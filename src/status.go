package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const version = "1.0.0"

const sessionFile = "/tmp/ztewifi.session"
const sessionTTL = 300 // 秒，会话缓存有效期，避免每次轮询都重新登录

// 需要向设备查询的命令列表（一次请求批量取回）
var statusCmds = []string{
	"network_type", "network_signalbar",
	"Z5g_rsrp", "Z5g_rsrq", "Z5g_SINR", "Z5g_snr",
	"network_lte_rsrp", "network_lte_rssi", "lte_rssi",
	"network_rssi", "network_rscp", "network_ecio",
	"wan_active_band", "wan_active_channel", "bandwidth",
	"network_cell_id", "network_pci",
	"network_lte_ca_pcell_band", "network_lte_ca_scell_band", "wan_lte_ca",
	"network_provider_fullname", "network_rmcc", "network_rmnc", "network_simcard_roam",
	"sim_iccid", "sim_imsi", "sim_msisdn", "imei",
	"device_market_name", "model_name", "wa_inner_version",
	"ppp_status", "mc_modem_main_state", "opms_wan_mode",
	"flux_realtime_tx_thrpt", "flux_realtime_rx_thrpt",
	"battery_value", "battery_vol_percent", "battery_charging", "battery_exist",
	"wifi_onoff_state", "wifi_chip1_ssid1_ssid", "wifi_chip2_ssid1_ssid",
	"wan_ipaddr", "lan_ipaddr",
}

// ---------------- 输出结构 ----------------

type Status struct {
	OK      bool        `json:"ok"`
	Error   string      `json:"error,omitempty"`
	IP      string      `json:"ip"`
	Time    string      `json:"time"`
	TS      int64       `json:"ts"`
	Network NetworkInfo `json:"network"`
	Signal  SignalInfo  `json:"signal"`
	Device  DeviceInfo  `json:"device"`
	Battery BatteryInfo `json:"battery"`
	WiFi    WiFiInfo    `json:"wifi"`
	Traffic TrafficInfo `json:"traffic"`
}

type NetworkInfo struct {
	Type       string `json:"type"`
	Band       string `json:"band"`
	Channel    string `json:"channel"`
	CellID     string `json:"cell_id"`
	Provider   string `json:"provider"`
	MCC        string `json:"mcc"`
	MNC        string `json:"mnc"`
	Roam       string `json:"roam"`
	PPPStatus  string `json:"ppp_status"`
	WANIP      string `json:"wan_ip"`
	LANIP      string `json:"lan_ip"`
	ModemState string `json:"modem_state"`
	WANMode    string `json:"wan_mode"`
}

type SignalInfo struct {
	Bars    int     `json:"bars"`
	Level   string  `json:"level"`
	RSRP    int     `json:"rsrp"`
	RSRQ    int     `json:"rsrq"`
	SINR    float64 `json:"sinr"`
	RSSI    int     `json:"rssi"`
	LTERSRP int     `json:"lte_rsrp"`
	LTERSSI int     `json:"lte_rssi"`
}

type DeviceInfo struct {
	Model    string `json:"model"`
	Market   string `json:"market"`
	Firmware string `json:"firmware"`
	IMEI     string `json:"imei"`
	ICCID    string `json:"iccid"`
	IMSI     string `json:"imsi"`
	MSISDN   string `json:"msisdn"`
}

type BatteryInfo struct {
	Percent  int  `json:"percent"`
	Charging bool `json:"charging"`
	Present  bool `json:"present"`
}

type WiFiInfo struct {
	Enabled bool   `json:"enabled"`
	SSID    string `json:"ssid"`
}

type TrafficInfo struct {
	TX int64 `json:"tx"`
	RX int64 `json:"rx"`
}

// ---------------- 命令实现 ----------------

func fetchStatus(cfg Config) *Status {
	now := time.Now()
	st := &Status{
		IP:   cfg.IP,
		Time: now.Format("2006-01-02 15:04:05"),
		TS:   now.Unix(),
	}
	if !cfg.Enabled {
		st.Error = "插件已禁用（请到“ZTE 随身WiFi → 设置”中启用）"
		return st
	}

	z := NewZTE(cfg.IP, cfg.Password, cfg.Timeout)

	// 1) 先尝试复用缓存会话
	if ck := loadSession(cfg.IP); ck != "" {
		z.cookie = ck
		if m, err := z.GetCmds(statusCmds); err == nil && m["network_type"] != "" {
			buildStatus(st, m)
			st.OK = true
			return st
		}
	}

	// 2) 重新登录
	if err := z.Login(); err != nil {
		st.Error = err.Error()
		return st
	}
	saveSession(cfg.IP, z.cookie)

	m, err := z.GetCmds(statusCmds)
	if err != nil {
		st.Error = err.Error()
		return st
	}
	if m["network_type"] == "" {
		st.Error = "已登录但读不到数据（会话可能被其他客户端抢占）"
		return st
	}

	buildStatus(st, m)
	st.OK = true
	return st
}

func buildStatus(st *Status, m map[string]string) {
	g := func(k string) string { return m[k] }

	st.Network = NetworkInfo{
		Type:       g("network_type"),
		Band:       g("wan_active_band"),
		Channel:    g("wan_active_channel"),
		CellID:     g("network_cell_id"),
		Provider:   g("network_provider_fullname"),
		MCC:        g("network_rmcc"),
		MNC:        g("network_rmnc"),
		Roam:       g("network_simcard_roam"),
		PPPStatus:  g("ppp_status"),
		WANIP:      g("wan_ipaddr"),
		LANIP:      g("lan_ipaddr"),
		ModemState: g("mc_modem_main_state"),
		WANMode:    g("opms_wan_mode"),
	}

	is5G := strings.Contains(strings.ToUpper(st.Network.Type), "NR") || strings.Contains(strings.ToUpper(st.Network.Type), "5G")
	rsrp := atoi(g("Z5g_rsrp"))
	rsrq := atoi(g("Z5g_rsrq"))
	sinr := atof(g("Z5g_SINR"))
	if sinr == 0 {
		sinr = atof(g("Z5g_snr"))
	}
	if !is5G {
		rsrp = atoi(g("network_lte_rsrp"))
		rsrq = atoi(g("Z5g_rsrq"))
	}
	st.Signal = SignalInfo{
		Bars:    atoi(g("network_signalbar")),
		Level:   signalLevel(rsrp),
		RSRP:    rsrp,
		RSRQ:    rsrq,
		SINR:    sinr,
		RSSI:    atoi(firstNonEmpty(g("network_rssi"), g("network_lte_rssi"), g("lte_rssi"))),
		LTERSRP: atoi(g("network_lte_rsrp")),
		LTERSSI: atoi(firstNonEmpty(g("network_lte_rssi"), g("lte_rssi"))),
	}

	st.Device = DeviceInfo{
		Model:    g("model_name"),
		Market:   g("device_market_name"),
		Firmware: g("wa_inner_version"),
		IMEI:     g("imei"),
		ICCID:    g("sim_iccid"),
		IMSI:     g("sim_imsi"),
		MSISDN:   g("sim_msisdn"),
	}

	charge := g("battery_charging")
	st.Battery = BatteryInfo{
		Percent:  atoi(firstNonEmpty(g("battery_value"), g("battery_vol_percent"))),
		Charging: charge == "1" || charge == "3",
		Present:  g("battery_exist") == "1" || charge == "2",
	}

	st.WiFi = WiFiInfo{
		Enabled: g("wifi_onoff_state") == "1",
		SSID:    firstNonEmpty(g("wifi_chip1_ssid1_ssid"), g("wifi_chip2_ssid1_ssid")),
	}

	st.Traffic = TrafficInfo{
		TX: atoi64(g("flux_realtime_tx_thrpt")),
		RX: atoi64(g("flux_realtime_rx_thrpt")),
	}
}

func signalLevel(rsrp int) string {
	switch {
	case rsrp == 0:
		return ""
	case rsrp >= -80:
		return "极佳"
	case rsrp >= -90:
		return "良好"
	case rsrp >= -100:
		return "一般"
	case rsrp >= -110:
		return "较弱"
	default:
		return "很弱"
	}
}

// ---------------- 会话缓存 ----------------

type sessionRec struct {
	IP     string `json:"ip"`
	Cookie string `json:"cookie"`
	TS     int64  `json:"ts"`
}

func loadSession(ip string) string {
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		return ""
	}
	var r sessionRec
	if err := json.Unmarshal(data, &r); err != nil {
		return ""
	}
	if r.IP != ip || r.Cookie == "" || time.Now().Unix()-r.TS > sessionTTL {
		return ""
	}
	return r.Cookie
}

func saveSession(ip, cookie string) {
	if cookie == "" {
		return
	}
	data, _ := json.Marshal(sessionRec{IP: ip, Cookie: cookie, TS: time.Now().Unix()})
	_ = os.WriteFile(sessionFile, data, 0600)
}

// ---------------- 工具 ----------------

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

func atoi(s string) int { n, _ := strconv.Atoi(strings.TrimSpace(s)); return n }
func atoi64(s string) int64 {
	n, _ := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	return n
}
func atof(s string) float64 { f, _ := strconv.ParseFloat(strings.TrimSpace(s), 64); return f }

// parseOpts 支持 --k v、--k=v、-k v；无值开关自动置 "true"。
func parseOpts(args []string) map[string]string {
	out := map[string]string{}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if !strings.HasPrefix(a, "-") {
			continue
		}
		a = strings.TrimLeft(a, "-")
		if eq := strings.Index(a, "="); eq >= 0 {
			out[a[:eq]] = a[eq+1:]
			continue
		}
		if i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
			out[a] = args[i+1]
			i++
		} else {
			out[a] = "true"
		}
	}
	return out
}

func uciSet(key, val string) error {
	if err := exec.Command("/sbin/uci", "-q", "get", "ztewifi.main").Run(); err != nil {
		if err := exec.Command("/sbin/uci", "set", "ztewifi.main=ztewifi").Run(); err != nil {
			return fmt.Errorf("创建 uci section 失败: %w", err)
		}
	}
	if err := exec.Command("/sbin/uci", "set", fmt.Sprintf("ztewifi.main.%s=%s", key, val)).Run(); err != nil {
		return fmt.Errorf("设置 %s 失败: %w", key, err)
	}
	return nil
}

func uciCommit() error {
	return exec.Command("/sbin/uci", "commit", "ztewifi").Run()
}

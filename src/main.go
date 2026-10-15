package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

func usage() {
	fmt.Fprintf(os.Stderr, `ztewifi %s —— ZTE 随身 WiFi 状态采集工具

用法:
  ztewifi status [--human] [--ip IP] [--password PWD]
        读取信号/网络/设备信息，默认输出 JSON。

  ztewifi test [--ip IP] [--password PWD]
        测试连通性与登录，输出 JSON {ok, message}。

  ztewifi config
        输出当前生效的配置（JSON，密码以掩码显示）。

  ztewifi set [--ip IP] [--password PWD] [--interval N] [--enabled 0|1]
        写入 UCI 配置 /etc/config/ztewifi。

  ztewifi version

环境变量: ZTEWIFI_IP / ZTEWIFI_PASSWORD
`, version)
}

func main() {
	argv := os.Args[1:]
	cmd := "status"
	if len(argv) > 0 && !strings.HasPrefix(argv[0], "-") {
		cmd = argv[0]
		argv = argv[1:]
	}
	opts := parseOpts(argv)

	cfg := LoadConfig()
	if v := opts["ip"]; v != "" {
		cfg.IP = v
	}
	if v, ok := opts["password"]; ok {
		cfg.Password = v
	}
	if v := opts["timeout"]; v != "" {
		if n, err := atoiErr(v); err == nil && n > 0 {
			cfg.Timeout = time.Duration(n) * time.Second
		}
	}

	switch cmd {
	case "status", "info":
		st := fetchStatus(cfg)
		if opts["human"] == "true" {
			printHuman(st)
		} else {
			printJSON(st)
		}
		if !st.OK {
			os.Exit(1)
		}

	case "test":
		printJSON(runTest(cfg))

	case "config":
		printJSON(map[string]interface{}{
			"ip":           cfg.IP,
			"password_set": cfg.Password != "",
			"password":     mask(cfg.Password),
			"interval":     cfg.Interval,
			"enabled":      cfg.Enabled,
		})

	case "set":
		res := map[string]interface{}{"ok": true}
		set := func(key, val string) {
			if err := uciSet(key, val); err != nil {
				res["ok"] = false
				res["error"] = err.Error()
			}
		}
		if v, ok := opts["ip"]; ok && v != "" {
			set("ip", v)
		}
		if v, ok := opts["password"]; ok {
			set("password", v)
		}
		if v, ok := opts["interval"]; ok && v != "" {
			set("interval", v)
		}
		if v, ok := opts["enabled"]; ok && v != "" {
			set("enabled", v)
		}
		if res["ok"] == true {
			if err := uciCommit(); err != nil {
				res["ok"] = false
				res["error"] = err.Error()
			} else {
				res["message"] = "配置已保存"
			}
		}
		printJSON(res)
		if res["ok"] != true {
			os.Exit(1)
		}

	case "version":
		fmt.Println(version)

	case "help", "h":
		usage()

	default:
		fmt.Fprintf(os.Stderr, "未知命令: %s\n\n", cmd)
		usage()
		os.Exit(2)
	}
}

func runTest(cfg Config) map[string]interface{} {
	start := time.Now()
	st := fetchStatus(cfg)
	res := map[string]interface{}{
		"ip":      cfg.IP,
		"elapsed": fmt.Sprintf("%dms", time.Since(start).Milliseconds()),
	}
	if !st.OK {
		res["ok"] = false
		res["message"] = st.Error
		return res
	}
	res["ok"] = true
	res["message"] = fmt.Sprintf("连接正常：%s，信号 %d/5，RSRP %d dBm",
		st.Network.Type, st.Signal.Bars, st.Signal.RSRP)
	res["status"] = st
	return res
}

func printJSON(v interface{}) {
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

func printHuman(st *Status) {
	if !st.OK {
		fmt.Printf("✗ %s\n", st.Error)
		return
	}
	n, s, d, b := st.Network, st.Signal, st.Device, st.Battery
	bar := strings.Repeat("█", s.Bars) + strings.Repeat("░", 5-s.Bars)

	fmt.Printf("=== ZTE 随身WiFi @ %s   %s ===\n", st.IP, st.Time)
	fmt.Printf("网络制式   : %s   (频段 %s / 信道 %s)\n", dash(n.Type), dash(n.Band), dash(n.Channel))
	fmt.Printf("运营商     : %s  %s/%s  %s\n", dash(n.Provider), dash(n.MCC), dash(n.MNC), n.Roam)
	fmt.Printf("信号       : %s (%d/5)  %s\n", bar, s.Bars, s.Level)
	fmt.Printf("RSRP/RSRQ/SINR : %v / %v / %v\n", dashInt(s.RSRP), dashInt(s.RSRQ), dashF(s.SINR))
	fmt.Printf("LTE RSRP/RSSI  : %v / %v\n", dashInt(s.LTERSRP), dashInt(firstNonZero(s.RSSI, s.LTERSSI)))
	fmt.Printf("连接状态   : %s  (%s / %s)\n", dash(n.PPPStatus), dash(n.ModemState), dash(n.WANMode))
	fmt.Printf("WAN/LAN IP : %s / %s\n", dash(n.WANIP), dash(n.LANIP))
	fmt.Printf("实时速率   : ↑ %d   ↓ %d\n", st.Traffic.TX, st.Traffic.RX)
	fmt.Printf("电量       : %d%%%s\n", b.Percent, charging(b.Charging))
	fmt.Printf("WiFi       : %s (开关 %v)\n", dash(st.WiFi.SSID), st.WiFi.Enabled)
	fmt.Printf("机型/固件  : %s %s  %s\n", dash(d.Market), dash(d.Model), dash(d.Firmware))
	fmt.Printf("IMEI/ICCID : %s  %s\n", dash(d.IMEI), dash(d.ICCID))
	fmt.Printf("IMSI       : %s\n", dash(d.IMSI))
}

func dash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}
func dashInt(n int) interface{} {
	if n == 0 {
		return "-"
	}
	return n
}
func dashF(f float64) interface{} {
	if f == 0 {
		return "-"
	}
	return f
}
func charging(c bool) string {
	if c {
		return "（充电中）"
	}
	return ""
}
func firstNonZero(a, b int) int {
	if a != 0 {
		return a
	}
	return b
}
func mask(s string) string {
	if s == "" {
		return ""
	}
	if len(s) <= 2 {
		return "**"
	}
	return s[:1] + strings.Repeat("*", len(s)-2) + s[len(s)-1:]
}
func atoiErr(s string) (int, error) {
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)
	return n, err
}

'use strict';
'require baseclass';
'require view.ztewifi.common as common';

/*
 * 首页（Status -> Overview）面板。
 *
 * 排版完全照抄 LuCI 自带「无线」区块：外层 .network-status-table +
 * ifacebox（蓝底标题条 + body），body 里先是「标签: 值」列表，
 * 末尾放一个宽体 ifacebadge（左侧信号图标 + 右侧多行信息）。
 * 之所以能变宽，是因为 CSS 里有
 *   .network-status-table .ifacebox-body .ifacebadge { display:flex; flex:1; min-width:220px }
 *
 * 文件名前缀 "29z_"：LuCI overview 会把 view/status/include/ 下的 .js
 * 按文件名字符串序排序后依次渲染，字符串序
 *     29_ports < 29z_ztewifi < 30_network
 * 因此本面板位于「端口状态」下面、「网络」上面。
 */
return baseclass.extend({
	title: _('ZTE 随身WiFi'),

	load: function () {
		return common.callStatus();
	},

	render: function (st) {
		if (!st || !st.ok) {
			return E('div', { 'class': 'alert-message warning' }, [
				E('strong', {}, [ _('读取失败') + '：' ]),
				(st && st.error) ? st.error : _('未知错误'),
				E('br'),
				E('a', { 'href': '/cgi-bin/luci/admin/services/ztewifi/settings' }, [ _('前往设置') ])
			]);
		}

		var n = st.network || {}, s = st.signal || {}, d = st.device || {}, b = st.battery || {};

		var pct = common.rsrpPercent(s.rsrp, s.bars);
		var icon = common.signalIcon(pct);
		var connected = /connected|connect/i.test(n.ppp_status || '');

		var model = [ d.market, d.model ].filter(Boolean).join(' / ');

		/* 主体信息：每项独占一行（itemlist 会自动用 <br> 分隔） */
		var info = [
			_('网络制式'), n.type || null,
			_('频段'), n.band || null,
			_('信道'), n.channel || null,
			_('小区 ID'), n.cell_id || null,
			_('运营商'),
				[ n.provider, (n.mcc && n.mnc) ? '(' + n.mcc + '/' + n.mnc + ')' : '', n.roam ]
					.filter(Boolean).join('  ') || null,
			_('连接状态'), n.ppp_status || null,
			_('固件'), d.firmware || null,
			_('电池'), (b.percent || 0) + '%' + (b.charging ? _('（充电中）') : '')
		];

		/* 宽体信号徽章：图标 + 右侧多行 */
		var badge = common.badgeWide(icon,
			_('信号') + ': ' + common.fmt(s.rsrp, ' dBm') + ' / ' + _('质量') + ': ' + pct + '%',
			[
				'RSRP', common.fmt(s.rsrp, '\u00a0dBm'),
				'RSRQ', common.fmt(s.rsrq, '\u00a0dB'),
				'SINR', common.fmt(s.sinr, '\u00a0dB'),
				_('质量'), pct + '%' + (s.level ? '  ' + s.level : ''),
				_('实时速率'), '\u2191 ' + (st.traffic && st.traffic.tx || 0) + '   \u2193 ' + (st.traffic && st.traffic.rx || 0),
				'WAN IP', n.wan_ip || null,
				_('WiFi SSID'), (st.wifi && st.wifi.ssid) ? st.wifi.ssid : null
			]);

		var box = common.ifaceBox(model || _('ZTE 随身WiFi'), connected,
			[ E('div', {}, [ badge ]) ], info);

		return E('div', { 'class': 'network-status-table' }, [ box ]);
	}
});

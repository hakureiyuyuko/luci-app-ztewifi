'use strict';
'require view';
'require dom';
'require poll';
'require uci';
'require ui';
'require view.ztewifi.common as common';

function renderContent(st) {
	if (!st || !st.ok) {
		return E('div', {}, [
			E('div', { 'class': 'alert-message error' }, [
				E('strong', {}, [ _('读取失败') + '：' ]),
				(st && st.error) ? st.error : _('未知错误')
			]),
			E('p', {}, [ _('请检查“设置”页中的设备 IP 与登录密码是否正确，并确认路由器能访问到随身 WiFi。') ])
		]);
	}

	var n = st.network || {}, s = st.signal || {}, d = st.device || {},
	    b = st.battery || {}, t = st.traffic || {}, w = st.wifi || {};

	var signal = E('table', { 'class': 'table' });
	var pct = common.rsrpPercent(s.rsrp, s.bars);
	var icon = common.signalIcon(pct);
	signal.appendChild(common.row(_('网络制式'), n.type || '-'));
	signal.appendChild(common.row(_('频段'), n.band || '-'));
	signal.appendChild(common.row(_('信道'), n.channel || '-'));
	signal.appendChild(E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '34%' }, [ _('信号强度') ]),
		E('td', { 'class': 'td left' }, [
			E('span', { 'style': 'display:flex;align-items:center;flex-wrap:wrap' }, [
				E('span', { 'style': 'margin-right:.75em' }, [
					common.badge(icon, common.fmt(s.rsrp, '\u00a0dBm'),
						_('信号') + ': ' + common.fmt(s.rsrp, ' dBm') +
						' / ' + _('质量') + ': ' + pct + '%')
				]),
				E('span', {}, [
					pct + '%' + (s.level ? '  ' + s.level : '') +
					'   (' + _('设备上报') + ' ' + (s.bars || 0) + '/5)'
				])
			])
		])
	]));
	signal.appendChild(common.row('RSRP / RSRQ / SINR',
		common.fmt(s.rsrp, ' dBm') + '  /  ' + common.fmt(s.rsrq, ' dB') + '  /  ' + common.fmt(s.sinr, ' dB')));
	signal.appendChild(common.row('RSSI', common.fmt(s.rssi || s.lte_rssi, ' dBm')));
	signal.appendChild(common.row(_('LTE RSRP'), common.fmt(s.lte_rsrp, ' dBm')));
	signal.appendChild(common.row(_('小区 ID'), n.cell_id || '-'));
	signal.appendChild(common.row(_('实时速率'), '\u2191 ' + (t.tx || 0) + '   \u2193 ' + (t.rx || 0)));

	var net = E('table', { 'class': 'table' });
	net.appendChild(common.row(_('运营商'),
		[ n.provider, (n.mcc && n.mnc) ? '(' + n.mcc + '/' + n.mnc + ')' : '' ].filter(Boolean).join(' ') || '-'));
	net.appendChild(common.row(_('漫游'), n.roam || '-'));
	net.appendChild(common.row(_('拨号状态'), n.ppp_status || '-'));
	net.appendChild(common.row(_('WAN IP'), n.wan_ip || '-'));
	net.appendChild(common.row(_('LAN IP'), n.lan_ip || '-'));

	var dev = E('table', { 'class': 'table' });
	dev.appendChild(common.row(_('机型'),
		[ d.market, d.model ].filter(Boolean).join(' / ') || '-'));
	dev.appendChild(common.row(_('固件'), d.firmware || '-'));
	dev.appendChild(common.row('IMEI', d.imei || '-'));
	dev.appendChild(common.row('ICCID', d.iccid || '-'));
	dev.appendChild(common.row('IMSI', d.imsi || '-'));
	dev.appendChild(common.row('MSISDN', d.msisdn || '-'));
	dev.appendChild(common.row(_('WiFi SSID'),
		(w.ssid || '-') + '   [' + (w.enabled ? _('已开启') : _('已关闭')) + ']'));
	dev.appendChild(common.row(_('电池'),
		(b.percent || 0) + '%' + (b.charging ? _('（充电中）') : '')));

	return E('div', { 'class': 'cbi-section-node' }, [
		E('div', { 'class': 'cbi-section' }, [ E('h3', {}, [ _('信号') ]), signal ]),
		E('div', { 'class': 'cbi-section' }, [ E('h3', {}, [ _('网络') ]), net ]),
		E('div', { 'class': 'cbi-section' }, [ E('h3', {}, [ _('设备') ]), dev ]),
		E('p', { 'class': 'cbi-section-descr' }, [
			_('采集自 %s，设备时间 %s').format(st.ip || '-', st.time || '-')
		])
	]);
}

return view.extend({
	load: function () {
		return Promise.all([ common.callStatus(), uci.load('ztewifi') ]);
	},

	render: function (data) {
		var interval = parseInt(uci.get('ztewifi', 'main', 'interval')) || 5;
		var box = E('div', { 'class': 'zte-status-box' });

		var update = function (st) { dom.content(box, renderContent(st)); };
		update(data[0]);

		var refresh = function () {
			return common.callStatus().then(function (st) { update(st); return st; });
		};

		poll.add(refresh, interval);

		return E('div', {}, [
			E('div', { 'class': 'cbi-map' }, [
				E('h2', {}, [ _('ZTE 随身WiFi 状态') ]),
				E('div', { 'class': 'cbi-map-descr' }, [
					_('每 %d 秒自动刷新；可在“设置”页修改刷新间隔。').format(interval)
				]),
				box
			]),
			E('div', { 'class': 'cbi-page-actions' }, [
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(this, refresh)
				}, [ _('立即刷新') ])
			])
		]);
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});

'use strict';
'require baseclass';
'require fs';

/*
 * 共用工具模块。
 * 注意：LuCI 会对模块返回的类执行 `new`（loader: `const instance = new _class()`），
 * 并把实例交给调用方，所以这里必须 return baseclass.extend({...})，
 * 而不是普通对象字面量，否则会报 "factory yields invalid constructor"。
 */

/* 调用 /usr/bin/ztewifi 并解析 JSON；异常统一归一化为 {ok:false, error:"..."} */
function callStatus() {
	return fs.exec('/usr/bin/ztewifi', [ 'status' ]).then(function (res) {
		var out = (res.stdout || '').trim();
		try {
			return JSON.parse(out);
		}
		catch (e) {
			return {
				ok: false,
				error: out ? out.slice(0, 300) : ((res.stderr || '').trim() || _('设备无输出'))
			};
		}
	}).catch(function (e) {
		var msg = (e && e.message) ? e.message : String(e);
		if (/PermissionError/.test(msg))
			msg += '（' + _('缺少 file.exec 权限，请以管理员账号登录') + '）';
		return { ok: false, error: msg };
	});
}

/* 数值展示：0 / 空 视为无效 */
function fmt(v, unit) {
	if (v === undefined || v === null || v === '' || v === 0)
		return '-';
	return v + (unit || '');
}

/* RSRP(dBm) -> 质量百分比；约 -115dBm=0% ，-80dBm=100%。
 * 没有 RSRP 时退回设备上报的信号格(0-5)。 */
function rsrpPercent(rsrp, bars) {
	var r = parseInt(rsrp);
	if (!r)
		return Math.max(0, Math.min(100, (parseInt(bars) || 0) * 20));
	return Math.max(0, Math.min(100, Math.round((r + 115) * 100 / 35)));
}

/* 选用 OpenWrt 原生信号图标（与 60_wifi.js 完全一致的阈值） */
function signalIcon(pct) {
	var name = (pct <= 0) ? 'signal-000-000'
		: (pct < 25) ? 'signal-000-025'
		: (pct < 50) ? 'signal-025-050'
		: (pct < 75) ? 'signal-050-075'
		: 'signal-075-100';
	return L.resource('icons/' + name + '.svg');
}

/* ---------------------------------------------------------------
 * 以下三个 helper 复刻 LuCI 首页模板 admin_status/index.ut 注入的
 * renderBox() / renderBadge() / L.itemlist()，用来做出与官方「无线」
 * 区块一模一样的 ifacebox 排版。
 * 若页面上已经有原生实现就直接用，避免将来样式漂移。
 * ------------------------------------------------------------- */

function itemlist(pairs) {
	if (typeof L.itemlist === 'function')
		return L.itemlist(E('span'), pairs);

	/* 等价回退：每项一行，形如 <strong>标签: </strong>值，用 <br> 分隔 */
	var children = [];
	for (var i = 0; i < pairs.length; i += 2) {
		if (pairs[i + 1] === null || pairs[i + 1] === undefined)
			continue;
		if (children.length)
			children.push(E('br'));
		children.push(E('span', { 'class': 'nowrap' }, [
			pairs[i] ? E('strong', pairs[i] + ': ') : '',
			pairs[i + 1]
		]));
	}
	return E('span', {}, children);
}

/* 紧凑信号徽章：图标在上、一行文字在下（适合表格单元格，需配合 .ifacebadge 默认列布局） */
function badge(icon, text, title) {
	return E('span', { 'class': 'ifacebadge', 'title': title || text }, [
		E('img', { 'src': icon }),
		E('span', {}, [ ' ', text ])
	]);
}

/* 宽体信号徽章：图标在左、右侧多行「标签: 值」。
 * 需要放在 .network-status-table 内才会变宽（与原生 renderBadge 一致）。 */
function badgeWide(icon, title, pairs) {
	if (typeof renderBadge === 'function')
		return renderBadge.apply(null, [ icon, title ].concat(pairs));

	return E('span', { 'class': 'ifacebadge' }, [
		E('img', { 'src': icon, 'title': title || '' }),
		itemlist(pairs)
	]);
}

/* ifacebox：带标题条的信息卡片 */
function ifaceBox(title, active, children, pairs) {
	if (typeof renderBox === 'function')
		return renderBox.apply(null, [ title, active, children ].concat(pairs));

	children = (children || []).slice();
	children.unshift(itemlist(pairs));

	return E('div', { 'class': 'ifacebox' }, [
		E('div', { 'class': 'ifacebox-head center ' + (active ? 'active' : '') },
			E('strong', title)),
		E('div', { 'class': 'ifacebox-body left' }, children)
	]);
}

/* 统一的“标签 - 值”表格行（应用内状态页用） */
function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '34%' }, [ label ]),
		E('td', { 'class': 'td left' }, [
			(value === undefined || value === null || value === '') ? '\u2014' : value
		])
	]);
}

return baseclass.extend({
	callStatus: callStatus,
	fmt: fmt,
	rsrpPercent: rsrpPercent,
	signalIcon: signalIcon,
	badge: badge,
	badgeWide: badgeWide,
	ifaceBox: ifaceBox,
	itemlist: itemlist,
	row: row
});

'use strict';
'require view';
'require form';
'require fs';
'require uci';
'require ui';

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('ztewifi'),
			fs.exec('/usr/bin/ztewifi', [ 'wifi', 'status' ]).then(function (res) {
				try { return JSON.parse((res.stdout || '').trim()); }
				catch (e) { return { ok: false, message: (res.stderr || '').trim() }; }
			}).catch(function (e) {
				return { ok: false, message: (e && e.message) ? e.message : String(e) };
			})
		]);
	},

	render: function (data) {
		var m, s, o;
		var wifi = data[1] || {};
		var wifiOn = wifi.on === true;
		var wifiKnown = wifi.ok === true;

		var stateHtml = function (on) {
			return on
				? '<b style="color:#1a7f37">' + _('已开启') + '</b>'
				: '<b style="color:#c0392b">' + _('已关闭') + '</b>';
		};

		m = new form.Map('ztewifi', _('ZTE 随身WiFi 设置'),
			_('配置随身 WiFi 后台的管理地址与登录密码。插件通过设备自带网页接口读取信号与网络信息，不会修改设备本身。'));

		s = m.section(form.NamedSection, 'main', 'ztewifi', _('基本设置'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.default = '1';
		o.rmempty = false;
		o.description = _('关闭后，首页面板与状态页将不再采集数据。');

		o = s.option(form.Value, 'ip', _('设备 IP 地址'));
		o.datatype = 'ip4addr';
		o.default = '192.168.0.1';
		o.placeholder = '192.168.0.1';
		o.rmempty = false;
		o.description = _('随身 WiFi 管理后台地址，通常为 192.168.0.1。');

		o = s.option(form.Value, 'password', _('登录密码'));
		o.password = true;
		o.rmempty = false;
		o.description = _('随身 WiFi 网页后台的登录密码（明文保存在本机 /etc/config/ztewifi）。');

		o = s.option(form.Value, 'interval', _('状态页刷新间隔'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.rmempty = false;
		o.description = _('单位：秒。');

		o = s.option(form.Value, 'timeout', _('请求超时'));
		o.datatype = 'uinteger';
		o.default = '8';
		o.optional = true;
		o.description = _('单位：秒。网络较慢时可调大。');

		o = s.option(form.Button, '_test', _('连接测试'));
		o.inputtitle = _('保存并测试连接');
		o.inputstyle = 'apply';
		o.onclick = function (ev, section_id) {
			var map = this.map;
			return Promise.resolve(map.save()).then(function () {
				return fs.exec('/usr/bin/ztewifi', [ 'test' ]);
			}).then(function (res) {
				var out = {};
				try { out = JSON.parse((res.stdout || '').trim()); } catch (e) {}
				if (out.ok)
					ui.addNotification(null, E('p', {}, [
						_('连接成功') + '：' + (out.message || '') + '  (' + (out.elapsed || '-') + ')'
					]), 'info');
				else
					ui.addNotification(null, E('p', {}, [
						_('连接失败') + '：' + (out.message || (res.stderr || '').trim() || _('未知错误'))
					]), 'error');
			}).catch(function (e) {
				ui.addNotification(null, E('p', {}, [
					_('测试失败') + '：' + ((e && e.message) ? e.message : e)
				]), 'error');
			});
		};

		/* ---- 设备控制：直接操作随身 WiFi 自身，不写入 UCI ---- */
		var btnClass = function (on) {
			return 'cbi-button cbi-button-' + (on ? 'reset important' : 'apply important');
		};

		var s2 = m.section(form.NamedSection, 'main', 'ztewifi', _('设备控制'));
		s2.anonymous = true;
		s2.description = _('直接控制随身 WiFi 自身的无线开关，不修改路由器配置，也不需要点“保存并应用”。');

		o = s2.option(form.DummyValue, '_wifi_state', _('设备 WiFi'));
		o.rawhtml = true;
		o.cfgvalue = function () {
			if (!wifiKnown)
				return '<em>' + _('读取失败') + (wifi.message ? '：' + wifi.message : '') + '</em>';
			return '<span id="ztewifi-wifi-state">' + stateHtml(wifiOn) + '</span>';
		};

		o = s2.option(form.Button, '_wifi_toggle', _('WiFi 开关'));
		o.inputtitle = wifiOn ? _('关闭') : _('开启');
		o.inputstyle = wifiOn ? 'reset important' : 'apply important';
		o.description = _('对应随身 WiFi 后台里的无线开关。设备切换需要几秒钟。');
		o.onclick = function (ev, section_id) {
			var btn = ev.currentTarget;
			var target = wifiOn ? 'off' : 'on';

			btn.disabled = true;
			return fs.exec('/usr/bin/ztewifi', [ 'wifi', target ]).then(function (res) {
				var out = {};
				try { out = JSON.parse((res.stdout || '').trim()); } catch (e) {}
				if (!out.ok)
					throw new Error(out.message || (res.stderr || '').trim() || _('未知错误'));

				wifiOn = out.on === true;
				var el = document.getElementById('ztewifi-wifi-state');
				if (el) el.innerHTML = stateHtml(wifiOn);
				btn.firstChild.data = wifiOn ? _('关闭') : _('开启');
				btn.setAttribute('class', btnClass(wifiOn));

				ui.addNotification(null, E('p', {}, [ out.message || _('操作成功') ]), 'info');
			}).catch(function (e) {
				ui.addNotification(null, E('p', {}, [
					_('操作失败') + '：' + ((e && e.message) ? e.message : e)
				]), 'error');
			}).finally(function () {
				btn.disabled = false;
			});
		};

		return m.render();
	}
});

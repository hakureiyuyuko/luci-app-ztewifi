'use strict';
'require view';
'require form';
'require fs';
'require uci';
'require ui';

return view.extend({
	load: function () {
		return uci.load('ztewifi');
	},

	render: function () {
		var m, s, o;

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

		return m.render();
	}
});

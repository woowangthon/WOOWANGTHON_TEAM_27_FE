import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get notifySupported => web.window.has('Notification');

Future<void> initNotify() async {}

/// 브라우저에서는 설정 화면을 열 수 없다.
Future<bool> openNotifySettings() async => false;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notifyPermission() => notifySupported ? web.Notification.permission : 'unsupported';

/// 브라우저 권한 창 (사용자가 직접 눌렀을 때만 호출해야 한다).
Future<String> requestNotifyPermission() async {
  if (!notifySupported) return 'unsupported';
  final r = await web.Notification.requestPermission().toDart;
  return r.toDart;
}

/// 메신저 알림처럼 표시: 앱 아이콘, 제목, 본문. 누르면 앱 창이 열린다.
void showSystemNotification(String title, String body, {String? tag}) {
  if (notifyPermission() != 'granted') return;
  final n = web.Notification(
    title,
    web.NotificationOptions(body: body, icon: 'icons/Icon-192.png', badge: 'icons/Icon-192.png', tag: tag ?? ''),
  );
  n.onclick = ((web.Event _) {
    web.window.focus();
    n.close();
  }).toJS;
}

extension on web.Window {
  bool has(String name) => (this as JSObject).has(name);
}

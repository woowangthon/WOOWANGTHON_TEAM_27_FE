/// 알림이 적용되지 않는 플랫폼용.
bool get notifySupported => false;

Future<void> initNotify() async {}

/// 시스템 알림 설정 (있는 경우).
Future<bool> openNotifySettings() async => false;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notifyPermission() => 'unsupported';

Future<String> requestNotifyPermission() async => 'unsupported';

Future<bool> showSystemNotification(String title, String body, {String? tag}) async => false;

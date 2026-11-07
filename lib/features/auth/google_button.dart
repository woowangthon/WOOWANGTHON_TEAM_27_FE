// 플랫폼에 맞는 "Google로 계속하기" 버튼.
// 웹: Google 공식 GIS 버튼 (웹에서는 이 방법으로만 로그인 가능).
// 그 외 플랫폼: GoogleSignIn.authenticate()를 호출하는 일반 버튼.
export 'google_button_stub.dart' if (dart.library.js_interop) 'google_button_web.dart';

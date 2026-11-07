// Web에서 Kakao JS SDK (window.kakao)가 로드되었는지 확인한다.
// Android에서는 항상 true (native SDK).
export 'kakao_sdk_check_stub.dart' if (dart.library.js_interop) 'kakao_sdk_check_web.dart';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool isKakaoSdkLoaded() {
  if (!globalContext.has('kakao')) return false;
  final kakao = globalContext['kakao'] as JSObject;
  return kakao.has('maps');
}

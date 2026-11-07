import 'package:web/web.dart' as web;

/// `<html class="lr-dark-map">` — web/index.html의 CSS는 Kakao 타일만 어둡게 함.
void setMapDarkMode(bool dark) => web.document.documentElement?.classList.toggle('lr-dark-map', dark);

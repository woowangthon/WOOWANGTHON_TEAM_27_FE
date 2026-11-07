import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const _googleCalendar = 'com.google.android.calendar';

/// 캘린더를 연다. Android에서는 브라우저가 아닌 Google Calendar 앱:
/// 1) Google Calendar 앱에서 해당 행사([htmlLink]);
/// 2) [at] 날짜의 Google Calendar;
/// 3) [at] 날짜의 기기 캘린더 앱;
/// 4) 최후의 수단 — 브라우저. Web에서는 항상 브라우저.
Future<void> openCalendar({String? htmlLink, DateTime? at}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final day = at ?? DateTime.now();
    final timeUri = 'content://com.android.calendar/time/${day.millisecondsSinceEpoch}';
    final attempts = [
      if (htmlLink != null) AndroidIntent(action: 'action_view', data: htmlLink, package: _googleCalendar),
      AndroidIntent(action: 'action_view', data: timeUri, package: _googleCalendar),
      AndroidIntent(action: 'action_view', data: timeUri),
    ];
    for (final intent in attempts) {
      try {
        if (await intent.canResolveActivity() ?? false) {
          await intent.launch();
          return;
        }
      } catch (e) {
        debugPrint('openCalendar: $e');
      }
    }
  }
  await launchUrl(
    Uri.parse(htmlLink ?? 'https://calendar.google.com/calendar/r/month'),
    mode: LaunchMode.externalApplication,
  );
}

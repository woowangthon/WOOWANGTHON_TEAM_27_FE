import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/env.dart';
import 'core/notify/notify.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/calendar_controller.dart';
import 'data/contest_background.dart';
import 'data/live_events.dart';
import 'data/providers.dart';
import 'data/session.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 예상하지 못한 오류가 앱을 멈추거나 회색 화면을 남기지 않게.
  FlutterError.onError = (details) {
    FlutterError.presentError(details); // 디버그: 콘솔, 릴리스: 기록만
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: ${error.runtimeType}: $error');
    return true; // 처리됨 — 앱은 계속 동작한다
  };
  if (kReleaseMode) {
    // 화면 일부를 그리다 실패하면 빨간/회색 오류 대신 빈 칸.
    ErrorWidget.builder = (_) => const SizedBox.shrink();
  }
  // 웹: SDK는 web/index.html에서 로드한다 (initialize 불필요).
  if (!kIsWeb && Env.hasKakaoMapKey) {
    await KakaoMapSdk.instance.initialize(Env.kakaoNativeAppKey);
    // Kakao Developers 등록용 key hash를 콘솔에 출력한다.
    debugPrint('Kakao key hash: ${await KakaoMapSdk.instance.hashKey()}');
  }
  // GIS SDK는 백그라운드에서 로드한다 — 앱 시작을 기다리게 하지 않는다.
  initGoogleSignIn().catchError((Object e) => debugPrint('Google Sign-In init failed: $e'));
  final (prefs, _) = await (SharedPreferences.getInstance(), initNotify()).wait;
  final feed = await LiveEvents.initial(prefs);
  await ContestBackground.register().catchError((Object e) => debugPrint('Contest scheduling: ${e.runtimeType}'));
  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      initialEventFeedProvider.overrideWithValue(feed),
      liveEventsEnabledProvider.overrideWithValue(true),
    ],
    child: const LifeRadarApp(),
  ));
}

class LifeRadarApp extends ConsumerWidget {
  const LifeRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

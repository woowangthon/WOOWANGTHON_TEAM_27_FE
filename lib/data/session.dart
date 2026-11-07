import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'calendar_controller.dart';
import 'providers.dart';

// ─────────────────────────── 테마 / 언어 (저장됨) ───────────────────────────

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => ThemeMode.values.asNameMap()[ref.read(sharedPrefsProvider).getString(_key)] ?? ThemeMode.system;

  Future<void> set(ThemeMode m) async {
    state = m;
    await ref.read(sharedPrefsProvider).setString(_key, m.name);
  }
}

/// null = 기기 언어.
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    final code = ref.read(sharedPrefsProvider).getString(_key);
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? l) async {
    state = l;
    final prefs = ref.read(sharedPrefsProvider);
    l == null ? await prefs.remove(_key) : await prefs.setString(_key, l.languageCode);
  }
}

// ─────────────────────────── 세션 (게스트 / Google) ───────────────────────────

enum SessionKind { guest, google }

class Session {
  const Session({required this.kind, this.name, this.email, this.photoUrl});

  final SessionKind kind;
  final String? name;
  final String? email;
  final String? photoUrl;

  bool get isGuest => kind == SessionKind.guest;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'name': name, 'email': email, 'photoUrl': photoUrl};

  static Session? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Session(
        kind: SessionKind.values.byName(j['kind'] as String),
        name: j['name'] as String?,
        email: j['email'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// null = 로그인하지 않음 (로그인 화면).
/// Google 계정 정보는 프로필용(이름/이메일/사진)만 — 비밀번호나 토큰은 저장하지 않는다.
final sessionProvider = NotifierProvider<SessionController, Session?>(SessionController.new);

class SessionController extends Notifier<Session?> {
  static const _key = 'session';
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  @override
  Session? build() {
    ref.onDispose(() => _sub?.cancel());
    return Session.fromJson(ref.read(sharedPrefsProvider).getString(_key));
  }

  /// Google 버튼(웹: GIS renderButton) 결과를 구독한다.
  /// 로그인 화면이 열릴 때 호출; [onSignedIn] — 다음 화면으로 이동.
  void listenForGoogle(void Function() onSignedIn, void Function(Object error) onError) {
    if (!isGoogleSignInConfigured) return;
    _sub?.cancel();
    _sub = GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final u = event.user;
        await _save(Session(kind: SessionKind.google, name: u.displayName, email: u.email, photoUrl: u.photoUrl));
        onSignedIn();
      }
    }, onError: onError);
  }

  Future<void> continueAsGuest() => _save(const Session(kind: SessionKind.guest));

  Future<void> signOut() async {
    await ref.read(calendarProvider.notifier).disconnect();
    if (isGoogleSignInConfigured && state?.kind == SessionKind.google) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await ref.read(sharedPrefsProvider).remove(_key);
    state = null;
  }

  Future<void> _save(Session s) async {
    state = s;
    await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(s.toJson()));
  }
}

// ─────────────────────────── 첫 실행과 이름 ───────────────────────────

/// 언어와 테마 선택 여부 (기기 기준 — 계정보다 먼저 묻는다).
final setupDoneProvider = NotifierProvider<SetupDoneController, bool>(SetupDoneController.new);

class SetupDoneController extends Notifier<bool> {
  static const _key = 'setup_done';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPrefsProvider).setBool(_key, true);
  }
}

/// 사용자가 직접 입력한 이름 (홈의 "안녕하세요, …"). 계정별로 저장 —
/// Google의 이름은 다른 경우가 많아 로그인 후에 묻는다.
final profileNameProvider = NotifierProvider<ProfileNameController, String?>(ProfileNameController.new);

class ProfileNameController extends Notifier<String?> {
  late String _key;

  @override
  String? build() {
    _key = 'name:${accountScope(ref.watch(sessionProvider))}';
    final v = ref.read(sharedPrefsProvider).getString(_key)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> save(String name) async {
    final v = name.trim();
    state = v.isEmpty ? null : v;
    final prefs = ref.read(sharedPrefsProvider);
    v.isEmpty ? await prefs.remove(_key) : await prefs.setString(_key, v);
  }
}

/// 로그인 이후 단계: 이름 → 관심사 → 홈. 둘 다 있으면 바로 홈.
String nextAfterAuth(Ref ref) {
  if (ref.read(profileNameProvider) == null) return '/name';
  if (ref.read(interestsProvider).isEmpty) return '/onboarding';
  return '/home';
}

/// 위젯에서 호출하기 위한 메서드.
String nextAfterAuthOf(WidgetRef ref) {
  if (ref.read(profileNameProvider) == null) return '/name';
  if (ref.read(interestsProvider).isEmpty) return '/onboarding';
  return '/home';
}

/// 계정과 기기의 모든 LifeRadar 데이터를 삭제한다 (테스트용 "처음부터 시작"으로도 사용).
/// Google 권한을 해제(disconnect)하고 캘린더 토큰을 지운다. 이후 → /welcome.
Future<void> deleteAccountAndData(WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  await ref.read(calendarProvider.notifier).disconnect();
  if (isGoogleSignInConfigured && session?.kind == SessionKind.google) {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }
  await ref.read(sharedPrefsProvider).clear();
  ref
    ..invalidate(sessionProvider)
    ..invalidate(interestsProvider)
    ..invalidate(plansProvider)
    ..invalidate(profileNameProvider)
    ..invalidate(setupDoneProvider)
    ..invalidate(themeModeProvider)
    ..invalidate(localeProvider)
    ..invalidate(insightFeedbackProvider);
}

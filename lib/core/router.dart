import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/session.dart';
import '../features/auth/login_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/name_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/profile/account_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/welcome/welcome_screen.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets.dart';

/// 상위 레벨 페이지를 위한 부드러운 페이드 + 미세한 위로 이동.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.slow,
      reverseTransitionDuration: Motion.normal,
      transitionsBuilder: (context, animation, _, child) {
        final a = CurvedAnimation(parent: animation, curve: Motion.curve);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
            child: child,
          ),
        );
      },
    );

/// 진입점: 최초 실행 → 언어/테마; 세션 없음 → 로그인;
/// 이름 없음 → 이름; 관심사 없음 → 관심사; 그 외 → 홈.
final routerProvider = Provider<GoRouter>((ref) {
  final setupDone = ref.read(setupDoneProvider);
  final signedIn = ref.read(sessionProvider) != null;
  return GoRouter(
    navigatorKey: Toast.navigatorKey, // 토스트는 루트 오버레이에 표시됨
    initialLocation: !setupDone ? '/welcome' : (!signedIn ? '/login' : nextAfterAuth(ref)),
    routes: [
      GoRoute(path: '/welcome', pageBuilder: (_, s) => _fadePage(s, const WelcomeScreen())),
      GoRoute(path: '/login', pageBuilder: (_, s) => _fadePage(s, const LoginScreen())),
      GoRoute(
        path: '/name',
        pageBuilder: (_, s) => _fadePage(s, NameScreen(editing: s.uri.queryParameters['edit'] == '1')),
      ),
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => _fadePage(s, const OnboardingScreen())),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/interests', builder: (_, _) => const OnboardingScreen(editing: true)),
      StatefulShellRoute(
        builder: (context, state, shell) => shell,
        navigatorContainerBuilder: (context, shell, children) => AppShell(
          shell: shell,
          body: FadeBranchContainer(currentIndex: shell.currentIndex, children: children),
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/plans', builder: (_, _) => const PlansScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
    errorBuilder: (_, _) => const Scaffold(body: Center(child: AppSpinner(size: 28))),
  );
});

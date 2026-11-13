import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/calendar_controller.dart';
import '../../data/notifications.dart';
import '../../data/providers.dart';
import '../../data/session.dart';

/// 내 정보 — 카드 안의 카드 없이, 한 장의 목록으로.
/// 위: 나(사진·이름·관심사). 아래: 연결 · 앱 설정 · 정보. 각 줄은 "이름 ··· 현재 값".
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final session = ref.watch(sessionProvider);
    final cal = ref.watch(calendarProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final pushOn = ref.watch(notificationsEnabledProvider);
    final guest = session == null || session.isGuest;
    final displayName = ref.watch(profileNameProvider) ?? (guest ? null : session.name);
    final stage = ref.watch(lifeStageProvider);
    final interests = [for (final tag in ref.watch(interestsProvider)) ?interestByTag(tag)];

    Future<void> signOut() async {
      await ref.read(sessionProvider.notifier).signOut();
      Toast.show(l10n.signedOutToast, type: ToastType.info);
      if (context.mounted) context.go('/login');
    }

    Future<void> toggleCalendar(bool on) async {
      final c = ref.read(calendarProvider.notifier);
      if (!on) {
        await c.disconnect();
        Toast.show(l10n.calendarDisconnectedToast, type: ToastType.info);
        return;
      }
      await c.connect();
      final s = ref.read(calendarProvider);
      if (s.isConnected) {
        Toast.show(l10n.calendarConnectedToast);
      } else {
        Toast.show(
          s.error == 'expired' ? l10n.calendarExpiredToast : l10n.calendarErrorToast,
          type: s.error == 'expired' ? ToastType.warning : ToastType.error,
        );
      }
    }

    final themeLabel = switch (themeMode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
    final langLabel = switch (locale?.languageCode) {
      'ko' => '한국어',
      'en' => 'English',
      _ => l10n.themeSystem,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.xxxl + MediaQuery.paddingOf(context).bottom),
        children: [
          // ── 나 ──
          const SizedBox(height: Space.md),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(photoUrl: session?.photoUrl, name: displayName, size: 84),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: p.primary,
                    shape: CircleBorder(side: BorderSide(color: p.background, width: 3)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/name?edit=1'),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.edit_rounded, size: 15, color: p.onPrimary, semanticLabel: l10n.editName),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            displayName ?? l10n.guestName,
            textAlign: TextAlign.center,
            style: t.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            guest ? l10n.guestSubtitle : (session.email ?? ''),
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          if (guest) ...[
            const SizedBox(height: Space.md),
            Center(child: FilledButton.tonal(onPressed: signOut, child: Text(l10n.signIn))),
          ],

          // 관심사 — 이름 대신 실제 칩으로 한눈에, 누르면 수정.
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => context.push('/interests'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(
                            stage == null ? l10n.profileStageNone : context.tr(stage.label),
                            icon: Icons.person_pin_circle_outlined,
                            tone: Tone.primary,
                          ),
                          for (final o in interests.take(5)) Pill(context.tr(o.label), icon: o.icon),
                          if (interests.length > 5) Pill('+${interests.length - 5}'),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.textMuted),
                  ],
                ),
              ),
            ),
          ),

          // ── 연결 ──
          _Header(l10n.sectionConnections),
          _Row(
            icon: Icons.calendar_month_outlined,
            title: l10n.sourceCalendar,
            trailing: cal.isBusy
                ? const AppSpinner(size: 20)
                : Switch(value: cal.isConnected, onChanged: toggleCalendar),
          ),

          // ── 앱 설정 ──
          _Header(l10n.profileSettings),
          _Row(
            icon: Icons.contrast_rounded,
            title: l10n.theme,
            value: themeLabel,
            onTap: () async {
              final picked = await _pick<ThemeMode>(
                context,
                title: l10n.theme,
                current: themeMode,
                options: [
                  (ThemeMode.system, l10n.themeSystem, Icons.brightness_auto_outlined),
                  (ThemeMode.light, l10n.themeLight, Icons.light_mode_outlined),
                  (ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
                ],
              );
              if (picked == null || picked == themeMode) return;
              ref.read(themeModeProvider.notifier).set(picked);
              Toast.show(l10n.themeChanged, type: ToastType.info);
            },
          ),
          _Row(
            icon: Icons.translate_rounded,
            title: l10n.language,
            value: langLabel,
            onTap: () async {
              final current = locale?.languageCode ?? 'system';
              final picked = await _pick<String>(
                context,
                title: l10n.language,
                current: current,
                options: [
                  ('system', l10n.themeSystem, Icons.phone_android_rounded),
                  ('ko', '한국어', Icons.language_rounded),
                  ('en', 'English', Icons.language_rounded),
                ],
              );
              if (picked == null || picked == current) return;
              ref.read(localeProvider.notifier).set(picked == 'system' ? null : Locale(picked));
              Toast.show(l10n.languageChanged, type: ToastType.info);
            },
          ),
          // 알림 설정은 알림 탭 한 곳에 — 여기서는 바로가기만.
          _Row(
            icon: Icons.notifications_none_rounded,
            title: l10n.notifications,
            value: pushOn ? l10n.alertsPushOn : l10n.alertsPushOff,
            onTap: () => context.go('/alerts'),
          ),

          // ── 정보 ──
          _Header(l10n.profileHelp),
          _Row(
            icon: Icons.shield_outlined,
            title: l10n.privacy,
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.privacy),
                content: Text('${l10n.calendarPrivacy}\n\n${l10n.onboardingPrivacy}'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
              ),
            ),
          ),
          // 계정 삭제 — 실수로 누르지 않도록 별도 페이지 + 확인.
          _Row(icon: Icons.manage_accounts_outlined, title: l10n.accountData, onTap: () => context.push('/account')),
          // pubspec.yaml의 version을 그대로 보여준다.
          _Row(icon: Icons.info_outline_rounded, title: l10n.version, value: ref.watch(appVersionProvider).value ?? ''),

          const SizedBox(height: Space.xl),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: p.danger),
              onPressed: signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(guest ? l10n.exitGuest : l10n.logout),
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택지 시트 — 세그먼트 버튼 대신, 고를 때만 연다.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String, IconData)> options,
}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final p = ctx.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
                child: Text(title, style: ctx.textStyles.titleMedium),
              ),
              for (final (value, label, icon) in options)
                ListTile(
                  leading: Icon(icon, color: value == current ? p.primary : p.textMuted),
                  title: Text(label),
                  trailing: value == current ? Icon(Icons.check_rounded, color: p.primary) : null,
                  onTap: () => Navigator.pop(ctx, value),
                ),
              const SizedBox(height: Space.sm),
            ],
          ),
        );
      },
    );

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xs),
    child: Semantics(
      header: true,
      child: Text(text, style: context.textStyles.labelMedium!.copyWith(color: context.palette.textMuted)),
    ),
  );
}

/// 한 줄 설정: 아이콘 · 이름 ··· 현재 값 ›. 테두리·배경 없이.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
          child: Row(
            children: [
              Icon(icon, size: 22, color: p.textMuted),
              const SizedBox(width: Space.lg),
              Expanded(child: Text(title, style: t.bodyLarge)),
              if (value != null) Text(value!, style: t.bodyMedium!.copyWith(color: p.textMuted)),
              ?trailing,
              if (onTap != null && trailing == null) ...[
                const SizedBox(width: Space.xs),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

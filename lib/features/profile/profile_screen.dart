import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/calendar_controller.dart';
import '../../core/notify/notify.dart';
import '../../core/toast.dart';
import '../../data/notifications.dart';
import '../../data/session.dart';
import '../../data/providers.dart';

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
    final guest = session == null || session.isGuest;
    final displayName = ref.watch(profileNameProvider) ?? (guest ? null : session.name);

    Future<void> signOut() async {
      await ref.read(sessionProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.xxxl + MediaQuery.paddingOf(context).bottom),
        children: [
          // ── 사용자 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    AppAvatar(photoUrl: session?.photoUrl, name: displayName, size: 56),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName ?? l10n.guestName,
                                  style: t.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.editName,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.edit_outlined, size: 18, color: p.textMuted),
                                onPressed: () => context.push('/name?edit=1'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guest ? l10n.guestSubtitle : (session.email ?? ''),
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (guest) TextButton(onPressed: signOut, child: Text(l10n.signIn)),
                  ],
                ),
              ),
            ),
          ),

          // ── 관심사: 목록은 여기서 보여주지 않음 (공간 절약) — "수정"으로 연다 ──
          SectionHeader(l10n.interestsEdit),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GroupCard(
              children: [
                ListTile(
                  leading: const IconTile(Icons.interests_outlined, size: 36),
                  title: Text(l10n.interestsEdit),
                  subtitle: Text(l10n.interestsCount(ref.watch(interestsProvider).length)),
                  trailing: TextButton(onPressed: () => context.push('/interests'), child: Text(l10n.edit)),
                  onTap: () => context.push('/interests'),
                ),
              ],
            ),
          ),

          // ── 연결된 서비스 ──
          SectionHeader(l10n.sectionConnections),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GroupCard(
              children: [
                ListTile(
                  leading: const IconTile(Icons.calendar_month_outlined, size: 36),
                  title: Text(l10n.sourceCalendar),
                  subtitle: Text(cal.isConnected ? l10n.connected : l10n.notConnected),
                  trailing: cal.isBusy
                      ? const AppSpinner(size: 20)
                      : cal.isConnected
                      ? TextButton(
                          onPressed: () => ref.read(calendarProvider.notifier).disconnect(),
                          child: Text(l10n.calendarDisconnect, style: TextStyle(color: p.danger)),
                        )
                      : TextButton(
                          onPressed: () => ref.read(calendarProvider.notifier).connect(),
                          child: Text(l10n.connect),
                        ),
                ),
              ],
            ),
          ),

          // ── 설정 ──
          SectionHeader(l10n.sectionSettings),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GroupCard(
              children: [
                _SettingRow(
                  icon: Icons.contrast_rounded,
                  label: l10n.theme,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
                      ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ),
                const _NotificationsRow(),
                _SettingRow(
                  icon: Icons.translate_rounded,
                  label: l10n.language,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'system', label: Text(l10n.themeSystem)),
                      const ButtonSegment(value: 'ko', label: Text('한국어')),
                      const ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {locale?.languageCode ?? 'system'},
                    onSelectionChanged: (s) =>
                        ref.read(localeProvider.notifier).set(s.first == 'system' ? null : Locale(s.first)),
                  ),
                ),
              ],
            ),
          ),

          // ── 정보 ──
          SectionHeader(l10n.sectionAbout),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: GroupCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l10n.privacy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.privacy),
                      content: Text('${l10n.calendarPrivacy}\n\n${l10n.onboardingPrivacy}'),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.version),
                  trailing: Text('0.1.0 · MVP', style: t.bodySmall),
                ),
                // 계정 삭제 — 실수로 누르지 않도록 일부러 안쪽에 (별도 페이지 + 확인).
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: Text(l10n.accountData),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/account'),
                ),
              ],
            ),
          ),

          const SizedBox(height: Space.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: p.danger),
              onPressed: signOut,
              icon: const Icon(Icons.logout_rounded),
              label: Text(guest ? l10n.exitGuest : l10n.logout),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림: 켤 때 권한을 요청하고, 켜져 있으면 테스트 알림 버튼을 보여준다.
class _NotificationsRow extends ConsumerWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final on = ref.watch(notificationsEnabledProvider);
    final supported = notifySupported;

    Future<void> toggle(bool v) async {
      final c = ref.read(notificationsEnabledProvider.notifier);
      if (!v) return c.disable();
      final r = await c.enable();
      switch (r) {
        case 'granted':
          Toast.show(l10n.notifyOn);
        case 'unsupported':
          Toast.show(l10n.notifyUnsupported, type: ToastType.warning);
        default:
          // Android: 설정 화면을 연다; 웹: 브라우저 설정 안내.
          final opened = await openNotifySettings();
          Toast.show(opened ? l10n.notifyDeniedApp : l10n.notifyDenied, type: ToastType.warning);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, size: 20, color: p.textMuted),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.notifications, style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(supported ? l10n.notifyDesc : l10n.notifyUnsupported, style: t.bodySmall),
                  ],
                ),
              ),
              Switch(value: on, onChanged: supported ? toggle : null),
            ],
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: TextButton.icon(
                onPressed: () => ref.read(signalNotifierProvider).test(),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(l10n.notifyTest),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: context.palette.textMuted),
            const SizedBox(width: Space.md),
            Text(label, style: context.textStyles.titleSmall),
          ],
        ),
        const SizedBox(height: Space.md),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}

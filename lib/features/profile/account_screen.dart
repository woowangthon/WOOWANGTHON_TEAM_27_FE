import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/confirm.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/session.dart';

/// 프로필 → 정보 → 계정 및 데이터. 삭제는 이 안쪽 화면에서 확인 후 진행한다.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _deleting = false;

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showConfirm(
      context,
      icon: Icons.delete_forever_outlined,
      title: l10n.deleteAccountTitle,
      body: l10n.deleteAccountBody,
      confirmLabel: l10n.deleteAccount,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    Toast.progress(l10n.planDeleting);
    await deleteAccountAndData(ref);
    if (!mounted) return;
    Toast.show(l10n.accountDeleted, type: ToastType.info);
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final session = ref.watch(sessionProvider);
    final name = ref.watch(profileNameProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountData)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          GroupCard(
            children: [
              ListTile(
                leading: const IconTile(Icons.person_outline_rounded, size: 36),
                title: Text(name ?? l10n.guestName),
                subtitle: Text(session == null || session.isGuest ? l10n.guestName : (session.email ?? '')),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: p.textMuted),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(l10n.deleteAccountInfo, style: t.bodySmall)),
            ],
          ),
          const SizedBox(height: Space.xxxl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.danger,
              side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
            ),
            onPressed: _deleting ? null : _delete,
            icon: _deleting ? AppSpinner(color: p.danger) : const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
  }
}

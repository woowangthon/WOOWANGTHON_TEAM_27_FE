import 'package:flutter/material.dart';

import 'theme.dart';

/// 모던한 확인 창 (하단 팝업): 컬러 아이콘 (부드러운 "pop" 애니메이션),
/// 제목, 설명 및 2개의 큰 버튼. 위험한 작업 ([destructive]) — 빨간색 버튼.
/// `true` — 확인됨; 닫히거나 "취소" 시 — `false`.
Future<bool> showConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  Widget? extra,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    useRootNavigator:
        true, // 하단 네비게이션도 덮도록 함 — 선택에만 집중
    builder: (_) => _ConfirmSheet(
      icon: icon,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      extra: extra,
    ),
  );
  return ok ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final color = destructive ? p.danger : p.primary;
    final soft = destructive ? p.dangerSoft : p.primarySoft;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.xxl,
          Space.sm,
          Space.xxl,
          Space.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0.4, end: 1),
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: soft,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 30),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(title, textAlign: TextAlign.center, style: t.titleLarge),
            if (body != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: p.textMuted),
              ),
            ],
            if (extra != null) ...[const SizedBox(height: Space.lg), extra!],
            const SizedBox(height: Space.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: FilledButton(
                    style: destructive
                        ? FilledButton.styleFrom(
                            backgroundColor: p.danger,
                            foregroundColor: Colors.white,
                          )
                        : null,
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

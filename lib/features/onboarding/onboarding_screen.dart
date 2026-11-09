import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/toast.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'about_me_sheet.dart';

/// 관심사 선택. 첫 실행([editing] = false)과
/// 이후 "관심사 변경"([editing] = true)에서 모두 사용한다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final Set<String> _selected = {...ref.read(interestsProvider)};
  late LifeStage? _stage = ref.read(lifeStageProvider);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(lifeStageProvider.notifier).save(_stage);
    await ref.read(interestsProvider.notifier).save(_selected);
    if (!mounted) return;
    if (widget.editing && context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// AI 대화로 상황·관심사 제안을 받아, 사용자가 남긴 것만 더한다.
  Future<void> _aboutMe() async {
    final r = await showAboutMe(context);
    if (r == null || !mounted) return;
    final added = r.tags.difference(_selected).length;
    setState(() {
      if (r.stage != null) _stage = r.stage;
      _selected.addAll(r.tags);
    });
    Toast.show(context.l10n.aboutMeApplied(added));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        title: widget.editing ? Text(l10n.interestsEdit) : null,
        automaticallyImplyLeading: widget.editing,
      ),
      // 버튼이 항상 보이도록 (작은 화면에서도).
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty || _saving ? null : _save,
                    child: Text(
                      _selected.isEmpty
                          ? l10n.onboardingPickOne
                          : widget.editing
                          ? l10n.save
                          : l10n.onboardingContinue(_selected.length),
                    ),
                  ),
                ),
                if (!widget.editing) ...[
                  const SizedBox(height: Space.sm),
                  Text(l10n.onboardingPrivacy, textAlign: TextAlign.center, style: t.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              if (!widget.editing) ...[
                Text(l10n.stepOf(2, 2), style: t.labelMedium!.copyWith(color: p.primary)),
                const SizedBox(height: Space.sm),
              ],
              Text(l10n.onboardingTitle, style: t.headlineSmall),
              const SizedBox(height: Space.sm),
              Text(l10n.onboardingSubtitle, style: t.bodyMedium!.copyWith(color: p.textMuted)),
              const SizedBox(height: Space.xl),

              // ── AI에게 나를 소개하기 ──
              Card(
                child: InkWell(
                  onTap: _aboutMe,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Row(
                      children: [
                        const IconTile(Icons.auto_awesome),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.aboutMeCta, style: t.titleSmall),
                              const SizedBox(height: 2),
                              Text(l10n.aboutMeCtaBody, style: t.bodySmall),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: p.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),

              // ── 지금 상황 (선택) ──
              Text(l10n.stageTitle, style: t.labelLarge!.copyWith(color: p.textMuted)),
              const SizedBox(height: 2),
              Text(l10n.stageOptional, style: t.bodySmall),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final s in LifeStage.values)
                    InterestChip(
                      label: context.tr(s.label),
                      icon: lifeStageIcon(s),
                      hue: Hue.teal,
                      selected: _stage == s,
                      onTap: () => setState(() => _stage = _stage == s ? null : s),
                    ),
                ],
              ),
              const SizedBox(height: Space.xxl),
              for (final g in InterestGroup.values) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Text(context.tr(g.label), style: t.labelLarge!.copyWith(color: p.textMuted)),
                ),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final o in interestOptions.where((o) => o.group == g))
                      InterestChip(
                        label: context.tr(o.label),
                        icon: o.icon,
                        hue: o.hue,
                        selected: _selected.contains(o.tag),
                        onTap: () =>
                            setState(() => _selected.contains(o.tag) ? _selected.remove(o.tag) : _selected.add(o.tag)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

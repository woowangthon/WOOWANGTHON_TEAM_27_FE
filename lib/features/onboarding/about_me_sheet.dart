import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/ai_insights.dart';
import '../../data/providers.dart';

/// "나를 소개하기" 결과: 사용자가 직접 남긴 상황과 관심사.
class AboutMeResult {
  const AboutMeResult({this.stage, this.tags = const {}});
  final LifeStage? stage;
  final Set<String> tags;
}

Future<AboutMeResult?> showAboutMe(BuildContext context) => showModalBottomSheet<AboutMeResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => const AboutMeSheet(),
);

IconData lifeStageIcon(LifeStage s) => switch (s) {
  LifeStage.student => Icons.school_outlined,
  LifeStage.jobSeeker => Icons.person_search_outlined,
  LifeStage.employee => Icons.badge_outlined,
  LifeStage.founder => Icons.rocket_launch_outlined,
  LifeStage.freelancer => Icons.laptop_mac_outlined,
  LifeStage.other => Icons.more_horiz_rounded,
};

/// 대화형 자기소개: 자유롭게 쓰면 AI([ProfileExtractor])가 상황·관심사를 근거와 함께 제안하고,
/// 사용자가 맞는 것만 남겨 적용한다. 더 쓰면 지금까지의 글 전체로 다시 제안한다.
class AboutMeSheet extends ConsumerStatefulWidget {
  const AboutMeSheet({super.key});

  @override
  ConsumerState<AboutMeSheet> createState() => _AboutMeSheetState();
}

class _AboutMeSheetState extends ConsumerState<AboutMeSheet> {
  late final _input = TextEditingController(text: ref.read(aboutMeProvider));
  final _scroll = ScrollController();
  final _messages = <String>[];
  bool _loading = false;
  ProfileSuggestion? _result;
  bool _stageOn = true;
  final Set<String> _tags = {};

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _input.text.trim();
    if (msg.isEmpty || _loading) return;
    setState(() {
      _messages.add(msg);
      _input.clear();
      _loading = true;
    });
    _scrollToEnd();
    final all = _messages.join('\n');
    unawaited(ref.read(aboutMeProvider.notifier).save(all));

    ProfileSuggestion s;
    final api = ref.read(geminiApiProvider);
    try {
      if (!api.isConfigured) throw const GeminiException('no key');
      s = await ProfileExtractor.extract(api, all, allowedTags: allowedInterestTags);
    } catch (_) {
      // 키 없음·할당량·오프라인 → 같은 형식의 키워드 제안 (AI 표시 없이).
      s = ProfileExtractor.keywordFallback(all, keywords: interestKeywords);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = s;
      _stageOn = s.stage != null;
      _tags
        ..clear()
        ..addAll(s.tags.map((t) => t.tag));
    });
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_scroll.hasClients || !mounted) return;
    final end = _scroll.position.maxScrollExtent;
    final d = Motion.of(context, Motion.normal);
    // "동작 줄이기"면 길이가 0 — animateTo는 0을 허용하지 않는다.
    d == Duration.zero ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: d, curve: Motion.curve);
  });

  int get _count => _tags.length + (_stageOn && _result?.stage != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final r = _result;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            // ── 제목 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.sm, 0),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: p.primary, size: 20),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(l10n.aboutMeTitle, style: t.titleMedium)),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── 대화 ──
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  _Bubble(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.aboutMeGreeting, style: t.bodyMedium),
                        if (_messages.isEmpty) ...[
                          const SizedBox(height: Space.md),
                          for (final ex in [l10n.aboutMeEx1, l10n.aboutMeEx2, l10n.aboutMeEx3])
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.xs),
                              child: ActionChip(
                                avatar: const Icon(Icons.edit_note_rounded),
                                label: Text(ex, maxLines: 2),
                                onPressed: () => setState(() => _input.text = ex),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  for (final m in _messages) _Bubble(mine: true, child: Text(m, style: t.bodyMedium)),
                  if (_loading)
                    _Bubble(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSpinner(size: 16, color: p.primary),
                          const SizedBox(width: Space.sm),
                          Text(l10n.aboutMeThinking, style: t.bodyMedium!.copyWith(color: p.textMuted)),
                        ],
                      ),
                    )
                  else if (r != null)
                    _Bubble(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.isEmpty)
                            Text(l10n.aboutMeNothing, style: t.bodyMedium)
                          else ...[
                            Row(
                              children: [
                                if (r.fromAi) ...[
                                  Pill(l10n.aboutMeAiBadge, icon: Icons.auto_awesome, tone: Tone.primary, dense: true),
                                  const SizedBox(width: Space.sm),
                                ],
                                Expanded(
                                  child: Text(
                                    r.fromAi ? l10n.aboutMeUnderstood : l10n.aboutMeKeyword,
                                    style: t.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            if (r.stage case final stage?)
                              _SuggestionRow(
                                icon: lifeStageIcon(stage),
                                label: l10n.aboutMeStage(context.tr(stage.label)),
                                quote: r.stageQuote,
                                on: _stageOn,
                                onChanged: (v) => setState(() => _stageOn = v),
                              ),
                            for (final s in r.tags)
                              if (interestByTag(s.tag) case final o?)
                                _SuggestionRow(
                                  icon: o.icon,
                                  label: context.tr(o.label),
                                  quote: s.quote,
                                  on: _tags.contains(s.tag),
                                  onChanged: (v) => setState(() => v ? _tags.add(s.tag) : _tags.remove(s.tag)),
                                ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── 적용 + 입력 ──
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r != null && !r.isEmpty && !_loading) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _count == 0
                                ? null
                                : () => Navigator.pop(
                                    context,
                                    AboutMeResult(stage: _stageOn ? r.stage : null, tags: {..._tags}),
                                  ),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(l10n.aboutMeApply(_count)),
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: ProfileExtractor.maxInputChars,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(hintText: l10n.aboutMeHint, counterText: ''),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          IconButton.filled(
                            tooltip: l10n.aboutMeSend,
                            onPressed: _loading ? null : _send,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(l10n.aboutMePrivacy, style: t.labelSmall, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child, this.mine = false});
  final Widget child;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.only(bottom: Space.md),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: mine ? p.primarySoft : p.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(Radii.lg),
            topRight: const Radius.circular(Radii.lg),
            bottomLeft: Radius.circular(mine ? Radii.lg : Radii.sm),
            bottomRight: Radius.circular(mine ? Radii.sm : Radii.lg),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 제안 한 줄: 켜기/끄기 + 이름 + 근거(사용자 글에서 잘라 온 문구).
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.label,
    required this.quote,
    required this.on,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String? quote;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () => onChanged(!on),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Checkbox(value: on, onChanged: (v) => onChanged(v ?? false)),
            Icon(icon, size: 18, color: on ? p.primary : p.textMuted),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.titleSmall),
                  if (quote != null && quote!.isNotEmpty)
                    Text(
                      '“$quote”',
                      style: t.bodySmall!.copyWith(color: p.textMuted, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

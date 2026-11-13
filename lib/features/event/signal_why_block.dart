import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_ext.dart';
import 'traffic_metadata.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'package:liferadar_core/liferadar_core.dart';

final _ruleCode = RegExp(r'^[A-Z0-9_]+$');

/// 신호 종류 → (이름, 아이콘, 톤). 카드와 상세 화면이 같은 모습이 되도록.
(String, IconData, Tone) insightKindMeta(BuildContext context, InsightKind kind) {
  final l10n = context.l10n;
  return switch (kind) {
    InsightKind.planAlert => (l10n.kindPlanAlert, Icons.notifications_active_outlined, Tone.info),
    InsightKind.deadline => (l10n.kindDeadline, Icons.schedule_outlined, Tone.accent),
    InsightKind.opportunity => (l10n.kindOpportunity, Icons.auto_awesome_outlined, Tone.primary),
    InsightKind.route => (l10n.kindRoute, Icons.alt_route_rounded, Tone.primary),
  };
}

/// "이 신호가 뜬 이유" — 신호 종류에 맞는 부드러운 색의 작은 블록(선·테두리 없음):
/// 처음에는 핵심 문장 두 줄만. "더 보기"를 누르면 이유·교통 근거·출처까지 펼친다.
/// [standalone] — 행사 없는 신호 창: 제목, 신호 표시, 출처 링크도 여기에.
class SignalWhyBlock extends StatefulWidget {
  const SignalWhyBlock({super.key, required this.insight, this.standalone = false});

  final Insight insight;
  final bool standalone;

  @override
  State<SignalWhyBlock> createState() => _SignalWhyBlockState();
}

class _SignalWhyBlockState extends State<SignalWhyBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final standalone = widget.standalone;
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final (label, icon, tone) = insightKindMeta(context, insight.kind);
    final (fg, bg) = switch (tone) {
      Tone.info => (p.info, p.infoSoft),
      Tone.accent => (p.accent, p.accentSoft),
      Tone.danger => (p.danger, p.dangerSoft),
      _ => (p.primary, p.primarySoft),
    };
    final links = insight.sources.where((s) => s.url != null && (insight.trafficContext == null || safeTrafficUrl(s.url))).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: Space.sm),
              Text(label, style: t.labelLarge!.copyWith(color: fg)),
              const Spacer(),
              if (insight.aiModel != null) ...[
                Tooltip(
                  message: l10n.aiWritten,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: fg),
                    const SizedBox(width: 2),
                    Text('AI', style: t.labelSmall!.copyWith(color: fg)),
                  ]),
                ),
                const SizedBox(width: Space.sm),
              ],
              Text(l10n.confidence((insight.confidence * 100).round()), style: t.labelSmall),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (standalone) ...[Text(context.tr(insight.title), style: t.titleMedium), const SizedBox(height: Space.xs)],
          SmoothSize(
            alignment: Alignment.topCenter,
            child: Text(
              context.tr(insight.body),
              maxLines: _open ? null : 2,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: t.bodyMedium!.copyWith(color: p.text, height: 1.5),
            ),
          ),
          if (_open) ...[
          const SizedBox(height: Space.sm),
          Text(context.tr(insight.why), style: t.bodySmall),
          if (insight.trafficContext != null) TrafficMetadata(insight.trafficContext!, detailed: true),
          ],
          if (_open && standalone) ...[
            // 규칙 코드(예: AMBIGUOUS_CORE_FIELDS)는 사람에게 보여주지 않는다.
            if (insight.signals.where((s) => !_ruleCode.hasMatch(context.tr(s.summary))).toList() case final tags
                when tags.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              QuietTags([for (final s in tags) QuietTag(context.tr(s.summary), icon: signalIcon(s.type))]),
            ],
            const SizedBox(height: Space.md),
            Text('${l10n.sources} · ${insight.sources.map((s) => s.title).join(', ')}', style: t.labelSmall),
            if (insight.aiModel != null) Text('${l10n.aiWritten} · ${insight.aiModel}', style: t.labelSmall),
            for (final s in links)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(Uri.parse(s.url!), mode: LaunchMode.externalApplication),
                  child: Text(insight.trafficContext?.source == 'utic' ? context.tr(const LocalizedText(ko: 'UTIC에서 확인', en: 'Check on UTIC')) : l10n.openSource),
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                foregroundColor: fg,
              ),
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
              label: Text(_open ? l10n.showLess : l10n.showMore),
            ),
          ),
        ],
      ),
    );
  }
}

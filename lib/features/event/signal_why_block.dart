import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'package:liferadar_core/liferadar_core.dart';

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
/// 종류 + 신뢰도, 핵심 문장 하나, 그 아래 이유(차분하게).
/// [standalone] — 행사 없는 신호 창: 제목, 신호 표시, 출처 링크도 여기에.
class SignalWhyBlock extends StatelessWidget {
  const SignalWhyBlock({super.key, required this.insight, this.standalone = false});

  final Insight insight;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
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
    final links = insight.sources.where((s) => s.url != null).toList();

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
          Text(context.tr(insight.body), style: t.bodyMedium!.copyWith(color: p.text, height: 1.5)),
          const SizedBox(height: Space.sm),
          Text(context.tr(insight.why), style: t.bodySmall),
          if (standalone) ...[
            if (insight.signals.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              QuietTags([for (final s in insight.signals) QuietTag(context.tr(s.summary), icon: signalIcon(s.type))]),
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
                  child: Text(l10n.openSource),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

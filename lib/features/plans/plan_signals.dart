import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart' show Tone;
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 일정에 영향을 주는 짧은 메시지 하나 (카드 아래 / 일정 창).
/// 출처는 InsightEngine 규칙 (날씨 API, 축제·공고 데이터)이며 AI가 아니다.
class PlanSignal {
  const PlanSignal({required this.insight, required this.icon, required this.text, required this.tone, this.event});
  final Insight insight;
  final IconData icon;
  final String text;
  final Tone tone;
  final RadarEvent? event;
}

/// 일정의 신호 — 중요도 순 (경고 → 기회).
List<PlanSignal> planSignals(BuildContext context, WidgetRef ref, Plan plan) {
  final l10n = context.l10n;
  final insights = ref
      .watch(insightsProvider)
      .where((i) => i.planId == plan.id && i.feedback != InsightFeedback.hidden);
  final out = <PlanSignal>[];
  for (final i in insights) {
    final event = i.eventIds.isEmpty ? null : ref.watch(eventByIdProvider(i.eventIds.first));
    if (i.trafficContext != null || i.id.startsWith('travel:') || i.id.startsWith('news-traffic:')) {
      out.add(PlanSignal(insight: i, icon: Icons.traffic_outlined, text: context.tr(i.title), tone: Tone.info));
    } else if (i.id.startsWith('rain:')) {
      out.add(PlanSignal(insight: i, icon: Icons.umbrella_outlined, text: l10n.planSignalRain, tone: Tone.info));
    } else if (i.id.startsWith('crowd:') && event != null) {
      out.add(
        PlanSignal(
          insight: i,
          event: event,
          icon: Icons.groups_2_outlined,
          text: l10n.planSignalCrowd(context.tr(event.title)),
          tone: Tone.accent,
        ),
      );
    } else if (event != null) {
      out.add(
        PlanSignal(
          insight: i,
          event: event,
          icon: Icons.auto_awesome_outlined,
          text: l10n.planSignalNearby(context.tr(event.title)),
          tone: Tone.primary,
        ),
      );
    }
  }
  int rank(PlanSignal s) => switch (s.tone) {
    Tone.info => 0,
    Tone.accent => 1,
    _ => 2,
  };
  // 같은 문장(같은 통제를 다룬 공지·기사 여러 개)은 한 줄만.
  final texts = <String>{};
  out.retainWhere((s) => texts.add(s.text));
  return out..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// 카드 아래의 간결한 줄: 아이콘 + 한 줄 텍스트 (톤 색상).
class PlanSignalLine extends StatelessWidget {
  const PlanSignalLine(this.signal, {super.key});
  final PlanSignal signal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (signal.tone) {
      Tone.info => p.info,
      Tone.accent => p.accent,
      _ => p.primary,
    };
    return Row(
      children: [
        Icon(signal.icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            signal.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.labelMedium!.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

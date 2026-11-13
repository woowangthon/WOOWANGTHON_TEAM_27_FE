import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/widgets.dart';
import '../../data/plan_travel.dart';

String planTravelModeLabel(BuildContext context, String mode) {
  final l10n = context.l10n;
  return switch (mode) {
    'bus' => l10n.planTravelBus,
    'subway' => l10n.planTravelSubway,
    'rail' => l10n.planTravelRail,
    'air' => l10n.planTravelAir,
    _ => l10n.planTravelCar,
  };
}

/// "기차 · KTX 오송→부산 · 09:30 출발 · 오송역에서"
String planTravelSummary(BuildContext context, PlanTravel travel) {
  final l10n = context.l10n;
  return [
    planTravelModeLabel(context, travel.mode),
    if (travel.lines.isNotEmpty) travel.lines.join(', '),
    if (travel.departure != null)
      l10n.planTravelDepartAt(DateFormat.Hm(context.lang).format(travel.departure!.toLocal())),
    if (travel.originName != null) l10n.planTravelFrom(travel.originName!),
  ].join(' · ');
}

/// 일정 카드·상세에 보이는 이동 방법 한 줄. 입력이 없으면 아무것도 그리지 않는다.
class PlanTravelLine extends ConsumerWidget {
  const PlanTravelLine({super.key, required this.plan, this.maxLines = 1});
  final Plan plan;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final travel = PlanTravelController.lookupIn(ref.watch(planTravelProvider), plan);
    if (travel == null) return const SizedBox.shrink();
    return MetaRow(planTravelIcon(travel.mode), planTravelSummary(context, travel), maxLines: maxLines);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../data/plan_routes.dart';
import 'plan_route_sheet.dart';

/// Compact insertion point, replaced by the saved route between adjacent plans.
class PlanRouteConnector extends ConsumerWidget {
  const PlanRouteConnector({super.key, required this.from, required this.to});
  final Plan from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canConnectPlans(from, to)) return const SizedBox.shrink();
    final stored = ref.watch(planRoutesProvider)[planRouteKey(from, to)];
    final route = stored != null && stored.matches(from, to) ? stored : null;
    final p = context.palette, t = context.textStyles;
    final l10n = context.l10n;
    void edit() =>
        showPlanRouteSheet(context, from: from, to: to, saved: route);
    final endpoints =
        '${from.locationText.isEmpty ? l10n.noLocation : from.locationText} → '
        '${to.locationText.isEmpty ? l10n.noLocation : to.locationText}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.md,
      ),
      child: Column(
        children: [
          _Dots(color: p.primary.withValues(alpha: 0.45)),
          if (route == null) ...[
            OutlinedButton.icon(
              onPressed: edit,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.primary,
                backgroundColor: p.surface,
                side: BorderSide(color: p.primary.withValues(alpha: 0.6)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.sm,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(l10n.planRouteAdd),
            ),
            const SizedBox(height: Space.xs),
            Text(
              endpoints,
              style: t.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Material(
                color: p.primarySoft,
                borderRadius: BorderRadius.circular(Radii.lg),
                child: InkWell(
                  onTap: edit,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Space.sm),
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Icon(
                            Icons.directions_transit_rounded,
                            color: p.onPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.planRouteTitle,
                                      style: t.titleSmall,
                                    ),
                                  ),
                                  const SizedBox(width: Space.xs),
                                  Text(
                                    l10n.routeEdit,
                                    style: t.labelMedium!.copyWith(
                                      color: p.primary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: p.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                '${route.origin} → ${route.destination}',
                                style: t.labelLarge,
                              ),
                              const SizedBox(height: Space.sm),
                              Wrap(
                                spacing: Space.xs,
                                runSpacing: Space.xs,
                                children: [
                                  for (final line in route.lines)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Space.sm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.surface,
                                        borderRadius: BorderRadius.circular(
                                          Radii.sm,
                                        ),
                                      ),
                                      child: Text(
                                        line,
                                        style: t.labelSmall!.copyWith(
                                          color: p.primaryStrong,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    routeDuration(
                                      context,
                                      route.durationSeconds,
                                    ),
                                    style: t.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                '${l10n.planRouteDeparture} ${DateFormat.Hm(context.lang).format(route.departure.toLocal())}'
                                ' → ${l10n.planRouteArrival} ${DateFormat.Hm(context.lang).format(route.arrival.toLocal())}',
                                style: t.bodySmall,
                              ),
                              if (route.arrival.isAfter(to.start)) ...[
                                const SizedBox(height: Space.xs),
                                Text(
                                  l10n.planRouteLate,
                                  style: t.bodySmall!.copyWith(color: p.danger),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          _Dots(color: p.primary.withValues(alpha: 0.45)),
        ],
      ),
    );
  }
}

String routeDuration(BuildContext context, int seconds) {
  final minutes = (seconds / 60).ceil();
  return context.l10n.hoursMinutes(minutes ~/ 60, minutes % 60);
}

class _Dots extends StatelessWidget {
  const _Dots({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ],
    ),
  );
}

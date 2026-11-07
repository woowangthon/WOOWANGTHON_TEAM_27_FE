import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'route_controller.dart';

/// 지도의 경로 모드 하단 패널: 출발 / 도착 / 날짜 → 결과.
class RoutePanel extends ConsumerStatefulWidget {
  const RoutePanel({super.key, required this.onOpportunityTap});

  final void Function(RouteOpportunity) onOpportunityTap;

  @override
  ConsumerState<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends ConsumerState<RoutePanel> {
  /// 결과가 나오면 지도를 보도록 패널을 접을 수 있다.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final s = ref.watch(routeProvider);
    final c = ref.read(routeProvider.notifier);
    final summary = s.route == null || s.status == RouteStatus.error ? null : _summary(context, s.route!);
    final loading = s.status == RouteStatus.loading;

    final decoration = BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.xl),
      border: Border.all(color: p.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
    );

    final collapsed = _collapsed && summary != null;

    return SmoothSize(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: collapsed
            ? ListTile(
                contentPadding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.sm, Space.xs),
                leading: const IconTile(Icons.alt_route_rounded, size: 40),
                title: Text(summary, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(l10n.routeAlongTheWay(s.opportunities.length)),
                trailing: Icon(Icons.expand_less_rounded, color: p.textMuted),
                onTap: () => setState(() => _collapsed = false),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.52),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
                  children: [
                    SegmentedButton<TravelMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: TravelMode.transit,
                          icon: const Icon(Icons.train_outlined, size: 18),
                          label: Text(l10n.travelTransit),
                        ),
                        ButtonSegment(
                          value: TravelMode.car,
                          icon: const Icon(Icons.directions_car_outlined, size: 18),
                          label: Text(l10n.travelCar),
                        ),
                      ],
                      selected: {s.mode},
                      onSelectionChanged: (v) => c.setMode(v.first),
                    ),
                    const SizedBox(height: Space.md),

                    // ── 출발 / 도착 ──
                    Container(
                      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(Radii.lg)),
                      child: Row(
                        children: [
                          const SizedBox(width: Space.md),
                          Column(
                            children: [
                              Icon(Icons.trip_origin_rounded, size: 14, color: p.primary),
                              Container(width: 2, height: 22, color: p.border),
                              Icon(Icons.place_rounded, size: 16, color: p.accent),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                _PlaceField(label: l10n.routeFrom, place: s.origin, onPicked: c.setOrigin),
                                Divider(height: 1, indent: Space.md, color: p.border),
                                _PlaceField(label: l10n.routeTo, place: s.destination, onPicked: c.setDestination),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '${l10n.routeFrom} ↔ ${l10n.routeTo}',
                            onPressed: c.swap,
                            icon: const Icon(Icons.swap_vert_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today_outlined),
                          label: Text(context.formatDate(s.date)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: s.date,
                              firstDate: DateTime(2026, 1, 1),
                              lastDate: DateTime(2027, 12, 31),
                            );
                            if (picked != null) c.setDate(picked);
                          },
                        ),
                        const Spacer(),
                        TextButton(onPressed: c.useDemo, child: Text(l10n.routeDemo)),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    FilledButton.icon(
                      onPressed: s.canSearch ? c.search : null,
                      icon: loading ? AppSpinner(color: p.textMuted) : const Icon(Icons.alt_route_rounded),
                      label: Text(loading ? l10n.searching : l10n.routeFind),
                    ),

                    if (s.status == RouteStatus.error) ...[
                      const SizedBox(height: Space.md),
                      Container(
                        padding: const EdgeInsets.all(Space.md),
                        decoration: BoxDecoration(color: p.dangerSoft, borderRadius: BorderRadius.circular(Radii.md)),
                        child: Text(l10n.routeError(friendlyError(l10n, s.error)), style: t.bodySmall!.copyWith(color: p.danger)),
                      ),
                    ],

                    if (loading && s.route == null) ...[
                      const SizedBox(height: Space.lg),
                      const Shimmer(
                        child: Column(
                          children: [
                            SkeletonBox(height: 16, width: 220),
                            SizedBox(height: Space.md),
                            SkeletonCard(lines: 1),
                          ],
                        ),
                      ),
                    ],

                    if (summary != null) ...[
                      const SizedBox(height: Space.lg),
                      Row(
                        children: [
                          Expanded(child: Text(summary, style: t.titleSmall)),
                          IconButton(
                            tooltip: l10n.routeAlongTheWay(s.opportunities.length),
                            icon: const Icon(Icons.expand_more_rounded),
                            onPressed: () => setState(() => _collapsed = true),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: Space.sm),
                      Text(l10n.routeAlongTheWay(s.opportunities.length), style: t.labelMedium),
                      const SizedBox(height: Space.xs),
                      if (s.opportunities.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.md),
                          child: Text(l10n.routeNoOpportunities, style: t.bodySmall),
                        ),
                      for (var i = 0; i < s.opportunities.length; i++)
                        FadeSlideIn(
                          index: i,
                          child: _OpportunityTile(
                            s.opportunities[i],
                            onTap: () => widget.onOpportunityTap(s.opportunities[i]),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

String _summary(BuildContext context, TravelRoute r) {
  final l10n = context.l10n;
  final km = (r.distanceMeters / 1000).toStringAsFixed(1);
  final dur = _duration(context, r.durationSeconds);
  return r.mode == TravelMode.transit
      ? l10n.routeSummaryTransit(km, dur, r.transitLines.isEmpty ? l10n.travelTransit : r.transitLines.join(' → '))
      : l10n.routeSummary(km, dur);
}

String _duration(BuildContext context, int seconds) {
  final m = (seconds / 60).round();
  return context.l10n.hoursMinutes(m ~/ 60, m % 60);
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile(this.o, {required this.onTap});
  final RouteOpportunity o;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final detour = o.detourKm == null ? null : l10n.routeDetour(o.detourKm!.toStringAsFixed(1), o.detourMinutes!);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            IconTile(categoryIcon(o.event.category), tone: Tone.info),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr(o.event.title), style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${context.formatDateTime(o.event.start)} · ${o.event.city}', style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            detour == null
                ? Pill(l10n.routeFromRoute(o.distanceFromRouteKm.toStringAsFixed(1)), dense: true)
                : Pill(detour, tone: Tone.info, dense: true),
          ],
        ),
      ),
    );
  }
}

class _PlaceField extends ConsumerWidget {
  const _PlaceField({required this.label, required this.place, required this.onPicked});

  final String label;
  final Place? place;
  final void Function(Place) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () async {
          final picked = await showModalBottomSheet<Place>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const PlaceSearchSheet(),
          );
          if (picked != null) onPicked(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(label, style: t.labelMedium)),
              Expanded(
                child: Text(
                  place?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall!.copyWith(color: place == null ? p.textMuted : p.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kakao Local 검색 (debounce 적용).
class PlaceSearchSheet extends ConsumerStatefulWidget {
  const PlaceSearchSheet({super.key});

  @override
  ConsumerState<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<PlaceSearchSheet> {
  Timer? _debounce;
  List<Place> _results = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(kakaoApiProvider).searchPlaces(q);
      if (!mounted || q != _query) return;
      setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextField(
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.routeSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(_error!, style: context.textStyles.bodySmall!.copyWith(color: p.danger)),
              ),
            if (_loading && _results.isEmpty)
              const Expanded(
                child: Shimmer(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
                    child: Column(children: [_SkeletonRow(), _SkeletonRow(), _SkeletonRow(), _SkeletonRow()]),
                  ),
                ),
              )
            else if (!_loading && _error == null && _query.isNotEmpty && _results.isEmpty)
              Expanded(
                child: EmptyState(icon: Icons.search_off_rounded, title: l10n.routeNoResults),
              )
            else
              Expanded(
                child: AnimatedOpacity(
                  duration: Motion.of(context, Motion.fast),
                  opacity: _loading ? 0.5 : 1,
                  child: ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(indent: 72),
                    itemBuilder: (_, i) {
                      final place = _results[i];
                      return ListTile(
                        leading: const IconTile(Icons.place_outlined, tone: Tone.neutral),
                        title: Text(place.name),
                        subtitle: Text(place.address),
                        onTap: () => Navigator.pop(context, place),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: Space.md),
    child: Row(
      children: [
        SkeletonBox(width: 40, height: 40, radius: Radii.md),
        SizedBox(width: Space.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 140, height: 14),
              SizedBox(height: Space.sm),
              SkeletonBox(height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

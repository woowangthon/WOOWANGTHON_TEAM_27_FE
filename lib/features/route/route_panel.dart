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
///
/// 결과가 나오면 손잡이를 끌어내리거나 지도를 눌러 패널을 내릴 수 있고, 내려간 패널을 누르거나
/// 끌어올리면 다시 펼쳐진다. 처음 한 번은 움직이는 안내로 이 동작을 알려 준다.
class RoutePanel extends ConsumerStatefulWidget {
  const RoutePanel({super.key, required this.onOpportunityTap, required this.collapsed});

  final void Function(RouteOpportunity) onOpportunityTap;

  /// 접힘 상태 — 지도 화면도 바꾼다 (지도를 누르면 접힘).
  final ValueNotifier<bool> collapsed;

  @override
  ConsumerState<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends ConsumerState<RoutePanel> with SingleTickerProviderStateMixin {
  static const _hintKey = 'hint:route_panel_drag';

  /// 손잡이를 끄는 중인 거리 (아래 +).
  double _drag = 0;
  bool _hint = false;

  /// 결과가 있을 때 출발·도착 입력을 다시 펼쳐 수정 중인지.
  bool _editing = false;
  Timer? _hintTimer;
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    widget.collapsed.addListener(_onCollapsedChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(routeProvider).route != null) _maybeShowHint();
    });
  }

  @override
  void dispose() {
    widget.collapsed.removeListener(_onCollapsedChanged);
    _hintTimer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  void _onCollapsedChanged() {
    if (widget.collapsed.value) _dismissHint();
    if (mounted) setState(() {});
  }

  void _setCollapsed(bool v) => widget.collapsed.value = v;

  /// 경로 결과를 처음 볼 때 한 번: 패널이 살짝 내려갔다 올라오며 "끌어내리기"를 보여 준다.
  void _maybeShowHint() {
    final prefs = ref.read(sharedPrefsProvider);
    if (_hint || (prefs.getBool(_hintKey) ?? false)) return;
    setState(() => _hint = true);
    if (!MediaQuery.disableAnimationsOf(context)) _bounce.repeat(reverse: true);
    // 몇 초 뒤 움직임만 멈추고, 안내 문구는 처음 내려 볼 때까지 남긴다.
    _hintTimer = Timer(
      const Duration(seconds: 6),
      () => _bounce
        ..stop()
        ..value = 0,
    );
  }

  void _dismissHint() {
    if (!_hint) return;
    _hintTimer?.cancel();
    _bounce
      ..stop()
      ..value = 0;
    ref.read(sharedPrefsProvider).setBool(_hintKey, true);
    if (mounted) setState(() => _hint = false);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _dismissHint();
    setState(() => _drag += d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final collapsed = widget.collapsed.value;
    if (!collapsed && (_drag > 56 || v > 400)) _setCollapsed(true);
    if (collapsed && (_drag < -24 || v < -400)) _setCollapsed(false);
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final s = ref.watch(routeProvider);
    final c = ref.read(routeProvider.notifier);
    final filter = ref.watch(routeFilterProvider);
    final interests = ref.watch(interestsProvider);
    final summary = s.route == null || s.status == RouteStatus.error ? null : _summary(context, s.route!);
    final loading = s.status == RouteStatus.loading;

    ref.listen<RouteState>(routeProvider, (prev, next) {
      if (next.route != null && prev?.route != next.route) {
        if (_editing) setState(() => _editing = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowHint();
        });
      }
    });

    final decoration = BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.xl),
      border: Border.all(color: p.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
    );

    final collapsed = widget.collapsed.value && summary != null;

    // 경로 주변 행사: 필터 칩 (전체 · 내 관심사 · 카테고리).
    final opps = s.opportunities;
    final shown = [
      for (final o in opps)
        if (routeFilterMatches(filter, o.event, interests)) o,
    ];
    final categories = opps.map((o) => o.event.category).toSet().toList()..sort((a, b) => a.index.compareTo(b.index));
    final mineCount = opps.where((o) => routeFilterMatches(routeFilterMine, o.event, interests)).length;
    void setFilter(String? f) => ref.read(routeFilterProvider.notifier).set(filter == f ? null : f);

    /// 손잡이 — 끌어서 내리고 올린다. 누르면 전환.
    Widget handle() => Semantics(
      button: true,
      label: collapsed ? l10n.routePanelExpand : l10n.routePanelCollapse,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setCollapsed(!collapsed),
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
              ),
              if (_hint && !collapsed)
                AnimatedBuilder(
                  animation: _bounce,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, 4 * Curves.easeInOut.transform(_bounce.value)),
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_double_arrow_down_rounded, size: 18, color: p.primary),
                        const SizedBox(width: Space.xs),
                        Text(l10n.routePanelHint, style: t.labelMedium!.copyWith(color: p.primary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final Widget body = collapsed
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                handle(),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.sm, Space.xs),
                  leading: const IconTile(Icons.alt_route_rounded, size: 40),
                  title: Text(summary, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(l10n.routeAlongTheWay(shown.length)),
                  trailing: Icon(Icons.expand_less_rounded, color: p.textMuted),
                  onTap: () => _setCollapsed(false),
                ),
              ],
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (summary != null) handle(),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(Space.lg, summary != null ? Space.xs : Space.lg, Space.lg, Space.md),
                    children: [
                      if (summary != null && !_editing)
                        // 결과가 있으면 입력 부분을 한 줄로 접어 목록이 더 보이게 한다.
                        Row(
                          children: [
                            Icon(
                              s.mode == TravelMode.transit ? Icons.train_outlined : Icons.directions_car_outlined,
                              size: 18,
                              color: p.primary,
                            ),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                '${s.origin?.name ?? '—'} → ${s.destination?.name ?? '—'} · ${context.formatDate(s.date)}',
                                style: t.labelLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _editing = true),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(l10n.routeEdit),
                            ),
                          ],
                        )
                      else ...[
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
                      ],

                      if (s.status == RouteStatus.error) ...[
                        const SizedBox(height: Space.md),
                        Container(
                          padding: const EdgeInsets.all(Space.md),
                          decoration: BoxDecoration(color: p.dangerSoft, borderRadius: BorderRadius.circular(Radii.md)),
                          child: Text(
                            l10n.routeError(friendlyError(l10n, s.error)),
                            style: t.bodySmall!.copyWith(color: p.danger),
                          ),
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
                        SizedBox(height: _editing ? Space.lg : Space.xs),
                        Row(
                          children: [
                            Expanded(child: Text(summary, style: t.titleSmall)),
                            IconButton(
                              tooltip: l10n.routePanelCollapse,
                              icon: const Icon(Icons.expand_more_rounded),
                              onPressed: () => _setCollapsed(true),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: Space.sm),
                        Text(l10n.routeAlongTheWay(shown.length), style: t.labelMedium),
                        if (opps.length > 1) ...[
                          const SizedBox(height: Space.sm),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ChoiceChip(
                                  label: Text('${l10n.discoverAll} ${opps.length}'),
                                  selected: filter == null,
                                  onSelected: (_) => ref.read(routeFilterProvider.notifier).set(null),
                                ),
                                if (mineCount > 0) ...[
                                  const SizedBox(width: Space.sm),
                                  ChoiceChip(
                                    avatar: const Icon(Icons.favorite_border_rounded),
                                    label: Text('${l10n.filterMine} $mineCount'),
                                    selected: filter == routeFilterMine,
                                    onSelected: (_) => setFilter(routeFilterMine),
                                  ),
                                ],
                                if (categories.length > 1)
                                  for (final cat in categories) ...[
                                    const SizedBox(width: Space.sm),
                                    ChoiceChip(
                                      avatar: Icon(categoryIcon(cat)),
                                      label: Text(context.categoryLabel(cat)),
                                      selected: filter == cat.name,
                                      onSelected: (_) => setFilter(cat.name),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.xs),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: Space.md),
                            child: Text(l10n.routeNoOpportunities, style: t.bodySmall),
                          ),
                        for (var i = 0; i < shown.length; i++)
                          FadeSlideIn(
                            key: ValueKey('${filter}_${shown[i].event.id}'),
                            index: i,
                            child: _OpportunityTile(shown[i], onTap: () => widget.onOpportunityTap(shown[i])),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

    // 끄는 동안 패널이 손가락을 따라 움직인다; 안내 중에는 살짝 내려갔다 올라온다.
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        final dy = collapsed
            ? _drag.clamp(-40.0, 0.0) * 0.5
            : _drag.clamp(0.0, 240.0) + 10 * Curves.easeInOut.transform(_bounce.value);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: SmoothSize(
        alignment: Alignment.bottomCenter,
        child: Container(decoration: decoration, clipBehavior: Clip.antiAlias, child: body),
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
                  Text(
                    // 이미 진행 중인 전시·행사: 지난 시작일 대신 "~종료일".
                    '${o.event.start.isBefore(DateTime.now()) ? '~${context.formatDate(o.event.end)}' : context.formatDateTime(o.event.start)} · ${o.event.city}',
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

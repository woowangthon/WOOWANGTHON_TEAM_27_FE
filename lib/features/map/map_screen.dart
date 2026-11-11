import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as km;

import '../../core/errors.dart';
import '../../core/env.dart';
import '../../core/kakao_sdk_check.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../event/event_detail_sheet.dart';
import '../plans/plan_detail_sheet.dart';
import '../route/route_controller.dart';
import '../route/route_panel.dart';
import '../../core/map_theme/map_theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/location.dart';
import 'marker_icons.dart';

enum MapMode { explore, myMap, route }

enum MapLayer { plans, recommended, route }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _seoul = km.LatLng(37.5665, 126.9780);

  km.KakaoMapController? _map;
  bool _ready = false;
  String? _mapError;
  int _mapGeneration = 0;
  MapMode _mode = MapMode.explore;
  final Set<MapLayer> _layers = {MapLayer.plans, MapLayer.recommended};

  /// 레이어별로 그려진 Poi (숨기기/보이기용).
  final Map<MapLayer, List<km.Poi>> _pois = {for (final l in MapLayer.values) l: []};

  /// 그려진 경로 선 (Route 레이어).
  km.Route? _routeLine;

  /// 경로 기회 Poi → opportunity (누르면 우회 정보 표시용).
  final Map<String, RouteOpportunity> _routeOppByEventId = {};

  /// 경로 기회 Poi (행사 id별) — 경로 필터에 맞지 않는 것은 숨긴다.
  final Map<String, km.Poi> _routeOppPois = {};

  /// 경로 패널 접힘 상태 — 지도를 누르면 패널을 내려 지도를 넓게 본다.
  final _panelCollapsed = ValueNotifier(false);

  Timer? _readyTimeout;

  @override
  void initState() {
    super.initState();
    _startReadyTimeout();
  }

  void _startReadyTimeout() {
    _readyTimeout?.cancel();
    _readyTimeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !_ready && _canShowMap) {
        setState(() => _mapError = 'Map initialization timed out');
      }
    });
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    _panelCollapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // 홈/발견에서 "지도에서 보기"로 들어왔을 때.
    ref.listen<String?>(mapFocusProvider, (_, id) {
      if (id != null) _focusEvent(id);
    });

    // 새 경로나 우회 결과가 오면 다시 그린다.
    // 캘린더 동기화 후에는 일정이 바뀐다.
    ref.listen<List<Plan>>(plansProvider, (_, next) {
      _drawing = _drawing.then((_) => _drawPlans(next)).catchError((_) {});
    });

    ref.listen<MyLocation>(myLocationProvider, (prev, next) {
      if (next.position != null && next.position != prev?.position) _drawMe(next.position);
    });

    ref.listen<RouteState>(routeProvider, (prev, next) {
      if (prev?.route != next.route || prev?.opportunities != next.opportunities) {
        _drawRoute(next, fit: prev?.route != next.route);
      }
      if (next.route != null && prev?.route != next.route) _panelCollapsed.value = false;
    });

    ref.listen<String?>(routeFilterProvider, (_, _) {
      _drawing = _drawing.then((_) => _applyRouteFilter()).catchError((_) {});
    });

    final p = context.palette;
    // 다크 모드에서는 지도 타일도 어둡게 (웹: CSS 필터).
    setMapDarkMode(Theme.of(context).brightness == Brightness.dark);
    final floating = BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: p.border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(context)),
          // 지도가 준비될 때까지 스켈레톤
          if (!_ready && _canShowMap)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: p.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: Space.md),
                        Text(l10n.searching),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassSegmented<MapMode>(
                    values: MapMode.values,
                    selected: _mode,
                    onChanged: _setMode,
                    label: (m) => switch (m) {
                      MapMode.explore => l10n.modeExplore,
                      MapMode.myMap => l10n.modeMyMap,
                      MapMode.route => l10n.modeRoute,
                    },
                    icon: (m, on) => switch (m) {
                      MapMode.explore => Icons.travel_explore,
                      MapMode.myMap => on ? Icons.person_pin_circle : Icons.person_pin_circle_outlined,
                      MapMode.route => Icons.alt_route_rounded,
                    },
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _layerChip(MapLayer.plans, l10n.layerPlans, AppColors.plan, floating),
                      _layerChip(MapLayer.recommended, l10n.layerRecommended, AppColors.recommended, floating),
                      _layerChip(MapLayer.route, l10n.layerRoute, AppColors.route, floating),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_mode != MapMode.route && _ready)
            Positioned(
              right: Space.lg,
              bottom: Space.lg + MediaQuery.paddingOf(context).bottom,
              child: Column(
                children: [
                  _roundButton(
                    floating,
                    tooltip: l10n.myLocation,
                    icon: _locating
                        ? AppSpinner(size: 20)
                        : Icon(
                            ref.watch(myLocationProvider).status == LocationStatus.located
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            color: p.primary,
                          ),
                    onPressed: _goToMe,
                  ),
                  const SizedBox(height: Space.sm),
                  _roundButton(
                    floating,
                    tooltip: l10n.modeExplore,
                    icon: Icon(Icons.fit_screen_outlined, color: p.text),
                    onPressed: _fitAll,
                  ),
                ],
              ),
            ),
          if (_mode == MapMode.route)
            Positioned(
              left: Space.md,
              right: Space.md,
              bottom: Space.md + MediaQuery.paddingOf(context).bottom,
              child: RoutePanel(onOpportunityTap: _openOpportunity, collapsed: _panelCollapsed),
            ),
        ],
      ),
    );
  }

  /// 떠 있는 원형 버튼. (copyWith(borderRadius: null)은 radius를 지우지 않음 → 새 BoxDecoration.)
  Widget _roundButton(
    BoxDecoration floating, {
    required String tooltip,
    required Widget icon,
    VoidCallback? onPressed,
  }) => GlassSurface(
    opacity: 0.84,
    blur: 24,
    child: IconButton(tooltip: tooltip, icon: icon, onPressed: onPressed),
  );

  // ---------- 내 위치 ----------

  km.Poi? _mePoi;
  bool _locating = false;

  /// 위치가 바뀌면 파란 점을 그리거나 옮긴다.
  Future<void> _drawMe(GeoPoint? at) async {
    final map = _map;
    if (map == null || at == null) return;
    if (_mePoi == null) {
      _mePoi = await map.labelLayer.addPoi(
        _ll(at),
        id: 'me',
        style: km.PoiStyle(icon: await MarkerIcons.myLocation(AppColors.route), anchor: const km.KPoint(0.5, 0.5)),
        rank: 30, // 모든 마커 위에
      );
    } else {
      await _mePoi!.move(_ll(at), 400);
    }
  }

  Future<void> _goToMe() async {
    final l10n = context.l10n;
    var me = ref.read(myLocationProvider);
    if (me.status != LocationStatus.located) {
      setState(() => _locating = true);
      await ref.read(myLocationProvider.notifier).start();
      if (!mounted) return;
      setState(() => _locating = false);
      me = ref.read(myLocationProvider);
    }
    switch (me.status) {
      case LocationStatus.located:
        await _drawMe(me.position);
        await _map?.moveCamera(
          km.CameraUpdate.newCenterPosition(_ll(me.position!), zoomLevel: 15),
          animation: const km.CameraAnimation(700),
        );
      case LocationStatus.denied:
        Toast.show(l10n.locationDenied, type: ToastType.warning);
      default:
        Toast.show(l10n.locationUnavailable, type: ToastType.error);
    }
  }

  bool get _canShowMap => Env.hasKakaoMapKey && isKakaoSdkLoaded() && _mapError == null;

  Widget _buildMap(BuildContext context) {
    final l10n = context.l10n;
    if (!Env.hasKakaoMapKey) return _MapMessage(l10n.mapKeyMissing);
    if (!isKakaoSdkLoaded()) return _MapMessage(l10n.mapSdkNotLoaded(Uri.base.origin));
    if (_mapError != null) {
      return _MapMessage(
        l10n.mapError(friendlyError(l10n, _mapError)),
        onRetry: () => setState(() {
          _mapError = null;
          _map = null;
          _ready = false;
          _mePoi = null;
          for (final pois in _pois.values) {
            pois.clear();
          }
          _routeLine = null;
          _routeOppPois.clear();
          _routeOppByEventId.clear();
          _mapGeneration++;
          _startReadyTimeout();
        }),
      );
    }
    return km.KakaoMap(
      key: ValueKey(_mapGeneration),
      // Keep Kakao's GL surface in the Android view hierarchy instead of a virtual display.
      forceHybridComposition: true,
      option: const km.KakaoMapOption(position: _seoul, zoomLevel: 7),
      onMapReady: _onMapReady,
      // 경로 결과가 있을 때 지도를 누르면 패널을 내린다.
      onMapClick: (_, _) => _collapsePanel(),
      onTerrainClick: (_, _) => _collapsePanel(),
      onMapError: (e) {
        if (mounted) setState(() => _mapError = e.toString());
      },
    );
  }

  void _collapsePanel() {
    if (_mode == MapMode.route && ref.read(routeProvider).route != null) _panelCollapsed.value = true;
  }

  /// 레이어 켜기/끄기 — 떠 있는 작은 "pill".
  /// 레이어 버튼 — 유리 "pill": 켜져 있으면 색 점이 채워지고 라벨이 진하다.
  Widget _layerChip(MapLayer layer, String label, Color color, BoxDecoration floating) {
    final p = context.palette;
    final on = _layers.contains(layer);
    final d = Motion.of(context, Motion.fast);
    return Semantics(
      toggled: on,
      button: true,
      child: GestureDetector(
        onTap: () => _setLayer(layer, !on),
        child: GlassSurface(
          opacity: on ? 0.84 : 0.6,
          blur: 24,
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: d,
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: on ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textStyles.labelMedium!.copyWith(
                  color: on ? p.text : p.textMuted,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 지도 로직 ----------

  Future<void> _onMapReady(km.KakaoMapController controller) async {
    if (!mounted) return;
    _readyTimeout?.cancel();
    _map = controller;
    if (mounted) setState(() => _ready = true);
    await _drawOverlays();
    final route = ref.read(routeProvider);
    if (route.route != null) {
      _drawRoute(route, fit: true);
    } else {
      await _fitAll();
    }
    final pending = ref.read(mapFocusProvider);
    if (pending != null) await _focusEvent(pending);
    // 내 위치 표시 (처음에는 브라우저/기기가 권한을 요청). 카메라는 전체 화면을 유지한다.
    final ok = await ref.read(myLocationProvider.notifier).start();
    if (ok) await _drawMe(ref.read(myLocationProvider).position);
  }

  Future<void> _drawOverlays() async {
    final map = _map;
    if (map == null) return;
    final events = ref.read(mapEventsProvider);

    await _drawPlans(ref.read(plansProvider));

    for (final e in events) {
      final icon = await MarkerIcons.pin(AppColors.recommended, categoryIcon(e.category));
      final poi = await map.labelLayer.addPoi(
        _ll(e.location),
        id: e.id,
        style: km.PoiStyle(icon: icon),
        visible: _layers.contains(MapLayer.recommended),
        onClick: () => _openEvent(e),
      );
      _pois[MapLayer.recommended]!.add(poi);
    }
  }

  /// "My Plans" 마커 — Google 캘린더 동기화 후 다시 그린다.
  Future<void> _drawPlans(List<Plan> plans) async {
    final map = _map;
    if (map == null) return;
    for (final poi in _pois[MapLayer.plans]!) {
      await poi.remove();
    }
    _pois[MapLayer.plans]!.clear();
    final planIcon = await MarkerIcons.pin(AppColors.plan, Icons.event);
    for (final p in plans) {
      if (p.location == null) continue;
      _pois[MapLayer.plans]!.add(
        await map.labelLayer.addPoi(
          _ll(p.location!),
          style: km.PoiStyle(
            icon: planIcon,
            textStyle: const [km.PoiTextStyle(size: 12, color: Colors.black87, stroke: 2, strokeColor: Colors.white)],
          ),
          text: p.title,
          rank: 10, // 일정을 행사 마커 위에
          visible: _layers.contains(MapLayer.plans),
          // 누르면 일정 상세 (수정·삭제 포함).
          onClick: () {
            if (mounted) showPlanDetail(context, p);
          },
        ),
      );
    }
  }

  Future<void> _setLayer(MapLayer layer, bool on) async {
    setState(() => on ? _layers.add(layer) : _layers.remove(layer));
    for (final poi in _pois[layer]!) {
      on ? await poi.show() : await poi.hide();
    }
    if (layer == MapLayer.route && on) await _applyRouteFilter();
    if (layer == MapLayer.route && _routeLine != null) {
      on ? await _routeLine!.show() : await _routeLine!.hide();
    }
  }

  // ---------- Route ----------

  /// 그리기 작업은 순서대로 실행한다 (경로 + 우회 결과가 자주 들어온다).
  Future<void> _drawing = Future.value();

  void _drawRoute(RouteState s, {required bool fit}) {
    _drawing = _drawing.then((_) => _doDrawRoute(s, fit: fit)).catchError((_) {});
  }

  Future<void> _doDrawRoute(RouteState s, {required bool fit}) async {
    final map = _map;
    if (map == null) return;

    // 이전 것 지우기
    if (_routeLine != null) {
      await map.routeLayer.removeRoute(_routeLine!);
      _routeLine = null;
    }
    for (final poi in _pois[MapLayer.route]!) {
      await poi.remove();
    }
    _pois[MapLayer.route]!.clear();
    _routeOppByEventId.clear();
    _routeOppPois.clear();

    final route = s.route;
    if (route == null || route.points.length < 2) return;
    final visible = _layers.contains(MapLayer.route);

    // 경로 선 (점을 줄여서 — 웹에서 빠르게 그려진다)
    final pts = RouteMatcher.sample(route.points, 0.3).map(_ll).toList();
    _routeLine = await map.routeLayer.addRoute(
      pts,
      km.RouteStyle(AppColors.route, 8, strokeColor: Colors.white, strokeWidth: 2),
    );
    if (!visible) await _routeLine!.hide();

    // 출발 / 도착
    final endIcon = await MarkerIcons.pin(AppColors.route, Icons.flag);
    final startIcon = await MarkerIcons.pin(AppColors.route, Icons.trip_origin);
    for (final (p, icon) in [(s.origin, startIcon), (s.destination, endIcon)]) {
      if (p == null) continue;
      _pois[MapLayer.route]!.add(
        await map.labelLayer.addPoi(
          _ll(p.location),
          style: km.PoiStyle(
            icon: icon,
            textStyle: const [km.PoiTextStyle(size: 13, color: Colors.black87, stroke: 2, strokeColor: Colors.white)],
          ),
          text: p.name,
          visible: visible,
        ),
      );
    }

    // 경로 주변의 기회
    final filter = ref.read(routeFilterProvider);
    final interests = ref.read(interestsProvider);
    for (final o in s.opportunities) {
      final icon = await MarkerIcons.pin(AppColors.route, categoryIcon(o.event.category), selected: true);
      _routeOppByEventId[o.event.id] = o;
      final poi = await map.labelLayer.addPoi(
        _ll(o.event.location),
        id: 'route-${o.event.id}',
        style: km.PoiStyle(icon: icon),
        rank: 20,
        visible: visible && routeFilterMatches(filter, o.event, interests),
        onClick: () => _openOpportunity(_routeOppByEventId[o.event.id] ?? o),
      );
      _pois[MapLayer.route]!.add(poi);
      _routeOppPois[o.event.id] = poi;
    }

    if (fit) {
      final step = (pts.length / 40).ceil().clamp(1, pts.length);
      await _fit([for (var i = 0; i < pts.length; i += step) pts[i], pts.last]);
    }
  }

  /// 경로 필터가 바뀌면 경로 주변 행사 마커를 보이기/숨기기.
  Future<void> _applyRouteFilter() async {
    final filter = ref.read(routeFilterProvider);
    final interests = ref.read(interestsProvider);
    final visible = _layers.contains(MapLayer.route);
    for (final MapEntry(key: id, value: poi) in _routeOppPois.entries) {
      final o = _routeOppByEventId[id];
      final on = visible && o != null && routeFilterMatches(filter, o.event, interests);
      on ? await poi.show() : await poi.hide();
    }
  }

  void _openOpportunity(RouteOpportunity o) {
    if (!mounted) return;
    _map?.moveCamera(
      km.CameraUpdate.newCenterPosition(_ll(o.event.location), zoomLevel: 12),
      animation: const km.CameraAnimation(600),
    );
    showEventDetail(context, o.event, opportunity: o);
  }

  Future<void> _setMode(MapMode mode) async {
    setState(() => _mode = mode);
    switch (mode) {
      case MapMode.explore:
        await _setLayer(MapLayer.route, false);
        await _setLayer(MapLayer.plans, true);
        await _setLayer(MapLayer.recommended, true);
        await _fitAll();
      case MapMode.myMap:
        await _setLayer(MapLayer.route, false);
        await _setLayer(MapLayer.plans, true);
        await _setLayer(MapLayer.recommended, false);
        final pts = ref.read(plansProvider).where((p) => p.location != null).map((p) => _ll(p.location!)).toList();
        await _fit(pts);
      case MapMode.route:
        // 복잡하지 않도록 경로와 그 주변 행사만.
        await _setLayer(MapLayer.plans, false);
        await _setLayer(MapLayer.recommended, false);
        await _setLayer(MapLayer.route, true);
    }
  }

  Future<void> _fitAll() async {
    final pts = [
      ...ref.read(plansProvider).where((p) => p.location != null).map((p) => _ll(p.location!)),
      ...ref.read(mapEventsProvider).map((e) => _ll(e.location)),
    ];
    await _fit(pts);
  }

  Future<void> _fit(List<km.LatLng> pts) async {
    if (_map == null || pts.isEmpty) return;
    await _map!.moveCamera(
      pts.length == 1
          ? km.CameraUpdate.newCenterPosition(pts.first, zoomLevel: 14)
          : km.CameraUpdate.fitMapPoints(pts, padding: 120),
      animation: const km.CameraAnimation(600),
    );
  }

  Future<void> _focusEvent(String id) async {
    // 일정 장소: "plan:<id>" — 카메라를 그 장소로, "My Plans" 레이어를 켠다.
    if (id.startsWith('plan:')) {
      final plan = ref.read(plansProvider).where((x) => x.id == id.substring(5)).firstOrNull;
      ref.read(mapFocusProvider.notifier).focus(null);
      if (plan?.location == null || _map == null) return;
      if (!_layers.contains(MapLayer.plans)) await _setLayer(MapLayer.plans, true);
      await _map!.moveCamera(
        km.CameraUpdate.newCenterPosition(_ll(plan!.location!), zoomLevel: 15),
        animation: const km.CameraAnimation(800),
      );
      return;
    }
    final event = ref.read(eventByIdProvider(id));
    if (event == null || _map == null) return;
    ref.read(mapFocusProvider.notifier).focus(null);
    if (!_layers.contains(MapLayer.recommended)) await _setLayer(MapLayer.recommended, true);
    await _map!.moveCamera(
      km.CameraUpdate.newCenterPosition(_ll(event.location), zoomLevel: 14),
      animation: const km.CameraAnimation(800),
    );
    if (mounted) _openEvent(event);
  }

  void _openEvent(RadarEvent e) {
    if (!mounted) return;
    showEventDetail(context, e);
  }

  km.LatLng _ll(GeoPoint p) => km.LatLng(p.lat, p.lng);
}

class _MapMessage extends StatelessWidget {
  const _MapMessage(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.surfaceAlt,
    child: Center(
      child: SingleChildScrollView(
        child: EmptyState(
          icon: Icons.map_outlined,
          title: message,
          actions: [
            if (onRetry != null)
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.l10n.retry)),
          ],
        ),
      ),
    ),
  );
}

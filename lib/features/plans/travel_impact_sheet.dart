import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../data/travel_impact.dart';
import '../../data/plan_routes.dart';
import '../../data/location.dart';
import '../route/route_panel.dart' show PlaceSearchSheet;

Future<void> showTravelImpact(BuildContext context, Plan plan, {TripContext? trip}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => TravelImpactSheet(plan: plan, trip: trip),
);

class TravelImpactSheet extends ConsumerStatefulWidget {
  const TravelImpactSheet({super.key, required this.plan, this.trip});
  final Plan plan;
  final TripContext? trip;
  @override
  ConsumerState<TravelImpactSheet> createState() => _TravelImpactSheetState();
}

class _TravelImpactSheetState extends ConsumerState<TravelImpactSheet> {
  GeoPoint? _origin;
  String? _originName;
  TravelMode _mode = TravelMode.car;
  TravelImpactReport? _report;
  bool _busy = false;
  String? _error;
  String tr(String ko, String en) => context.lang == 'ko' ? ko : en;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(travelImpactProvider.notifier);
    _origin = controller.originFor(widget.plan.id);
    _mode = controller.modeFor(widget.plan.id) ?? TravelMode.car;
    if (_origin != null) _originName = '저장한 출발지';
    final trip = widget.trip ?? ref.read(tripsByPlanIdProvider)[widget.plan.id];
    if (trip != null) {
      if (trip.points.isNotEmpty) _origin = trip.points.first;
      _originName = '저장한 이동의 출발지';
      if (controller.modeFor(widget.plan.id) == null && !trip.modes.contains('car')) _mode = TravelMode.transit;
    }
    _report = ref.read(travelImpactProvider)[widget.plan.id];
    Future.microtask(_check);
  }

  Future<void> _check() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await ref
          .read(travelImpactProvider.notifier)
          .check(widget.plan, origin: _origin, mode: _mode, trip: widget.trip);
      if (mounted) setState(() => _report = report);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            '조회하지 못했습니다. 연결 상태와 일정 장소를 확인해 주세요.',
            'Could not check. Verify your connection and plan location.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOrigin() async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlaceSearchSheet(),
    );
    if (place != null && mounted) {
      setState(() {
        _origin = place.location;
        _originName = place.name;
        _report = null;
      });
    }
  }

  Future<void> _myLocation() async {
    setState(() => _busy = true);
    final ok = await ref.read(myLocationProvider.notifier).start();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _origin = ref.read(myLocationProvider).position;
        _originName = tr('현재 위치', 'Current location');
        _report = null;
      } else {
        _error = tr('현재 위치를 확인하지 못했습니다. 출발지를 검색해 주세요.', 'Location unavailable. Search for an origin.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final report = _report;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            Row(
              children: [
                Expanded(child: Text(tr('교통 영향 확인', 'Check travel impact'), style: context.textStyles.titleLarge)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Text(widget.plan.title, style: context.textStyles.titleSmall),
            const SizedBox(height: Space.sm),
            Text(
              tr(
                '현재 정체, 공식 도로 통제, 파업·운행 제한 보도와 실제 행사 일정을 비교합니다.',
                'Check current congestion, road controls, strike reports and real event schedules.',
              ),
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickOrigin,
              icon: const Icon(Icons.trip_origin),
              label: Text(_originName ?? tr('출발지 선택 · 경로 정체 확인에 필요', 'Choose an origin to check route traffic')),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _myLocation,
              icon: const Icon(Icons.my_location),
              label: Text(tr('현재 위치를 출발지로', 'Use current location')),
            ),
            SegmentedButton<TravelMode>(
              segments: [
                ButtonSegment(
                  value: TravelMode.car,
                  label: Text(tr('자동차', 'Driving')),
                  icon: const Icon(Icons.directions_car),
                ),
                ButtonSegment(
                  value: TravelMode.transit,
                  label: Text(tr('대중교통', 'Transit')),
                  icon: const Icon(Icons.train),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _mode = v.first;
                      _report = null;
                    }),
            ),
            const SizedBox(height: Space.md),
            FilledButton.icon(
              onPressed: _busy ? null : _check,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(
                _busy ? tr('실제 정보 조회 중…', 'Checking live sources…') : tr('최신 정보로 확인', 'Check latest information'),
              ),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: p.danger)),
            if (report != null) ...[
              const SizedBox(height: Space.lg),
              Text(
                '${tr('조회 시각', 'Checked')}: ${context.formatDateTime(report.checkedAt)}',
                style: context.textStyles.labelLarge,
              ),
              if (report.incomplete)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Text(
                    tr(
                      '일부 정보는 확인하지 못했습니다. 결과가 없더라도 정상 운행이나 영향 없음을 보장하지 않습니다.',
                      'Some sources could not be checked. An empty result does not guarantee normal service.',
                    ),
                    style: TextStyle(color: p.danger),
                  ),
                ),
              for (final source in report.sources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    source.ok ? Icons.check_circle_outline : Icons.info_outline,
                    color: source.ok ? p.primary : p.danger,
                  ),
                  title: Text(source.name),
                  subtitle: Text(
                    '${source.detail}${source.updatedAt == null ? '' : '\n${tr('자료 갱신', 'Updated')}: ${context.formatDateTime(source.updatedAt!.toLocal())}'}',
                  ),
                ),
              if (report.route != null)
                Text(
                  tr(
                    '조회 경로: ${(report.route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${(report.route!.durationSeconds / 60).ceil()}분',
                    'Route: ${(report.route!.distanceMeters / 1000).toStringAsFixed(1)} km · ${(report.route!.durationSeconds / 60).ceil()} min',
                  ),
                ),
              const Divider(),
              if (report.insights.isEmpty)
                Text(
                  tr(
                    '조회된 자료에서 일정과 겹치는 영향을 찾지 못했습니다. 출발 전 운행 공지를 다시 확인해 주세요.',
                    'No overlapping impact was found in the checked sources. Recheck operator notices before departure.',
                  ),
                ),
              for (final insight in report.insights)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr(insight.title), style: context.textStyles.titleSmall),
                        const SizedBox(height: Space.sm),
                        Text(context.tr(insight.body)),
                        const SizedBox(height: Space.xs),
                        Text(context.tr(insight.why), style: context.textStyles.bodySmall),
                        if (insight.trafficContext != null) ...[
                          const SizedBox(height: Space.xs),
                          Text(insight.trafficContext!.detail, style: context.textStyles.bodySmall),
                        ],
                        for (final source in insight.sources.where((s) => s.url != null))
                          TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(source.url!), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(source.title),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: Space.md),
            Text(
              tr(
                '알림을 켜면 3일 이내의 저장 일정에 대한 영향 가능성도 알립니다. 현재 도로 정체 알림은 2시간 이내 일정만 대상입니다. 앱 실행·복귀 및 실행 중 5분마다 갱신합니다.',
                'With notifications enabled, saved plans within 3 days receive relevant impact alerts. Current congestion alerts apply within 2 hours. Checks run while the app is open and on return.',
              ),
              style: context.textStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

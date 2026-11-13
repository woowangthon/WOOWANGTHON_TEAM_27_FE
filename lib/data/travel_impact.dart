import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../core/env.dart';
import 'providers.dart';
import 'plan_routes.dart';
import 'session.dart';

final travelImpactServiceProvider = Provider<TravelImpactService>((ref) {
  final service = TravelImpactService(
    kakaoKey: Env.kakaoRestApiKey,
    googleKey: Env.googleApiKey,
    itsKey: Env.itsApiKey,
  );
  ref.onDispose(service.close);
  return service;
});

final travelImpactProvider = NotifierProvider<TravelImpactController, Map<String, TravelImpactReport>>(
  TravelImpactController.new,
);

class TravelImpactController extends Notifier<Map<String, TravelImpactReport>> {
  final _running = <String, Future<TravelImpactReport>>{};
  final _signatures = <String, String>{};
  final _origins = <String, GeoPoint>{};
  final _modes = <String, TravelMode>{};
  int _generation = 0;
  GeoPoint? originFor(String planId) => _origins[planId];
  TravelMode? modeFor(String planId) => _modes[planId];
  late String _configKey;
  @override
  Map<String, TravelImpactReport> build() {
    final session = ref.watch(sessionProvider);
    _configKey = 'travel_check_inputs:${accountScope(session)}';
    _generation++;
    _running.clear();
    _signatures.clear();
    _origins.clear();
    _modes.clear();
    try {
      final saved = jsonDecode(ref.read(sharedPrefsProvider).getString(_configKey) ?? '{}') as Map;
      for (final entry in saved.entries) {
        final row = entry.value as Map;
        final mode = TravelMode.values.asNameMap()[row['mode']];
        if (mode != null) _modes[entry.key as String] = mode;
        if (row['lat'] is num && row['lng'] is num) {
          final lat = (row['lat'] as num).toDouble(), lng = (row['lng'] as num).toDouble();
          if (lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132) _origins[entry.key as String] = GeoPoint(lat, lng);
        }
      }
    } catch (_) {
      /* Invalid local settings never become invented route facts. */
    }
    return {};
  }

  String _signature(Plan p) => '${TravelImpactReport.versionOf(p)}:${ref.read(tripsByPlanIdProvider)[p.id]?.version}';

  Future<TravelImpactReport> check(
    Plan plan, {
    GeoPoint? origin,
    TravelMode? mode,
    bool force = true,
    TripContext? trip,
  }) {
    // A manual edit during an outstanding check cannot write a stale report.
    final key = '${plan.id}:${_signature(plan)}:${origin?.lat}:${origin?.lng}:$mode';
    return _running.putIfAbsent(key, () async {
      final generation = _generation;
      try {
        final savedTrip = trip ?? ref.read(tripsByPlanIdProvider)[plan.id];
        final useMode =
            mode ??
            _modes[plan.id] ??
            (savedTrip != null && !savedTrip.modes.contains('car') ? TravelMode.transit : TravelMode.car);
        final useOrigin = origin ?? _origins[plan.id];
        final signature = _signature(plan);
        final result = await ref
            .read(travelImpactServiceProvider)
            .check(plan, now: ref.read(nowProvider), origin: useOrigin, mode: useMode, trip: savedTrip, force: force);
        if (ref.mounted && generation == _generation) {
          final current = ref.read(plansProvider).where((p) => p.id == plan.id).firstOrNull;
          if (current != null && signature == _signature(current)) {
            _signatures[plan.id] = signature;
            if (useOrigin != null) _origins[plan.id] = useOrigin;
            _modes[plan.id] = useMode;
            state = {...state, plan.id: result};
            await ref
                .read(sharedPrefsProvider)
                .setString(
                  _configKey,
                  jsonEncode({
                    for (final id in _modes.keys)
                      id: {
                        'mode': _modes[id]!.name,
                        if (_origins[id] != null) 'lat': _origins[id]!.lat,
                        if (_origins[id] != null) 'lng': _origins[id]!.lng,
                      },
                  }),
                );
          }
        }
        return result;
      } finally {
        _running.remove(key);
      }
    });
  }

  Future<void> refreshUpcoming() async {
    final now = ref.read(nowProvider);
    final plans = ref
        .read(plansProvider)
        .where(
          (p) =>
              p.source != 'sample' &&
              p.attendance != 'online' &&
              p.location != null &&
              p.start.isAfter(now) &&
              p.start.difference(now) <= const Duration(days: 3),
        )
        .toList();
    final ids = plans.map((p) => p.id).toSet();
    state = {
      for (final e in state.entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
    for (final plan in plans) {
      if (!ref.mounted) return;
      final report = state[plan.id];
      if (report != null &&
          report.matches(plan, ref.read(tripsByPlanIdProvider)[plan.id]) &&
          _signatures[plan.id] == _signature(plan) &&
          now.difference(report.checkedAt) < const Duration(minutes: 5)) {
        continue;
      }
      await check(plan, force: false);
    }
  }
}

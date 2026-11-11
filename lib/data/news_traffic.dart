import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'providers.dart';
import 'plan_routes.dart';
import 'session.dart';

final newsTrafficDecisionsProvider =
    NotifierProvider<NewsTrafficDecisions, List<NewsTrafficEvaluation>>(
      NewsTrafficDecisions.new,
    );

/// Previous decisions are account-scoped and persisted so a later withdrawal or
/// a saved route edit can resolve precisely that schedule/impact pair.
class NewsTrafficDecisions extends Notifier<List<NewsTrafficEvaluation>> {
  String? _scope;
  Map<String, dynamic> _history = {};
  int _generation = 0;
  @override
  List<NewsTrafficEvaluation> build() {
    final scope = accountScope(ref.watch(sessionProvider));
    final prefs = ref.read(sharedPrefsProvider);
    final key = 'news_traffic_decisions:$scope';
    if (_scope != scope) {
      _scope = scope;
      try {
        _history = (jsonDecode(prefs.getString(key) ?? '{}') as Map)
            .cast<String, dynamic>();
      } catch (_) {
        _history = {};
      }
    }
    final prior = _history;
    final impacts = ref.watch(newsFeedProvider).trafficImpacts;
    final trips = ref.watch(tripsByPlanIdProvider);
    final plans = ref.watch(plansProvider);
    final now = ref.watch(nowProvider);
    final next = <NewsTrafficEvaluation>[];
    final history = <String, String>{};
    for (final p in plans) {
      for (final impact in impacts) {
        final pair = jsonEncode([p.id, impact.id]);
        final result = const NewsTrafficMatcher().evaluate(
          p,
          trips[p.id],
          impact,
          now,
          previousDecision: prior[pair] as String?,
        );
        history[pair] = result.decision.name;
        next.add(result);
      }
    }
    // No published verified state yet is not a cancellation of previous alerts.
    if (impacts.isNotEmpty) {
      _history = history;
      final generation = ++_generation;
      final value = jsonEncode(history);
      if (prefs.getString(key) != value) {
        Future.microtask(() async {
          if (ref.mounted &&
              _generation == generation &&
              accountScope(ref.read(sessionProvider)) == scope) {
            await prefs.setString(key, value);
          }
        });
      }
    }
    return next;
  }
}

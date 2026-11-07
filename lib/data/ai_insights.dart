import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:liferadar_core/liferadar_core.dart';

import '../core/env.dart';
import 'providers.dart';

final geminiApiProvider = Provider<GeminiClient>((ref) => GeminiClient(apiKey: Env.geminiApiKey));

/// 상위 몇 개의 카드만 AI로 작성한다 (속도와 무료 할당량 때문).
const aiInsightLimit = 6;

/// 인사이트 id → Gemini가 쓴 문장. 키가 없거나, 오류이거나, 검증을 통과하지 못하면 비어 있고
/// 카드는 규칙 문장으로 남는다. 결과는 기기에 캐시된다: 사실이 바뀌지 않으면 요청하지 않는다.
final aiInsightTextProvider =
    NotifierProvider<AiInsightTextController, Map<String, InsightWriting>>(AiInsightTextController.new);

class AiInsightTextController extends Notifier<Map<String, InsightWriting>> {
  static const _prefsKey = 'ai_insight_cache';
  static const _maxCached = 120;

  final _inflight = <String>{};
  final _rejected = <String>{}; // 검증 실패 — 이번 세션에서는 다시 요청하지 않는다
  DateTime? _cooldownUntil;
  Map<String, String> _keyById = const {};

  @override
  Map<String, InsightWriting> build() {
    final api = ref.watch(geminiApiProvider);
    if (!api.isConfigured) return const {};
    final base = ref.watch(baseInsightsProvider);
    if (base.isEmpty) return const {};

    final plans = {for (final p in ref.watch(plansProvider)) p.id: p};
    final events = {for (final e in ref.watch(eventsProvider)) e.id: e};
    final interests = ref.watch(interestsProvider);
    final hidden = ref.watch(insightFeedbackProvider);
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);

    final cache = _readCache();
    final keyById = <String, String>{};
    final todo = <String, Map<String, dynamic>>{};
    final out = <String, InsightWriting>{};
    // 교통 통제·혼잡 참고 카드는 템플릿 문장을 유지한다 (InsightWriter.isEligible).
    final candidates = base.where((i) => hidden[i.id] != InsightFeedback.hidden && InsightWriter.isEligible(i));
    for (final i in candidates.take(aiInsightLimit)) {
      final facts = InsightWriter.facts(
        i,
        plan: plans[i.planId],
        event: i.eventIds.isEmpty ? null : events[i.eventIds.first],
        interests: interests,
        today: today,
      );
      final key = InsightWriter.cacheKey(facts);
      keyById[i.id] = key;
      final hit = cache[key];
      if (hit != null) {
        out[i.id] = hit;
      } else if (!_inflight.contains(key) && !_rejected.contains(key)) {
        todo[i.id] = facts;
      }
    }
    _keyById = keyById;

    final cooling = _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
    if (todo.isNotEmpty && !cooling) Future.microtask(() => _fetch(todo, Map.of(keyById)));
    return out;
  }

  Future<void> _fetch(Map<String, Map<String, dynamic>> todo, Map<String, String> keys) async {
    final requested = [for (final id in todo.keys) keys[id]!];
    _inflight.addAll(requested);
    try {
      final (json, model) = await ref.read(geminiApiProvider).generate(InsightWriter.requestBody([...todo.values]));
      final written = InsightWriter.parseResponse(json, factsById: todo, model: model);
      _rejected.addAll([for (final id in todo.keys) if (!written.containsKey(id)) keys[id]!]);
      if (written.isEmpty) return;

      final cache = _readCache();
      for (final e in written.entries) {
        cache[keys[e.key]!] = e.value;
      }
      await _writeCache(cache);

      if (!ref.mounted) return;
      final next = {...state};
      for (final e in written.entries) {
        if (_keyById[e.key] == keys[e.key]) next[e.key] = e.value; // 그 사이 사실이 바뀌지 않았다면
      }
      state = next;
    } catch (e) {
      _cooldownUntil = DateTime.now().add(const Duration(minutes: 2)); // 네트워크/할당량 — 잠시 기다린다
      debugPrint('Gemini insight: $e');
    } finally {
      _inflight.removeAll(requested);
    }
  }

  Map<String, InsightWriting> _readCache() {
    final raw = ref.read(sharedPrefsProvider).getString(_prefsKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: InsightWriting.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeCache(Map<String, InsightWriting> cache) {
    final entries = cache.entries.toList();
    final kept = entries.length > _maxCached ? entries.sublist(entries.length - _maxCached) : entries;
    return ref
        .read(sharedPrefsProvider)
        .setString(_prefsKey, jsonEncode({for (final e in kept) e.key: e.value.toJson()}));
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import 'ai_insights.dart';
import 'providers.dart';

/// 제안 행동의 상태 — 사용자가 [추가] / [취소]를 누르기 전에는 아무것도 바뀌지 않는다.
enum ActionStatus { pending, running, done, cancelled, failed }

class AssistantMessage {
  const AssistantMessage({
    required this.fromUser,
    this.text = '',
    this.eventIds = const [],
    this.actions = const [],
    this.actionStatus = const [],
    this.fromAi = false,
    this.loading = false,
    this.understood = '',
  });

  final bool fromUser;
  final String text;
  final List<String> eventIds;
  final List<AssistantAction> actions;
  final List<ActionStatus> actionStatus;

  /// Gemini 답이 검증을 통과했는지 (false = 조건 검색 규칙 문장).
  final bool fromAi;
  final bool loading;

  /// 코드가 질문에서 읽은 조건 ("11/20 · 부산").
  final String understood;

  AssistantMessage withStatus(int i, ActionStatus s) => AssistantMessage(
    fromUser: fromUser,
    text: text,
    eventIds: eventIds,
    actions: actions,
    actionStatus: [...actionStatus]..[i] = s,
    fromAi: fromAi,
    understood: understood,
  );
}

/// 앱 안의 AI 비서 대화 (이 세션 동안만, 기기에 저장하지 않음).
final assistantProvider = NotifierProvider<AssistantController, List<AssistantMessage>>(AssistantController.new);

class AssistantController extends Notifier<List<AssistantMessage>> {
  @override
  List<AssistantMessage> build() => const [];

  bool get busy => state.any((m) => m.loading);

  void clear() => state = const [];

  void setActionStatus(int message, int action, ActionStatus s) {
    if (message >= state.length) return;
    state = [...state]..[message] = state[message].withStatus(action, s);
  }

  /// 질문 → (코드) 조건·후보 → (Gemini) 답 → (코드) 검증. AI가 안 되면 같은 후보로 규칙 문장.
  Future<void> ask(String question, {required String lang}) async {
    final text = question.trim();
    if (text.isEmpty || busy) return;
    final history = [
      for (final m in state)
        if (!m.loading && m.text.isNotEmpty) ChatTurn(fromUser: m.fromUser, text: m.text),
    ];
    state = [
      ...state,
      AssistantMessage(fromUser: true, text: text),
      const AssistantMessage(fromUser: false, loading: true),
    ];

    final now = ref.read(nowProvider);
    final plans = ref.read(plansProvider);
    final interests = ref.read(interestsProvider);
    final query = AssistantQuery.parse(text, now: now, plans: plans);
    final candidates = Assistant.retrieve(
      query,
      events: ref.read(eventsProvider),
      interests: interests,
      taste: ref.read(tasteProvider),
      now: now,
    );
    final ctx = Assistant.context(
      query: query,
      candidates: candidates,
      plans: plans,
      now: now,
      interests: interests,
      stage: ref.read(lifeStageProvider),
      signals: ref.read(insightsProvider),
    );

    AssistantReply reply;
    final api = ref.read(geminiApiProvider);
    try {
      if (!api.isConfigured) throw const GeminiException('no key');
      reply = await Assistant.ask(
        api,
        question: text,
        query: query,
        candidates: candidates,
        context: ctx,
        history: history,
        lang: lang,
      );
    } catch (_) {
      reply = Assistant.fallback(query, candidates, lang: lang);
    }
    if (!ref.mounted) return;
    state = [
      for (final m in state)
        if (!m.loading) m,
      AssistantMessage(
        fromUser: false,
        text: reply.text,
        eventIds: reply.eventIds,
        actions: reply.actions,
        actionStatus: [for (final _ in reply.actions) ActionStatus.pending],
        fromAi: reply.fromAi,
        understood: query.describe(lang: lang),
      ),
    ];
  }
}

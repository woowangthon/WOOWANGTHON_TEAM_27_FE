import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:liferadar/data/ai_insights.dart';
import 'package:liferadar/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _insight = Insight(
  id: 'nearby:p1:e1',
  kind: InsightKind.opportunity,
  planId: 'p1',
  eventIds: ['e1'],
  title: LocalizedText(ko: '부산에 있는 동안: 재즈 페스티벌', en: 'While you are at Busan: Jazz Festival'),
  body: LocalizedText(ko: '11월 8일 해운대에서 열립니다. 일정 장소에서 약 2.4 km.', en: 'On Nov 8 at Haeundae, about 2.4 km from your plan.'),
  why: LocalizedText(ko: '관심사(#music)와 맞습니다.', en: 'It matches your interests (#music).'),
  confidence: 0.8,
);

Map<String, dynamic> _response(Object items) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(items)},
            ],
          },
        },
      ],
    };

Map<String, String> _item({String bodyKo = '11월 8일 해운대에서 재즈 공연이 있어요. 부산 일정 중에 들러 보세요.', String bodyEn = 'Jazz at Haeundae on Nov 8, 2.4 km from your plan.'}) => {
      'id': _insight.id,
      'body_ko': bodyKo,
      'body_en': bodyEn,
      'why_ko': '음악을 좋아하시고 그날 부산에 계세요.',
      'why_en': 'You love music and will already be in Busan.',
    };

void main() {
  group('aiInsightTextProvider', () {
    Future<(ProviderContainer, List<http.Request>)> setup(http.Response Function(http.Request) handler) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final calls = <http.Request>[];
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          nowProvider.overrideWithValue(DateTime(2026, 11, 6, 10)),
          baseInsightsProvider.overrideWithValue([_insight]),
          geminiApiProvider.overrideWithValue(
            GeminiClient(
              apiKey: 'test',
              client: MockClient((r) async {
                calls.add(r);
                return handler(r);
              }),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return (c, calls);
    }

    test('Gemini 문장을 카드에 넣고 캐시에서 재사용한다', () async {
      final (c, calls) = await setup((_) => http.Response.bytes(utf8.encode(jsonEncode(_response([_item()]))), 200));
      c.listen(insightsProvider, (_, _) {});
      expect(c.read(insightsProvider).single.aiModel, isNull); // 처음에는 규칙 문장
      await pumpEventQueue();
      final i = c.read(insightsProvider).single;
      expect(i.aiModel, GeminiClient.defaultModels.first);
      expect(i.why.en, 'You love music and will already be in Busan.');
      expect(calls, hasLength(1));

      c.invalidate(aiInsightTextProvider);
      expect(c.read(insightsProvider).single.aiModel, isNotNull); // 즉시 캐시에서
      await pumpEventQueue();
      expect(calls, hasLength(1)); // 새 요청 없음
    });

    test('오류가 나면 규칙 문장이 유지된다', () async {
      final (c, calls) = await setup((_) => http.Response('quota', 429));
      c.listen(insightsProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(insightsProvider).single.body.en, _insight.body.en);
      expect(calls, hasLength(GeminiClient.defaultModels.length)); // 예비 모델도 시도했다
    });
  });
}

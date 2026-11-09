import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferadar_core/liferadar_core.dart';

import 'interests.dart';
import 'session.dart';

/// 사용자의 지금 상황 (학생·구직·직장인…). 선택 사항 — null이면 순위에 반영하지 않는다.
/// 관심사처럼 계정별로 기기에만 저장한다.
final lifeStageProvider = NotifierProvider<LifeStageController, LifeStage?>(LifeStageController.new);

class LifeStageController extends Notifier<LifeStage?> {
  late String _key;

  @override
  LifeStage? build() {
    _key = 'stage:${accountScope(ref.watch(sessionProvider))}';
    return LifeStage.byName(ref.read(sharedPrefsProvider).getString(_key));
  }

  Future<void> save(LifeStage? s) async {
    state = s;
    final prefs = ref.read(sharedPrefsProvider);
    s == null ? await prefs.remove(_key) : await prefs.setString(_key, s.name);
  }
}

/// "나를 소개하기"에 마지막으로 쓴 글 — 다음에 열면 이어서 고칠 수 있게. 기기에만 저장.
final aboutMeProvider = NotifierProvider<AboutMeController, String>(AboutMeController.new);

class AboutMeController extends Notifier<String> {
  late String _key;

  @override
  String build() {
    _key = 'about:${accountScope(ref.watch(sessionProvider))}';
    return ref.read(sharedPrefsProvider).getString(_key) ?? '';
  }

  Future<void> save(String text) async {
    state = text;
    await ref.read(sharedPrefsProvider).setString(_key, text);
  }
}

/// AI가 고를 수 있는 관심사 태그 (태그 → 영어 설명). 앱의 관심사 목록과 같다.
Map<String, String> get allowedInterestTags => {for (final o in interestOptions) o.tag: o.label.en};

/// AI 없이 쓸 키워드: 관심사 이름(한국어·영어)을 낱말로 나눈 것 + 자주 쓰는 표현.
Map<String, List<String>> get interestKeywords {
  const extra = <String, List<String>>{
    'ai': ['인공지능', '머신러닝', '딥러닝', 'LLM', 'machine learning'],
    'developer': ['개발자', '프로그래밍', '코딩', '프론트엔드', '백엔드', 'coding', 'programming', 'developer'],
    'startup': ['창업'],
    'career': ['취업', '채용', '이직', 'job'],
    'student': ['대학생', '학생'],
    'music': ['콘서트', '재즈', '밴드', 'concert'],
    'art': ['전시회', '미술관', 'museum'],
    'fitness': ['러닝', '헬스', '요가', 'running', 'gym'],
    'outdoor': ['등산', '캠핑', 'hiking'],
    'food': ['맛집', '카페', '요리'],
    'pets': ['강아지', '고양이', '반려견', '반려묘', 'dog', 'cat'],
    'language': ['영어', '일본어', '중국어', '한국어 공부'],
    'finance': ['투자', '주식', '재테크'],
    'gaming': ['게임', 'game'],
    'travel': ['여행'],
    'movie': ['영화'],
    'books': ['독서', '책'],
  };
  return {
    for (final o in interestOptions)
      o.tag: {
        ...[
          o.label.ko,
          o.label.en,
        ].expand((s) => s.split(RegExp(r'[·&]'))).map((s) => s.trim()).where((s) => s.length >= 2),
        ...?extra[o.tag],
      }.toList(),
  };
}

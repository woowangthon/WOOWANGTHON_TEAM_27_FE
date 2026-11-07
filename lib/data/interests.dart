import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'session.dart';

/// 관심사 그룹 (온보딩의 소제목).
enum InterestGroup {
  tech(LocalizedText(ko: '기술·창업', en: 'Tech & startups')),
  growth(LocalizedText(ko: '커리어·배움', en: 'Career & learning')),
  culture(LocalizedText(ko: '문화·예술', en: 'Culture & arts')),
  active(LocalizedText(ko: '운동·야외', en: 'Active & outdoors')),
  life(LocalizedText(ko: '일상·라이프', en: 'Everyday life'));

  const InterestGroup(this.label);
  final LocalizedText label;
}

/// 선택 가능한 관심사. [tag] — 행사의 `tags`와 같은 키.
class InterestOption {
  const InterestOption(this.tag, this.label, this.icon, this.hue, this.group);
  final String tag;
  final LocalizedText label;
  final IconData icon;
  final Hue hue;
  final InterestGroup group;
}

const interestOptions = <InterestOption>[
  // 기술
  InterestOption('ai', LocalizedText(ko: 'AI', en: 'AI'), Icons.auto_awesome, Hue.violet, InterestGroup.tech),
  InterestOption('developer', LocalizedText(ko: '개발', en: 'Development'), Icons.code, Hue.indigo, InterestGroup.tech),
  InterestOption('data', LocalizedText(ko: '데이터', en: 'Data'), Icons.insights, Hue.blue, InterestGroup.tech),
  InterestOption('startup', LocalizedText(ko: '스타트업', en: 'Startups'), Icons.rocket_launch_outlined, Hue.orange, InterestGroup.tech),
  InterestOption('design', LocalizedText(ko: '디자인', en: 'Design'), Icons.palette_outlined, Hue.pink, InterestGroup.tech),
  // 커리어와 학습
  InterestOption('career', LocalizedText(ko: '채용·커리어', en: 'Careers & jobs'), Icons.work_outline, Hue.sky, InterestGroup.growth),
  InterestOption('student', LocalizedText(ko: '학생 프로그램', en: 'Student programs'), Icons.school_outlined, Hue.teal, InterestGroup.growth),
  InterestOption('networking', LocalizedText(ko: '네트워킹', en: 'Networking'), Icons.groups_outlined, Hue.cyan, InterestGroup.growth),
  InterestOption('finance', LocalizedText(ko: '재테크·투자', en: 'Money & investing'), Icons.savings_outlined, Hue.green, InterestGroup.growth),
  InterestOption('language', LocalizedText(ko: '외국어', en: 'Languages'), Icons.translate, Hue.indigo, InterestGroup.growth),
  InterestOption('books', LocalizedText(ko: '책·강연', en: 'Books & talks'), Icons.menu_book_outlined, Hue.amber, InterestGroup.growth),
  // 문화
  InterestOption('music', LocalizedText(ko: '음악·공연', en: 'Music & shows'), Icons.music_note, Hue.rose, InterestGroup.culture),
  InterestOption('culture', LocalizedText(ko: '문화·축제', en: 'Culture & festivals'), Icons.celebration_outlined, Hue.orange, InterestGroup.culture),
  InterestOption('art', LocalizedText(ko: '전시·미술', en: 'Art & exhibitions'), Icons.brush_outlined, Hue.violet, InterestGroup.culture),
  InterestOption('movie', LocalizedText(ko: '영화', en: 'Movies'), Icons.movie_outlined, Hue.blue, InterestGroup.culture),
  InterestOption('photo', LocalizedText(ko: '사진', en: 'Photography'), Icons.photo_camera_outlined, Hue.sky, InterestGroup.culture),
  InterestOption('gaming', LocalizedText(ko: '게임·e스포츠', en: 'Gaming & esports'), Icons.sports_esports_outlined, Hue.pink, InterestGroup.culture),
  // 활동적인 생활
  InterestOption('sports', LocalizedText(ko: '스포츠 관람', en: 'Watching sports'), Icons.sports_soccer, Hue.green, InterestGroup.active),
  InterestOption('fitness', LocalizedText(ko: '운동·러닝', en: 'Fitness & running'), Icons.directions_run, Hue.lime, InterestGroup.active),
  InterestOption('outdoor', LocalizedText(ko: '등산·캠핑', en: 'Hiking & camping'), Icons.terrain_outlined, Hue.teal, InterestGroup.active),
  InterestOption('travel', LocalizedText(ko: '여행', en: 'Travel'), Icons.flight_takeoff, Hue.cyan, InterestGroup.active),
  // 일상
  InterestOption('food', LocalizedText(ko: '맛집·푸드', en: 'Food & drinks'), Icons.restaurant_outlined, Hue.amber, InterestGroup.life),
  InterestOption('family', LocalizedText(ko: '가족·아이', en: 'Family & kids'), Icons.family_restroom, Hue.rose, InterestGroup.life),
  InterestOption('pets', LocalizedText(ko: '반려동물', en: 'Pets'), Icons.pets, Hue.orange, InterestGroup.life),
  InterestOption('fashion', LocalizedText(ko: '패션·뷰티', en: 'Fashion & beauty'), Icons.checkroom_outlined, Hue.pink, InterestGroup.life),
  InterestOption('volunteer', LocalizedText(ko: '봉사·나눔', en: 'Volunteering'), Icons.volunteer_activism_outlined, Hue.green, InterestGroup.life),
];

InterestOption? interestByTag(String tag) {
  for (final o in interestOptions) {
    if (o.tag == tag) return o;
  }
  return null;
}

/// main()에서 로드해 override한다 (ProviderScope).
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden in main()'),
);

/// 계정별 데이터의 키: Google은 이메일 기준, 게스트는 'guest'.
/// 로그아웃 후 다시 로그인하거나 다른 계정으로 들어와도 데이터가 섞이지 않는다.
String accountScope(Session? s) =>
    s == null || s.isGuest || s.email == null ? 'guest' : 'g:${s.email!.toLowerCase()}';

final interestsProvider = NotifierProvider<InterestsController, Set<String>>(InterestsController.new);

/// 사용자 관심사 — 기기에 계정별로 저장 (웹: localStorage).
/// 빈 집합 = 아직 온보딩을 하지 않음.
class InterestsController extends Notifier<Set<String>> {
  static const _legacyKey = 'interests';
  late String _key;

  @override
  Set<String> build() {
    final prefs = ref.read(sharedPrefsProvider);
    _key = 'interests:${accountScope(ref.watch(sessionProvider))}';
    final saved = prefs.getStringList(_key);
    if (saved != null) return saved.toSet();

    // 이전 버전(계정 없는 키)에서 한 번 이전한다.
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy != null) {
      prefs.setStringList(_key, legacy);
      prefs.remove(_legacyKey);
      return legacy.toSet();
    }
    return const {};
  }

  bool get hasCompletedOnboarding => state.isNotEmpty;

  Future<void> save(Set<String> tags) async {
    state = {...tags};
    await ref.read(sharedPrefsProvider).setStringList(_key, tags.toList());
  }
}

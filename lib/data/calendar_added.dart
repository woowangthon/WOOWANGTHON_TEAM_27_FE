import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'session.dart';

/// 이 기기에서 캘린더에 넣은 행사 id (계정별). 버튼을 "추가됨"으로 보여주는 데만 쓴다 —
/// 실제 중복 판단은 추가 직전에 Google 캘린더에서 다시 확인한다 (다른 기기·삭제 반영).
final calendarAddedProvider = NotifierProvider<CalendarAddedController, Set<String>>(CalendarAddedController.new);

class CalendarAddedController extends Notifier<Set<String>> {
  late String _key;

  @override
  Set<String> build() {
    _key = 'calendar_added:${accountScope(ref.watch(sessionProvider))}';
    return (ref.read(sharedPrefsProvider).getStringList(_key) ?? const []).toSet();
  }

  Future<void> mark(String eventId) async {
    if (state.contains(eventId)) return;
    state = {...state, eventId};
    await ref.read(sharedPrefsProvider).setStringList(_key, state.toList());
  }
}

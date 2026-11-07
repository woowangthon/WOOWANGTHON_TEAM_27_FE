import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interests.dart';
import 'session.dart';

/// 사용자가 열어 본 신호/행사 (카드가 살짝 흐리게 보인다).
/// 키: `insight:<id>`, `event:<id>`. 기기에 계정별로, 최근 500개.
final seenProvider = NotifierProvider<SeenController, Set<String>>(SeenController.new);

class SeenController extends Notifier<Set<String>> {
  static const _limit = 500;
  late String _key;
  List<String> _order = const [];

  @override
  Set<String> build() {
    _key = 'seen:${accountScope(ref.watch(sessionProvider))}';
    _order = ref.read(sharedPrefsProvider).getStringList(_key) ?? const [];
    return _order.toSet();
  }

  bool isSeen(String id) => state.contains(id);

  Future<void> mark(Iterable<String> ids) async {
    final fresh = ids.where((id) => !state.contains(id)).toList();
    if (fresh.isEmpty) return;
    _order = [..._order, ...fresh];
    if (_order.length > _limit) _order = _order.sublist(_order.length - _limit);
    state = _order.toSet();
    await ref.read(sharedPrefsProvider).setStringList(_key, _order);
  }
}

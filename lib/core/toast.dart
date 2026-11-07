import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// 상태별 토스트 색상. 글자는 항상 흰색이며 배경은 흰 글자와 대비 ≥ 4.5:1
/// (그래서 "연한 초록" 대신 읽을 수 있는 가장 밝은 초록 green-700).
enum ToastType {
  success(Color(0xFF15803D)),
  error(Color(0xFFB91C1C)),
  warning(Color(0xFFB45309)),
  info(Color(0xFF1E293B));

  const ToastType(this.color);
  final Color color;
}

/// 앱 전체에서 하나뿐인 토스트: 위(상태 표시줄 아래)에서 부드럽게 내려오고,
/// 아이콘 없음, 누르거나 위로 밀면 닫힘. 새 토스트가 이전 토스트를 대체한다.
///
/// Navigator의 루트 overlay에 표시 — 바텀 시트가 닫힌 뒤에도 보인다.
class Toast {
  Toast._();

  /// `GoRouter(navigatorKey: …)` — 이 키로 overlay를 찾는다.
  static final navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _entry;
  static GlobalKey<_ToastViewState>? _viewKey;

  static void show(String message, {ToastType type = ToastType.success, Duration? duration}) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _dismissNow();
    final key = GlobalKey<_ToastViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: key,
        message: message,
        type: type,
        duration: duration ?? Duration(milliseconds: 1800 + message.length * 30).clampMax(5000),
        onDone: () {
          if (_entry == entry) {
            _entry = null;
            _viewKey = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    _viewKey = key;
    overlay.insert(entry);
  }

  static void _dismissNow() {
    final e = _entry;
    _entry = null;
    _viewKey = null;
    if (e != null && e.mounted) e.remove();
  }

  /// 테스트용: 현재 표시 중인 토스트 닫기.
  static void hide() => _viewKey?.currentState?._close();
}

extension on Duration {
  Duration clampMax(int ms) => inMilliseconds > ms ? Duration(milliseconds: ms) : this;
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.message, required this.type, required this.duration, required this.onDone});

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 240),
  );
  // 등장: 가벼운 "튀어나옴"(easeOutBack), 퇴장: 빠르고 부드럽게.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0;
    } else {
      await _c.reverse();
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 상태 표시줄과 제목보다 조금 아래 — 시선이 자연스럽게 가는 위치.
    final top = MediaQuery.paddingOf(context).top + 56;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned(
      top: top,
      left: Space.xl,
      right: Space.xl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              final v = _curve.value;
              return Opacity(
                opacity: _c.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -28),
                  child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                ),
              );
            },
            child: GestureDetector(
              onTap: _close,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) _close();
              },
              child: Semantics(
                liveRegion: true,
                container: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: widget.type.color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ColoredBox(
                      color: widget.type.color,
                      child: Stack(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.xl + 2, vertical: Space.md + 1),
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                          ),
                        ),
                        // 남은 시간 — 아래쪽 가는 막대.
                        if (!reduce)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1, end: 0),
                              duration: widget.duration,
                              builder: (_, f, _) => Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: f,
                                  child: Container(height: 2.5, color: Colors.white.withValues(alpha: 0.45)),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

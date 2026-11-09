import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/notifications.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 하단 내비게이션 셸 (탭 5개). 여기서 신호를 지켜보고, 중요한 신호를
/// 시스템 알림으로 보낸다 (켜져 있을 때).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell, required this.body});

  final StatefulNavigationShell shell;
  final Widget body;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<List<Insight>>(
      insightsProvider,
      (_, next) => ref.read(signalNotifierProvider).dispatch(next),
      fireImmediately: true,
    );
    // 켜는 즉시 — 현재의 중요 신호도 보낸다.
    ref.listenManual<bool>(notificationsEnabledProvider, (_, on) {
      if (on) ref.read(signalNotifierProvider).dispatch(ref.read(insightsProvider));
    });
  }

  StatefulNavigationShell get shell => widget.shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 홈의 빨간 배지 — 아직 열어 보지 않은 신호 수.
    final seen = ref.watch(seenProvider);
    final unseen = ref
        .watch(insightsProvider)
        .where((i) => i.feedback != InsightFeedback.hidden && !seen.contains('insight:${i.id}'))
        .where((i) => i.eventIds.isEmpty || !seen.contains('event:${i.eventIds.first}'))
        .length;

    return Scaffold(
      // 콘텐츠가 떠 있는 유리 내비게이션 아래로 지나간다 (유리 뒤로 흐리게 보인다).
      extendBody: true,
      body: widget.body,
      bottomNavigationBar: GlassTabBar(
        currentIndex: shell.currentIndex,
        onSelect: (i) {
          if (i != shell.currentIndex) HapticFeedback.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
        items: [
          GlassTab(Icons.radar_outlined, Icons.radar, l10n.tabHome, badge: unseen),
          GlassTab(Icons.map_outlined, Icons.map_rounded, l10n.tabMap),
          GlassTab(Icons.event_note_outlined, Icons.event_note_rounded, l10n.tabPlans),
          GlassTab(Icons.explore_outlined, Icons.explore_rounded, l10n.tabDiscover),
          GlassTab(Icons.person_outline_rounded, Icons.person_rounded, l10n.tabProfile),
        ],
      ),
    );
  }
}

class GlassTab {
  const GlassTab(this.icon, this.selectedIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// iOS "liquid glass" 스타일의 떠 있는 탭 바: 반투명 흐림 캡슐, 선택된 탭
/// 아래로 움직이는 안쪽 캡슐, 색 라벨과 빨간 개수 배지.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.currentIndex, required this.onSelect, required this.items});

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<GlassTab> items;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = Motion.of(context, const Duration(milliseconds: 380));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final n = items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm + bottomInset),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: height,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: (dark ? const Color(0xFF23272A) : Colors.white).withValues(alpha: dark ? 0.60 : 0.68),
                    borderRadius: BorderRadius.circular(999),
                    // 유리 가장자리 — 밝고 얇은 선.
                    border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.12 : 0.7)),
                  ),
                  child: Stack(
                    children: [
                      // 선택된 탭 아래의 안쪽 캡슐 — 살짝 "튀며" 이동한다.
                      AnimatedAlign(
                        duration: d,
                        curve: Curves.easeOutBack,
                        alignment: Alignment(n == 1 ? 0 : -1 + 2 * currentIndex / (n - 1), 0),
                        child: FractionallySizedBox(
                          widthFactor: 1 / n,
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: dark ? Colors.white.withValues(alpha: 0.13) : p.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: _TabItem(
                                item: items[i],
                                selected: i == currentIndex,
                                onTap: () => onSelect(i),
                                labelStyle: t.labelSmall!,
                              ),
                            ),
                        ],
                      ),
                    ],
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

class _TabItem extends StatelessWidget {
  const _TabItem({required this.item, required this.selected, required this.onTap, required this.labelStyle});
  final GlassTab item;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.primary : p.text;
    final d = Motion.of(context, const Duration(milliseconds: 320));
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0 ? '${item.label}, ${item.badge}' : item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  duration: d,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.12 : 1,
                  child: Icon(selected ? item.selectedIcon : item.icon, size: 23, color: color),
                ),
                if (item.badge > 0)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFED4245),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: p.surface, width: 1.5),
                      ),
                      child: Text(
                        item.badge > 9 ? '9+' : '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭 간 부드러운 페이드. 각 탭의 상태를 유지한다 (Offstage + TickerMode).
class FadeBranchContainer extends StatelessWidget {
  const FadeBranchContainer({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [for (var i = 0; i < children.length; i++) _Branch(active: i == currentIndex, child: children[i])],
  );
}

class _Branch extends StatefulWidget {
  const _Branch({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.normal,
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Branch old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _c.duration = Motion.of(context, Motion.normal);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !widget.active,
    child: TickerMode(
      enabled: widget.active,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _c, curve: Motion.curve),
        child: widget.child,
      ),
    ),
  );
}

/// 샘플 데이터임을 정직하게 알리는 작은 배지.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) => Pill(context.l10n.sampleData, tone: Tone.neutral, dense: true);
}

import '../event/traffic_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/confirm.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/alerts.dart';
import '../../data/calendar_controller.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../event/event_detail_sheet.dart';
import '../profile/user_avatar.dart';
import '../event/signal_why_block.dart';
import '../weather/weather_chip.dart';

/// 홈의 통계 3개 — 동시에 필터 역할도 한다.
enum HomeFilter { plans, all, deadlines }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final session = ref.watch(sessionProvider);
    final cal = ref.watch(calendarProvider);
    final now = ref.watch(nowProvider);
    // 일정 경고는 알림 탭에서만 — 홈은 새 소식·기회·마감.
    final all = ref.watch(insightsProvider).where((i) => !isAlert(i) && i.feedback != InsightFeedback.hidden).toList();
    final forPlans = all.where((i) => i.planId != null).toList();
    final deadlines = all.where((i) => i.kind == InsightKind.deadline).toList()
      ..sort((a, b) => _deadlineOf(ref, a).compareTo(_deadlineOf(ref, b)));
    final shown = _stable(switch (_filter) {
      HomeFilter.all => all,
      HomeFilter.plans => forPlans,
      HomeFilter.deadlines => deadlines,
    });
    // 사용자가 입력한 이름; 없으면 Google 이름의 첫 단어.
    final name =
        ref.watch(profileNameProvider) ?? (session == null || session.isGuest ? null : session.name?.split(' ').first);

    final counts = {
      HomeFilter.plans: forPlans.length,
      HomeFilter.all: all.length,
      HomeFilter.deadlines: deadlines.length,
    };

    // 카드 목록 (필터가 바뀌면 옆으로 밀리며 교체).
    final Widget cards;
    if (cal.isInitialLoading) {
      cards = const Shimmer(
        key: ValueKey('busy'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              SkeletonCard(lines: 2, leading: false),
              SizedBox(height: Space.md),
              SkeletonCard(lines: 2, leading: false),
            ],
          ),
        ),
      );
    } else if (all.isEmpty) {
      cards = EmptyState(
        key: const ValueKey('empty'),
        icon: Icons.radar,
        title: l10n.homeEmptyTitle,
        body: l10n.homeEmptyBody,
        actions: [
          FilledButton(onPressed: () => context.go('/plans'), child: Text(l10n.connectCalendar)),
          OutlinedButton(onPressed: () => context.push('/interests'), child: Text(l10n.interestsEdit)),
        ],
      );
    } else if (shown.isEmpty) {
      cards = EmptyState(
        key: ValueKey('none-${_filter.name}'),
        icon: Icons.inbox_outlined,
        title: l10n.homeFilterEmpty,
      );
    } else {
      cards = Column(
        key: ValueKey(_filter),
        children: [
          for (var i = 0; i < shown.length; i++)
            // 키는 목록의 직접 자식에 — 순서가 바뀌어도 카드가 다시 만들어지지(깜빡이지) 않는다.
            Padding(
              key: ValueKey('${_filter.name}-${shown[i].id}'),
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: FadeSlideIn(
                index: i,
                child: Pressable(child: InsightCard(insight: shown[i])),
              ),
            ),
        ],
      );
    }

    final d = Motion.of(context, Motion.normal);
    return Scaffold(
      body: Stack(
        children: [
          const AmbientGlow(),
          SafeArea(
        bottom: false,
        // 옆으로 밀기 — 필터 간 이동 (내 일정 ↔ 전체 ↔ 마감 임박).
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (e) {
            final v = e.primaryVelocity ?? 0;
            if (v.abs() < 250) return;
            final i = _filter.index + (v < 0 ? 1 : -1);
            if (i >= 0 && i < HomeFilter.values.length) _select(HomeFilter.values[i]);
          },
          child: RefreshIndicator(
            onRefresh: () async {
              _order.clear(); // 새로 고치면 취향이 반영된 새 순서
              if (cal.isConnected) await ref.read(calendarProvider.notifier).sync();
              ref.invalidate(forecastProvider);
              if (!context.mounted) return;
              final failed = ref.read(calendarProvider).status == CalendarStatus.error;
              Toast.show(
                failed ? l10n.calendarErrorToast : l10n.refreshedToast,
                type: failed ? ToastType.error : ToastType.info,
              );
            },
            child: CustomScrollView(
              slivers: [
                // ── 제목 ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat.MMMMEEEEd(context.lang).format(now), style: t.labelMedium),
                              const SizedBox(height: 2),
                              Text(name == null ? l10n.homeHello : l10n.homeHelloName(name), style: t.headlineSmall),
                            ],
                          ),
                        ),
                        const _AskAiButton(),
                        const SizedBox(width: Space.sm),
                        Semantics(
                          button: true,
                          label: l10n.tabProfile,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.push('/profile'),
                            child: const UserAvatar(size: 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 필터: 위에 고정되고, 스크롤하면 유리 "pill"이 된다 ──
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FilterHeader(
                    selected: _filter,
                    counts: counts,
                    onSelect: _select,
                    labels: (l10n.statForPlans, l10n.statAll, l10n.statSoon),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SectionHeader(switch (_filter) {
                    HomeFilter.all => l10n.homeGreeting,
                    HomeFilter.plans => l10n.homeSectionPlans,
                    HomeFilter.deadlines => l10n.homeSectionDeadlines,
                  }),
                ),

                // ── 카드 ──
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: d,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == cards.key;
                      final dx = (incoming == _forward) ? 0.18 : -0.18;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: cards,
                  ),
                ),
                // 떠 있는 하단 내비게이션이 콘텐츠를 가리지 않도록.
                SliverToBoxAdapter(child: SizedBox(height: Space.xxxl + MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }

  /// 화면에 보이는 동안의 카드 순서. 👍를 누르면 취향 점수가 바뀌어 순위가 다시 매겨지는데,
  /// 누른 카드가 손가락 아래에서 다른 곳으로 튀지 않도록 이미 본 카드는 자리를 지킨다.
  /// 새 카드는 순위대로 뒤에 붙고, 👎 카드는 맨 아래로. 새로 고침·필터 변경 때 다시 정렬.
  final List<String> _order = [];

  List<Insight> _stable(List<Insight> ranked) {
    final known = {for (var i = 0; i < _order.length; i++) _order[i]: i};
    final rank = {for (var i = 0; i < ranked.length; i++) ranked[i].id: i};
    int key(Insight x) => known[x.id] ?? _order.length + rank[x.id]!;
    final liked = ranked.where((x) => x.feedback != InsightFeedback.dislike).toList()
      ..sort((a, b) => key(a).compareTo(key(b)));
    final disliked = ranked.where((x) => x.feedback == InsightFeedback.dislike).toList();
    final out = [...liked, ...disliked];
    _order
      ..clear()
      ..addAll(out.map((x) => x.id));
    return out;
  }

  /// 앞/뒤 — 카드가 어느 방향으로 밀릴지 정한다.
  bool _forward = true;

  void _select(HomeFilter f) {
    if (f == _filter) return;
    HapticFeedback.selectionClick();
    setState(() {
      _forward = f.index > _filter.index;
      _filter = f;
      _order.clear();
    });
  }

  static DateTime _deadlineOf(WidgetRef ref, Insight i) {
    final e = i.eventIds.isEmpty ? null : ref.read(eventByIdProvider(i.eventIds.first));
    return e?.deadline ?? DateTime(9999);
  }
}

/// 고정 필터 — 하단 내비게이션과 같은 "liquid glass" 캡슐: 아이콘 + 라벨,
/// 개수는 아이콘 모서리에 ("Due soon"은 빨강). 스크롤해도 거의 작아지지 않고 조금만
/// 촘촘해지며 더 투명해진다 (뒤의 카드가 흐리게 비친다).
class _FilterHeader extends SliverPersistentHeaderDelegate {
  _FilterHeader({required this.selected, required this.counts, required this.onSelect, required this.labels});

  final HomeFilter selected;
  final Map<HomeFilter, int> counts;
  final ValueChanged<HomeFilter> onSelect;
  final (String, String, String) labels;

  static const _max = 104.0;
  static const _min = 92.0;

  @override
  double get maxExtent => _max;

  @override
  double get minExtent => _min;

  @override
  bool shouldRebuild(_FilterHeader old) =>
      old.selected != selected || old.counts.toString() != counts.toString() || old.labels != labels;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final k = Curves.easeInOut.transform((shrinkOffset / (_max - _min)).clamp(0.0, 1.0));
    double lerp(double a, double b) => a + (b - a) * k;
    final d = Motion.of(context, const Duration(milliseconds: 380));
    const red = Color(0xFFED4245);

    Widget badge(HomeFilter f, int n, bool on) {
      final urgent = f == HomeFilter.deadlines && n > 0;
      return Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: urgent ? red : (on ? p.primary : p.textMuted.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            color: urgent || on ? Colors.white : p.text,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      );
    }

    Widget cell(HomeFilter f, IconData icon, IconData iconOn, String label) {
      final on = f == selected;
      final n = counts[f] ?? 0;
      final color = on ? p.primary : p.text;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: '$label $n',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(f),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedScale(
                        duration: d,
                        curve: Curves.easeOutBack,
                        scale: on ? 1.12 : 1,
                        child: Icon(on ? iconOn : icon, size: 22, color: color),
                      ),
                      Positioned(right: -14, top: -7, child: badge(f, n, on)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelMedium!.copyWith(color: color, fontWeight: on ? FontWeight.w700 : FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final n = HomeFilter.values.length;
    return Padding(
      // 고정되어도 화면 끝에 붙지 않고 (위쪽 ~14 px), 양옆으로 조금 안쪽에 위치한다.
      padding: EdgeInsets.fromLTRB(lerp(Space.gutter, Space.gutter + 8), 14, lerp(Space.gutter, Space.gutter + 8), 10),
      child: GlassSurface(
        opacity: lerp(dark ? 0.62 : 0.80, dark ? 0.48 : 0.55),
        blur: 20,
        padding: const EdgeInsets.all(5),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: d,
              curve: Curves.easeOutBack,
              alignment: Alignment(-1 + 2 * selected.index / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withValues(alpha: 0.13) : p.primarySoft.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                cell(HomeFilter.plans, Icons.event_note_outlined, Icons.event_note_rounded, labels.$1),
                cell(HomeFilter.all, Icons.radar_outlined, Icons.radar, labels.$2),
                cell(HomeFilter.deadlines, Icons.hourglass_empty_rounded, Icons.hourglass_bottom_rounded, labels.$3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 신호 열기: 행사가 있으면 행사 창(+ "이유" 블록), 없으면 신호 창.
void openSignal(BuildContext context, WidgetRef ref, Insight insight) {
  final event = insight.eventIds.isEmpty ? null : ref.read(eventByIdProvider(insight.eventIds.first));
  if (event != null) {
    showEventDetail(
      context,
      event,
      insight: insight,
      onShowOnMap: event.placeless
          ? null
          : () {
              ref.read(mapFocusProvider.notifier).focus(event.id);
              context.go('/map');
            },
    );
    return;
  }
  ref.read(seenProvider.notifier).mark(['insight:${insight.id}']);
  final plan = insight.planId == null ? null : ref.read(plansProvider).where((p) => p.id == insight.planId).firstOrNull;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // 떠 있는 하단 내비게이션 위로 — 창의 아래쪽이 가려지지 않게.
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SignalWhyBlock(insight: insight, standalone: true),
            if (plan?.location != null) ...[
              const SizedBox(height: Space.md),
              WeatherChip(location: plan!.location!, date: plan.start),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 간결한 신호 카드: 무엇(제목) · 언제 · 어디서 · 누구에게(관심사).
/// 자세한 내용("왜 중요한가", 출처, 배너, 링크)은 눌렀을 때.
class InsightCard extends ConsumerWidget {
  const InsightCard({super.key, required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final interests = ref.watch(interestsProvider);
    final seen = ref.watch(seenProvider);
    final plan = insight.planId == null
        ? null
        : ref.watch(plansProvider).where((x) => x.id == insight.planId).firstOrNull;
    final event = insight.eventIds.isEmpty ? null : ref.watch(eventByIdProvider(insight.eventIds.first));
    final (kindLabel, kindIcon, tone) = insightKindMeta(context, insight.kind);
    final isSeen = seen.contains('insight:${insight.id}') || (event != null && seen.contains('event:${event.id}'));

    // 무엇 — 행사가 있으면 행사 이름(짧고 명확하게), 없으면 신호 제목.
    final what = event != null ? context.tr(event.title) : context.tr(insight.title);

    // QACHON
    String? when;
    if (event != null && event.placeless && event.deadline != null) {
      // 배지가 이미 "Deadline"이면 — 반복하지 않는다.
      final date = context.formatDate(event.isApplication ? event.applicationDate(event.deadline!) : event.deadline!);
      when = insight.kind == InsightKind.deadline ? date : '${l10n.kindDeadline} · $date';
    } else if (event != null) {
      final from = plan != null && event.start.isBefore(plan.start) ? plan.start : event.start;
      when = event.start.isBefore(today) && plan == null
          ? l10n.untilDate(context.formatDate(event.end))
          : (from.hour == 0 && from.minute == 0 ? context.formatDate(from) : context.formatDateTime(from));
    } else if (plan != null) {
      when = context.formatDate(plan.start);
    }

    // QAYERDA
    String? where;
    if (event != null && event.placeless) {
      where = event.city == '전국' ? l10n.nationwide : event.city;
    } else if (event != null) {
      where = [event.venue, event.city].where((s) => s.isNotEmpty).join(' · ');
    } else if (plan != null && plan.locationText.isNotEmpty) {
      where = plan.locationText;
    }

    // 누구에게 / 무엇에 관한 — 일치하는 관심사(최대 2개), 없으면 카테고리.
    final matched = [
      for (final tag in event?.tags ?? const <String>[])
        if (interests.contains(tag)) ?interestByTag(tag),
    ].take(2).toList();

    // 마감이 가까우면 오른쪽 위에 D-n.
    final dl = event?.deadline;
    final left = dl == null ? null : DateTime(dl.year, dl.month, dl.day).difference(today).inDays;
    final showLeft = left != null && left >= 0 && left <= 14;

    /// 👍/👎: 이미 누른 상태에서 다시 누르면 취소 (확인 후).
    /// 👎도 확인을 거친다 (실수로 누르지 않도록).
    Future<void> react(InsightFeedback f) async {
      final notifier = ref.read(insightFeedbackProvider.notifier);
      final current = insight.feedback;
      if (current == f) {
        final undo = await showConfirm(
          context,
          icon: f == InsightFeedback.like ? Icons.thumb_up_off_alt_rounded : Icons.visibility_outlined,
          title: f == InsightFeedback.like ? l10n.likeUndoTitle : l10n.dislikeUndoTitle,
          body: f == InsightFeedback.like ? l10n.likeUndoBody : l10n.dislikeUndoBody,
          confirmLabel: f == InsightFeedback.like ? l10n.removeLike : l10n.showAgain,
          cancelLabel: l10n.keep,
        );
        if (!undo) return;
        Toast.show(l10n.feedbackCleared, type: ToastType.info);
        await notifier.clear(insight.id);
        return;
      }
      if (f == InsightFeedback.dislike) {
        if (!context.mounted) return;
        final ok = await showConfirm(
          context,
          icon: Icons.thumb_down_alt_outlined,
          title: l10n.dislikeConfirmTitle,
          body: l10n.dislikeConfirmBody,
          confirmLabel: l10n.notForMeConfirm,
          cancelLabel: l10n.keep,
        );
        if (!ok) return;
      }
      // 화면과 토스트가 먼저, 기기 저장은 그 뒤에.
      Toast.show(f == InsightFeedback.like ? l10n.feedbackLiked : l10n.feedbackDisliked);
      HapticFeedback.lightImpact();
      await notifier.set(insight.id, f);
    }

    return AnimatedOpacity(
      duration: Motion.of(context, Motion.normal),
      // 열어 본 카드: 살짝만 흐리게 + 테두리 없이 (새 카드와 한눈에 구분).
      opacity: isSeen ? 0.82 : 1,
      child: Card(
        shape: isSeen ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)) : null,
        child: InkWell(
          onTap: () => openSignal(context, ref, insight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 종류 + 연결된 일정 + 마감
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Row(
                    children: [
                      Pill(kindLabel, icon: kindIcon, tone: tone, dense: true),
                      const Spacer(),
                      if (showLeft) Pill(left == 0 ? l10n.today : 'D-$left', tone: Tone.accent, dense: true),
                    ],
                  ),
                ),
                const SizedBox(height: Space.sm),
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: MarqueeText(what, style: t.titleMedium),
                ),
                const SizedBox(height: 6),
                if (insight.trafficContext != null) TrafficMetadata(insight.trafficContext!),
                if (when != null) MetaRow(Icons.schedule_outlined, when),
                if (where != null && where.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  MetaRow(event?.placeless == true ? Icons.apartment_outlined : Icons.place_outlined, where),
                ],
                // 이유 — 캘린더의 어떤 일정과 연결되는지 (있는 사실만: 날짜, 이름, 거리).
                if (plan != null) ...[
                  const SizedBox(height: Space.sm),
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: _PlanLink(insight: insight, plan: plan, event: event),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: QuietTags([
                        for (final o in matched) QuietTag(context.tr(o.label), icon: o.icon),
                        if (matched.isEmpty && event != null)
                          QuietTag(context.categoryLabel(event.category), icon: categoryIcon(event.category)),
                      ]),
                    ),
                    IconButton(
                      tooltip: l10n.helpful,
                      visualDensity: VisualDensity.compact,
                      isSelected: insight.feedback == InsightFeedback.like,
                      selectedIcon: Icon(Icons.thumb_up_rounded, color: p.primary, size: 18),
                      icon: Icon(Icons.thumb_up_outlined, size: 18, color: p.textMuted),
                      onPressed: () => react(InsightFeedback.like),
                    ),
                    IconButton(
                      tooltip: l10n.notForMe,
                      visualDensity: VisualDensity.compact,
                      isSelected: insight.feedback == InsightFeedback.dislike,
                      selectedIcon: Icon(Icons.thumb_down_rounded, color: p.textMuted, size: 18),
                      icon: Icon(Icons.thumb_down_outlined, size: 18, color: p.textMuted),
                      onPressed: () => react(InsightFeedback.dislike),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드의 "이유" 줄: 신호가 캘린더의 어떤 일정과 연결되는지.
/// 계산된 사실만 표시 — 추천 시간이나 이동 시간처럼 우리가 계산하지 않은 값은 만들지 않는다.
class _PlanLink extends StatelessWidget {
  const _PlanLink({required this.insight, required this.plan, this.event});

  final Insight insight;
  final Plan plan;
  final RadarEvent? event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final km = event == null || plan.location == null || event!.placeless
        ? null
        : RouteMatcher.haversineKm(plan.location!, event!.location).toStringAsFixed(1);
    final kind = insight.id.split(':').first;
    final weather = insight.signals.where((s) => s.type == SignalType.weather).firstOrNull;
    final relation = switch (kind) {
      'nearby' when km != null => l10n.planLinkNearby(km),
      'crowd' when km != null => l10n.planLinkCrowd(km),
      'traffic' => l10n.planLinkTraffic,
      'strike' => l10n.planLinkStrike,
      'rain' when weather != null => context.tr(weather.summary),
      _ => null,
    };
    final alert = insight.kind == InsightKind.planAlert;
    final (fg, bg) = alert ? (p.accent, p.accentSoft) : (p.primary, p.primarySoft);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.event_note_rounded, size: 20, color: fg)),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.formatDate(plan.start)} · ${plan.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelLarge!.copyWith(color: p.text),
                ),
                if (relation != null)
                  Text(
                    relation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelMedium!.copyWith(color: fg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈 머리의 AI 비서 버튼 — 브랜드 그라데이션 알약 (✨ AI 비서).
class _AskAiButton extends StatelessWidget {
  const _AskAiButton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.assistantTitle,
      child: Pressable(
        scale: 0.94,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: p.brandGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: p.primary.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.push('/assistant'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md + 2, vertical: Space.sm + 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: p.onPrimary),
                    const SizedBox(width: 6),
                    Text(l10n.assistantButton, style: context.textStyles.labelLarge!.copyWith(color: p.onPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../event/event_cover.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../event/event_detail_sheet.dart';

enum DiscoverPeriod { today, weekend, week, month }

enum DiscoverSort { match, soon }

/// 공고의 지역은 명시된 참가 지역만 사용한다.
String discoverRegionOf(RadarEvent e) => e.placeless ? e.city : KoreaRegions.regionOf(e.location);

/// 기간 [from, to) — 행사 기간이 겹치면 포함.
(DateTime, DateTime) discoverPeriodRange(DiscoverPeriod p, DateTime today) => switch (p) {
  DiscoverPeriod.today => (today, today.add(const Duration(days: 1))),
  // 다가오는 토·일 (일요일이면 오늘만).
  DiscoverPeriod.weekend =>
    today.weekday == DateTime.sunday
        ? (today, today.add(const Duration(days: 1)))
        : (
            today.add(Duration(days: DateTime.saturday - today.weekday)),
            today.add(Duration(days: DateTime.saturday - today.weekday + 2)),
          ),
  DiscoverPeriod.week => (today, today.add(const Duration(days: 7))),
  DiscoverPeriod.month => (today, today.add(const Duration(days: 31))),
};

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  EventCategory? _category;
  DiscoverPeriod? _period;
  String? _region;
  bool _freeOnly = false;
  bool _mineOnly = false;
  DiscoverSort _sort = DiscoverSort.match;
  String _query = '';
  final _search = TextEditingController();

  /// 실제 데이터에는 행사가 수백 개 — 나누어 보여준다.
  static const _pageSize = 30;
  int _limit = _pageSize;

  bool get _filtered =>
      _category != null || _period != null || _region != null || _freeOnly || _mineOnly || _query.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _update(VoidCallback f) => setState(() {
    f();
    _limit = _pageSize;
  });

  void _reset() => _update(() {
    _category = null;
    _period = null;
    _region = null;
    _freeOnly = false;
    _mineOnly = false;
    _query = '';
    _search.clear();
  });

  String _periodLabel(DiscoverPeriod p) => switch (p) {
    DiscoverPeriod.today => context.l10n.periodToday,
    DiscoverPeriod.weekend => context.l10n.periodWeekend,
    DiscoverPeriod.week => context.l10n.periodWeek,
    DiscoverPeriod.month => context.l10n.periodMonth,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final interests = ref.watch(interestsProvider);
    final taste = ref.watch(tasteProvider);
    final feed = ref.watch(eventFeedProvider);
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final all = ref.watch(eventsProvider).where((e) => e.applicationVisible(now) && !e.end.isBefore(today)).toList();
    final q = _query.trim().toLowerCase();
    final range = _period == null ? null : discoverPeriodRange(_period!, today);

    bool matches(RadarEvent e, {bool ignoreCategory = false}) {
      if (!ignoreCategory && _category != null && e.category != _category) return false;
      if (range != null && !(e.start.isBefore(range.$2) && !e.end.isBefore(range.$1))) return false;
      if (_region != null && discoverRegionOf(e) != _region) return false;
      if (_freeOnly && e.isFree != true) return false;
      if (_mineOnly && !e.tags.any(interests.contains)) return false;
      if (q.isNotEmpty) {
        final hay = '${e.title.ko} ${e.title.en} ${e.venue} ${e.city} ${e.eligibilityText ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }

    // 진행 중인(이미 시작한) 행사는 오늘 행사로 본다.
    DateTime eff(RadarEvent e) => e.start.isBefore(today) ? today : e.start;
    int bySoon(RadarEvent a, RadarEvent b) => eff(a).compareTo(eff(b));
    int byMatch(RadarEvent a, RadarEvent b) {
      final s = taste.score(b, interests).compareTo(taste.score(a, interests));
      return s != 0 ? s : bySoon(a, b);
    }

    final events = all.where(matches).toList()..sort(_sort == DiscoverSort.match ? byMatch : bySoon);
    // 카테고리 칩은 다른 필터가 적용된 결과 기준으로 개수를 보여준다.
    final catCounts = <EventCategory, int>{};
    for (final e in all.where((e) => matches(e, ignoreCategory: true))) {
      catCounts[e.category] = (catCounts[e.category] ?? 0) + 1;
    }
    final categories = catCounts.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    final regionCounts = <String, int>{};
    for (final e in all) {
      final r = discoverRegionOf(e);
      regionCounts[r] = (regionCounts[r] ?? 0) + 1;
    }
    final regions = regionCounts.keys.toList()..sort((a, b) => regionCounts[b]!.compareTo(regionCounts[a]!));

    // 필터 없이 볼 때: 관심사에 가장 잘 맞는, 포스터가 있는 행사 몇 개.
    final picks = _filtered || interests.isEmpty
        ? const <RadarEvent>[]
        : (all.where((e) => e.imageUrl != null && e.tags.any(interests.contains)).toList()..sort(byMatch))
              .take(10)
              .toList();

    Widget chipRow(List<Widget> chips) => SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabDiscover)),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.xxxl + MediaQuery.paddingOf(context).bottom),
        children: [
          // ── 검색 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: TextField(
              controller: _search,
              onChanged: (v) => _update(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.discoverSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _update(() {
                          _query = '';
                          _search.clear();
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),

          // ── 빠른 필터: 기간 · 지역 · 무료 · 내 관심사 · 정렬 ──
          chipRow([
            _MenuChip<DiscoverPeriod>(
              icon: Icons.event_outlined,
              label: _period == null ? l10n.filterPeriod : _periodLabel(_period!),
              selected: _period != null,
              values: DiscoverPeriod.values,
              current: _period,
              itemLabel: _periodLabel,
              allLabel: l10n.filterAnyTime,
              onChanged: (v) => _update(() => _period = v),
            ),
            _MenuChip<String>(
              icon: Icons.place_outlined,
              label: _region ?? l10n.filterRegion,
              selected: _region != null,
              values: regions,
              current: _region,
              itemLabel: (r) => '$r · ${regionCounts[r]}',
              allLabel: l10n.filterAllRegions,
              onChanged: (v) => _update(() => _region = v),
            ),
            FilterChip(label: Text(l10n.free), selected: _freeOnly, onSelected: (v) => _update(() => _freeOnly = v)),
            if (interests.isNotEmpty)
              FilterChip(
                avatar: const Icon(Icons.favorite_border_rounded),
                label: Text(l10n.filterMine),
                selected: _mineOnly,
                onSelected: (v) => _update(() => _mineOnly = v),
              ),
            _MenuChip<DiscoverSort>(
              icon: Icons.sort_rounded,
              label: _sort == DiscoverSort.match ? l10n.sortMatch : l10n.sortSoon,
              selected: false,
              values: DiscoverSort.values,
              current: _sort,
              itemLabel: (v) => v == DiscoverSort.match ? l10n.sortMatch : l10n.sortSoon,
              onChanged: (v) => _update(() => _sort = v ?? DiscoverSort.match),
            ),
          ]),

          // ── 카테고리 (개수 포함) ──
          chipRow([
            ChoiceChip(
              label: Text(l10n.discoverAll),
              selected: _category == null,
              onSelected: (_) => _update(() => _category = null),
            ),
            for (final c in categories)
              ChoiceChip(
                avatar: Icon(categoryIcon(c)),
                label: Text('${context.categoryLabel(c)} ${catCounts[c]}'),
                selected: _category == c,
                onSelected: (_) => _update(() => _category = _category == c ? null : c),
              ),
          ]),

          // ── 관심사 맞춤 (포스터) ──
          if (picks.isNotEmpty) ...[
            SectionHeader(l10n.discoverPicks),
            SizedBox(
              height: 262,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                itemCount: picks.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                itemBuilder: (_, i) => Pressable(child: _PosterCard(picks[i])),
              ),
            ),
          ],

          // ── 결과 개수 · 초기화 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.sm, Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _filtered ? l10n.discoverResults(events.length) : l10n.discoverSubtitle,
                    style: t.labelLarge!.copyWith(color: p.textMuted),
                  ),
                ),
                if (_filtered)
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(l10n.filterReset),
                  ),
              ],
            ),
          ),

          // ── 목록 ──
          if (events.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.discoverNoResults,
              actions: [OutlinedButton(onPressed: _reset, child: Text(l10n.filterReset))],
            )
          else
            for (var i = 0; i < events.length && i < _limit; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                child: FadeSlideIn(
                  key: ValueKey(events[i].id),
                  index: i % _pageSize,
                  child: Pressable(child: EventCard(event: events[i], interests: interests)),
                ),
              ),
          if (events.length > _limit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: OutlinedButton(
                onPressed: () => setState(() => _limit += _pageSize),
                child: Text('${l10n.showMore} (${events.length - _limit})'),
              ),
            ),
          if (feed.generatedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined, size: 14, color: p.textMuted),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      l10n.eventsUpdated(feed.events.length, context.formatDateTime(feed.generatedAt!.toLocal())),
                      style: t.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 누르면 선택지 메뉴가 열리는 필터 칩 (기간 · 지역 · 정렬).
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.values,
    required this.current,
    required this.itemLabel,
    required this.onChanged,
    this.allLabel,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final List<T> values;
  final T? current;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  /// 있으면 맨 위에 "전체" 선택지 (null).
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MenuAnchor(
      menuChildren: [
        if (allLabel != null)
          MenuItemButton(
            leadingIcon: Icon(current == null ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
            onPressed: () => onChanged(null),
            child: Text(allLabel!),
          ),
        for (final v in values)
          MenuItemButton(
            leadingIcon: Icon(current == v ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
            onPressed: () => onChanged(v),
            child: Text(itemLabel(v)),
          ),
      ],
      builder: (context, menu, _) => FilterChip(
        avatar: Icon(icon),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: selected ? p.primary : p.textMuted),
          ],
        ),
        selected: selected,
        onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// 관심사 맞춤 가로 목록의 포스터 카드.
class _PosterCard extends ConsumerWidget {
  const _PosterCard(this.event);
  final RadarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textStyles;
    return SizedBox(
      width: 136,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showEventDetail(
          context,
          event,
          onShowOnMap: event.placeless ? null : () {
            ref.read(mapFocusProvider.notifier).focus(event.id);
            context.go('/map');
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  event.imageUrl!,
                  fit: BoxFit.cover,
                  // 웹: CORS가 없는 포스터 서버도 <img>로 보여준다.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => EventCover(category: event.category, seed: event.id),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(context.tr(event.title), style: t.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              '${DateFormat.MMMd(context.lang).format(event.start)} · ${discoverRegionOf(event)}',
              style: t.labelSmall,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// 행사 카드: 날짜 타일 + 카테고리 + 이름 + 장소 + 일치하는 태그.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, required this.interests, this.trailing});

  final RadarEvent event;
  final Set<String> interests;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textStyles;
    final l10n = context.l10n;
    final matched = event.tags.where(interests.contains).toList();
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    // 몇 달씩 이어지는 전시/강좌: 지난 시작일 대신 종료일.
    final ongoing = event.start.isBefore(today);
    final tileDate = event.isApplication && event.deadline != null ? event.applicationDate(event.deadline!) : ongoing ? event.end : event.start;
    final seen = ref.watch(seenProvider).contains('event:${event.id}');
    return AnimatedOpacity(
      duration: Motion.of(context, Motion.normal),
      // 열어 본 행사: 살짝만 흐리게 + 테두리 없이.
      opacity: seen ? 0.82 : 1,
      // 3D 블록: 새 행사는 아래 입술, 열어 본 행사는 평평하게.
      child: Press3D(
        face: context.palette.surface,
        lip: seen ? null : cardLip(context),
        onTap: () => showEventDetail(
            context,
            event,
            onShowOnMap: event.placeless ? null : () {
              ref.read(mapFocusProvider.notifier).focus(event.id);
              context.go('/map');
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateTile(tileDate, monthLabel: '${event.isApplication ? '' : ongoing ? '~' : ''}${DateFormat.MMM(context.lang).format(tileDate)}'),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 · 상태 — 차분한 글자; "무료"는 색으로만 구분.
                      QuietTags([
                        QuietTag(context.categoryLabel(event.category), icon: categoryIcon(event.category)),
                        if (event.isApplication) QuietTag(event.applicationStale(now) ? l10n.verificationDelayed : switch(event.applicationStatusAt(now)) { 'open' => l10n.applicationOpen, 'upcoming' => l10n.applicationUpcoming, _ => l10n.applicationUnknown })
                        else if (ongoing) QuietTag(l10n.ongoing),
                        if (event.isFree == true) QuietTag(l10n.free, color: context.palette.primary),
                        if (event.isSample) QuietTag(l10n.sampleData),
                      ]),
                      const SizedBox(height: 6),
                      Text(context.tr(event.title), style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      MetaRow(event.placeless ? Icons.apartment_outlined : Icons.place_outlined, '${event.venue} · ${event.city}'),
                      if(event.isApplication) Text('${l10n.applicationDeadline}: ${context.formatDate(tileDate)}', style:t.labelSmall),
                      if (matched.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        QuietTags([
                          for (final tag in matched)
                            if (interestByTag(tag) case final o?) QuietTag(context.tr(o.label), icon: o.icon),
                        ]),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Padding(
                      padding: const EdgeInsets.only(left: Space.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        child: SizedBox(
                          width: 56,
                          height: 74,
                          // 포스터가 없으면 기본 그림 — 목록의 모양이 들쭉날쭉하지 않게.
                          child: event.imageUrl == null
                              ? EventCover(category: event.category, seed: event.id, iconSize: 18)
                              : Image.network(
                                  event.imageUrl!,
                                  fit: BoxFit.cover,
                                  // 웹: CORS가 없는 포스터 서버도 <img>로 보여준다.
                                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                  errorBuilder: (_, _, _) => EventCover(category: event.category, seed: event.id, iconSize: 18),
                                ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../event/event_detail_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  EventCategory? _category;

  /// 실제 데이터에는 행사가 수백 개 — 나누어 보여준다.
  static const _pageSize = 30;
  int _limit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final interests = ref.watch(interestsProvider);
    final taste = ref.watch(tasteProvider);
    final feed = ref.watch(eventFeedProvider);
    final now = ref.watch(nowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final all = ref.watch(eventsProvider).where((e) => !e.end.isBefore(today)).toList();
    final events = all.where((e) => _category == null || e.category == _category).toList()
      ..sort((a, b) {
        final byScore = taste.score(b, interests).compareTo(taste.score(a, interests));
        if (byScore != 0) return byScore;
        // 진행 중인(이미 시작한) 행사는 오늘 행사로 본다.
        DateTime eff(RadarEvent e) => e.start.isBefore(today) ? today : e.start;
        return eff(a).compareTo(eff(b));
      });
    final categories = all.map((e) => e.category).toSet().toList()..sort((a, b) => a.index.compareTo(b.index));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabDiscover)),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.xxxl + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(l10n.discoverSubtitle, style: t.bodySmall),
          ),
          if (feed.generatedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
              child: Row(children: [
                Icon(Icons.cloud_done_outlined, size: 14, color: context.palette.textMuted),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l10n.eventsUpdated(feed.events.length, context.formatDateTime(feed.generatedAt!.toLocal())),
                    style: t.labelSmall,
                  ),
                ),
              ]),
            ),
          const SizedBox(height: Space.md),

          // ── 카테고리 ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                ChoiceChip(
                  label: Text(l10n.discoverAll),
                  selected: _category == null,
                  onSelected: (_) => setState(() {
                    _category = null;
                    _limit = _pageSize;
                  }),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: Space.sm),
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c)),
                    label: Text(context.categoryLabel(c)),
                    selected: _category == c,
                    onSelected: (_) => setState(() {
                      _category = c;
                      _limit = _pageSize;
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          // ── 목록 ──
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            child: Column(
              key: ValueKey(_category),
              children: [
                for (var i = 0; i < events.length && i < _limit; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                    child: FadeSlideIn(
                      index: i % _pageSize,
                      child: EventCard(event: events[i], interests: interests),
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
              ],
            ),
          ),
        ],
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
    final tileDate = ongoing ? event.end : event.start;
    final seen = ref.watch(seenProvider).contains('event:${event.id}');
    return AnimatedOpacity(
      duration: Motion.of(context, Motion.normal),
      opacity: seen ? 0.6 : 1,
      child: Card(
        child: InkWell(
          onTap: () => showEventDetail(
            context,
            event,
            onShowOnMap: () {
              ref.read(mapFocusProvider.notifier).focus(event.id);
              context.go('/map');
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateTile(tileDate, monthLabel: '${ongoing ? '~' : ''}${DateFormat.MMM(context.lang).format(tileDate)}'),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 · 상태 — 차분한 글자; "무료"는 색으로만 구분.
                      QuietTags([
                        QuietTag(context.categoryLabel(event.category), icon: categoryIcon(event.category)),
                        if (ongoing) QuietTag(l10n.ongoing),
                        if (event.isFree == true) QuietTag(l10n.free, color: context.palette.primary),
                        if (event.isSample) QuietTag(l10n.sampleData),
                      ]),
                      const SizedBox(height: 6),
                      Text(context.tr(event.title), style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      MetaRow(Icons.place_outlined, '${event.venue} · ${event.city}'),
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
                trailing ?? Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

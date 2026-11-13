import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/share.dart';
import 'event_actions.dart';
import 'event_cover.dart';
import '../../data/calendar_added.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../weather/weather_chip.dart';
import 'signal_why_block.dart';

Future<void> showEventDetail(
  BuildContext context,
  RadarEvent event, {
  VoidCallback? onShowOnMap,
  RouteOpportunity? opportunity,
  Insight? insight,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true, // 하단 내비게이션까지 덮고, 전체 화면으로 펼칠 수 있다
    showDragHandle: false, // DetailSheet가 자체 핸들을 그린다
    builder: (_) =>
        EventDetailSheet(event: event, onShowOnMap: onShowOnMap, opportunity: opportunity, insight: insight),
  );
}

class EventDetailSheet extends ConsumerStatefulWidget {
  const EventDetailSheet({super.key, required this.event, this.onShowOnMap, this.opportunity, this.insight});

  final RadarEvent event;
  final VoidCallback? onShowOnMap;

  /// 경로 모드에서 열렸을 때: 경로에서의 거리와 추가 이동.
  final RouteOpportunity? opportunity;

  /// 홈 카드에서 열렸을 때: 신호가 뜬 이유 (카드에 표시하지 않는 세부 정보).
  final Insight? insight;

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  bool _adding = false;

  RadarEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    // 본 것으로 표시한다 (카드가 흐려짐). build 이후에 — build 중에 provider를 바꾸지 않기 위해.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(seenProvider.notifier).mark([
        'event:${event.id}',
        if (widget.insight != null) 'insight:${widget.insight!.id}',
      ]);
    });
  }

  Future<void> _addToCalendar() async {
    if (_adding) return;
    setState(() => _adding = true);
    final ok = await addEventToCalendar(context, ref, event);
    if (!mounted) return;
    setState(() => _adding = false);
    // 넣었으면(또는 이미 있었으면) 창을 닫는다 — 결과는 토스트로 남는다.
    if (ok) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final interests = ref.watch(interestsProvider);
    final matched = event.tags.where(interests.contains).toList();
    final o = widget.opportunity;
    final now = ref.watch(nowProvider);
    final ongoing = event.start.isBefore(DateTime(now.year, now.month, now.day));

    final already = ref.watch(calendarAddedProvider).contains(event.id);
    final addButton = FilledButton.icon(
      onPressed: _adding || !event.applicationActionable(now) ? null : _addToCalendar,
      style: already ? FilledButton.styleFrom(backgroundColor: p.primarySoft, foregroundColor: p.primary) : null,
      icon: _adding
          ? AppSpinner(color: p.textMuted)
          : Icon(already ? Icons.event_available_rounded : Icons.event_available_outlined),
      label: Text(_adding ? l10n.addingToCalendar : already ? l10n.calendarAddedLabel : l10n.addToCalendar),
    );

    return DetailSheet(
      bodyBuilder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        children: [
          // 포스터가 없어도 같은 자리에 기본 그림 — 화면 모양이 일정하게.
          _Poster(event.imageUrl, event: event),
          const SizedBox(height: Space.lg),

          // ── 무엇: 카테고리 (차분하게) + 제목 ──
          QuietTags([
            QuietTag(context.categoryLabel(event.category), icon: categoryIcon(event.category)),
            if (event.isApplication) QuietTag(event.applicationStale(now) ? l10n.verificationDelayed : switch(event.applicationStatusAt(now)) { 'open' => l10n.applicationOpen, 'upcoming' => l10n.applicationUpcoming, 'closed' => l10n.applicationClosed, 'cancelled' => l10n.applicationCancelled, _ => l10n.applicationUnknown })
            else if (ongoing) QuietTag(l10n.ongoing),
            if (event.isSample) QuietTag(l10n.sampleData),
          ]),
          const SizedBox(height: Space.sm),
          Text(context.tr(event.title), style: t.headlineSmall!.copyWith(height: 1.3)),
          const SizedBox(height: Space.lg),

          // ── 한눈에: 언제 · 어디서 · 요금 · 마감 ──
          _FactsCard(
            children: [
              if (event.placeless || event.applicationStart != null)
                _Fact(
                  icon: Icons.event_available_outlined,
                  label: l10n.applicationLabel,
                  value: '${context.formatDate(event.isApplication ? event.applicationDate(event.applicationStart ?? event.start) : event.start)} – ${context.formatDate(event.isApplication ? event.applicationDate(event.deadline ?? event.end) : event.end)}',
                ),
              if (!event.placeless)
                _Fact(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.planWhen,
                  value: _dateRange(context, event),
                  sub: event.eventDatePrecision == 'date' ? null : _timeRange(context, event),
                  extra: WeatherChip(location: event.location, date: event.start),
                ),
              if (event.placeless)
                _Fact(
                  icon: Icons.apartment_outlined,
                  label: l10n.organizer,
                  value: event.venue.isEmpty ? l10n.applicationUnknown : event.venue,
                  sub: event.city == '전국' ? l10n.nationwide : event.city,
                )
              else
                _Fact(
                  icon: Icons.place_outlined,
                  label: l10n.planWhere,
                  value: event.venue,
                  sub: event.city,
                  trailing: widget.onShowOnMap == null
                      ? null
                      : IconButton.filledTonal(
                          tooltip: l10n.showOnMap,
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onShowOnMap!();
                          },
                          icon: const Icon(Icons.map_outlined, size: 20),
                        ),
                ),
              if (event.isApplication)
                _Fact(icon: Icons.badge_outlined, label:l10n.eligibilityLabel,
                  value:event.eligibilityText ?? l10n.eligibilityUnknown),
              if (event.isApplication && event.lastVerifiedAt != null)
                _Fact(icon:Icons.update_outlined,label:l10n.verifiedAtLabel,
                  value:'${context.formatDateTime(event.lastVerifiedAt!.toUtc().add(const Duration(hours:9)))} KST',
                  sub:event.applicationStale(now) ? l10n.verificationDelayed : null),
              if (event.isFree == true || event.price != null)
                _Fact(
                  icon: Icons.confirmation_number_outlined,
                  label: l10n.eventPrice,
                  value: event.isFree == true ? l10n.free : event.price!,
                  tone: event.isFree == true ? Tone.primary : Tone.neutral,
                ),
              if (event.deadline != null)
                _Fact(
                  icon: Icons.hourglass_bottom_rounded,
                  label: event.isApplication ? l10n.applicationDeadline : l10n.kindDeadline,
                  value: context.formatDate(event.isApplication ? event.applicationDate(event.deadline!) : event.deadline!),
                  sub: event.deadlinePrecision == 'datetime' ? '${event.applicationDate(event.deadline!).hour.toString().padLeft(2,'0')}:${event.applicationDate(event.deadline!).minute.toString().padLeft(2,'0')} KST' : null,
                  tone: Tone.accent,
                  trailing: event.applicationStale(now) ? null : _daysLeft(context, event.isApplication ? event.applicationDate(event.deadline!) : event.deadline!),
                ),
              if (o != null)
                _Fact(
                  icon: Icons.alt_route_rounded,
                  label: l10n.onYourWay,
                  value: o.detourKm != null
                      ? l10n.routeDetour(o.detourKm!.toStringAsFixed(1), o.detourMinutes!)
                      : l10n.routeFromRoute(o.distanceFromRouteKm.toStringAsFixed(1)),
                  tone: Tone.primary,
                ),
            ],
          ),

          // ── 표시된 이유 (신호) ──
          if (widget.insight != null) ...[const SizedBox(height: Space.md), SignalWhyBlock(insight: widget.insight!)],

          // ── 내용 ──
          SectionHeader(l10n.eventAbout, padding: const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.sm)),
          ExpandableText(context.tr(event.description), maxLines: 4),

          if (matched.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Text(l10n.matchesYou, style: t.labelMedium),
            const SizedBox(height: Space.xs),
            QuietTags([
              for (final x in matched)
                if (interestByTag(x) case final o?) QuietTag(context.tr(o.label), icon: o.icon),
            ]),
          ],

          // ── 출처 + 번역 안내 (출처명은 라이선스 허가를 뜻하지 않음) ──
          if (!event.isSample) ...[
            const SizedBox(height: Space.xl),
            Divider(color: p.border, height: 1),
            const SizedBox(height: Space.md),
            if (context.lang != 'ko' && event.title.en != event.title.ko)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 14, color: p.textMuted),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(l10n.aiTranslated, style: t.labelSmall)),
                  ],
                ),
              ),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 14, color: p.textMuted),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(l10n.dataSource(event.sourceName ?? event.source), style: t.labelSmall)),
                if (event.url != null)
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(event.url!), mode: LaunchMode.externalApplication),
                    child: Text(l10n.openSource),
                  ),
              ],
            ),
          ],
        ],
      ),
      // ── 행동 (항상 표시) ──
      bottom: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: l10n.share,
                  onPressed: () => shareEvent(context, event),
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                const SizedBox(width: Space.sm),
                if (event.registerUrl != null || (event.isApplication && event.url != null)) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: event.registerUrl != null && !event.applicationActionable(now) ? null : () => launchUrl(Uri.parse(event.registerUrl ?? event.url!), mode: LaunchMode.externalApplication),
                      child: Text(event.registerUrl == null ? l10n.openSource : event.placeless ? l10n.applyNow : l10n.register),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(flex: 2, child: addButton),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Fri, Nov 20" 또는 "Thu, Nov 19 – Sun, Nov 22".
String _dateRange(BuildContext context, RadarEvent e) {
  final sameDay = DateUtils.isSameDay(e.start, e.end);
  return sameDay ? context.formatDate(e.start) : '${context.formatDate(e.start)} – ${context.formatDate(e.end)}';
}

/// "19:30 – 21:30"(하루) 또는 "10:00 – 18:00 (매일)" 대신 단순한 시간 범위.
String _timeRange(BuildContext context, RadarEvent e) {
  String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${hm(e.start)} – ${hm(e.end)}';
}

Widget? _daysLeft(BuildContext context, DateTime deadline) {
  final now = DateTime.now();
  final left = DateTime(
    deadline.year,
    deadline.month,
    deadline.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (left < 0 || left > 30) return null;
  return Pill(left == 0 ? context.l10n.today : 'D-$left', tone: Tone.accent, dense: true);
}

/// "한눈에" 카드: 줄 사이를 얇은 선으로 구분.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Divider(height: 1, color: p.border),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 사실 하나: 색 아이콘 · 작은 라벨 · 굵은 값 · (선택) 설명 / 추가 정보 / 버튼.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.extra,
    this.trailing,
    this.tone = Tone.neutral,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Widget? extra;
  final Widget? trailing;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final valueColor = switch (tone) {
      Tone.primary => p.primary,
      Tone.accent => p.accent,
      _ => p.text,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, size: 36, tone: tone == Tone.neutral ? Tone.primary : tone),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: t.titleSmall!.copyWith(color: valueColor)),
                if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 1), Text(sub!, style: t.bodySmall)],
                if (extra != null) ...[const SizedBox(height: Space.sm), extra!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
  }
}

/// 행사 포스터. 웹에서 다른 도메인 이미지는 CORS가 없을 수 있다 — HTML <img>로 대체한다.
class _Poster extends StatelessWidget {
  const _Poster(this.url, {required this.event});
  final String? url;
  final RadarEvent event;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        height: url == null ? 140 : 200,
        color: p.surfaceAlt,
        alignment: Alignment.center,
        child: url == null
            ? SizedBox.expand(child: EventCover(category: event.category, seed: event.id, iconSize: 40))
            : Image.network(
          url!,
          fit: BoxFit.contain,
          height: 200,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, _, _) => SizedBox.expand(child: EventCover(category: event.category, seed: event.id, iconSize: 40)),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const Shimmer(child: SkeletonBox(height: 200)),
        ),
      ),
    );
  }
}

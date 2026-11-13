import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calendar_link.dart';
import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/calendar_controller.dart';
import '../../data/plan_travel.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../route/route_panel.dart' show PlaceSearchSheet;
import 'plan_actions.dart';
import 'plan_travel_line.dart';

/// 일정 추가([plan] = null) 또는 수정.
/// - 'local'  → 기기에 저장 (선택: Google 캘린더에도).
/// - 'gcal'   → 변경 사항을 Google 캘린더에 기록.
/// - 'sample' → 저장하면 내 일정이 된다.
Future<void> showPlanEditor(BuildContext context, {Plan? plan, DateTime? day}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true, // 하단 내비게이션이 저장 버튼을 가리지 않게
  builder: (_) => PlanEditorSheet(plan: plan, day: day),
);

class PlanEditorSheet extends ConsumerStatefulWidget {
  const PlanEditorSheet({super.key, this.plan, this.day});

  final Plan? plan;
  final DateTime? day;

  @override
  ConsumerState<PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends ConsumerState<PlanEditorSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.plan?.title ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.plan?.note ?? '');

  late DateTime _startDay;
  late DateTime _endDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  String _locationText = '';
  String _city = '';
  GeoPoint? _location;
  // 이동 방법 (선택)
  String? _travelMode;
  late final TextEditingController _lines = TextEditingController();
  String? _originName;
  GeoPoint? _origin;
  TimeOfDay? _departure;
  late bool _toCalendar;
  bool _saving = false;
  bool _titleError = false;
  String? _error;

  Plan? get _plan => widget.plan;
  bool get _isNew => _plan == null;
  bool get _isCalendarPlan => _plan?.source == 'gcal';

  @override
  void initState() {
    super.initState();
    final p = _plan;
    if (p != null) {
      _allDay = p.isAllDay;
      _startDay = _dateOnly(p.start);
      // 종일 일정의 종료일은 "배타적"으로 저장한다 (Google과 동일).
      _endDay = _dateOnly(_allDay ? p.end.subtract(const Duration(days: 1)) : p.end);
      _startTime = TimeOfDay.fromDateTime(p.start);
      _endTime = TimeOfDay.fromDateTime(p.end);
      _locationText = p.locationText;
      _city = p.city;
      _location = p.location;
    } else {
      // 다음 정시부터 1시간.
      final now = DateTime.now();
      final base = widget.day ?? now;
      final hour = widget.day == null ? (now.hour + 1).clamp(0, 23) : 10;
      _allDay = false;
      _startDay = _dateOnly(base);
      _endDay = _startDay;
      _startTime = TimeOfDay(hour: hour, minute: 0);
      _endTime = TimeOfDay(hour: (hour + 1).clamp(0, 23), minute: hour == 23 ? 59 : 0);
    }
    _toCalendar = _isCalendarPlan || (_isNew && ref.read(calendarProvider).isConnected);
    final travel = p == null ? null : ref.read(planTravelProvider.notifier).lookup(p);
    if (travel != null) {
      _travelMode = travel.mode;
      _lines.text = travel.lines.join(', ');
      _originName = travel.originName;
      _origin = travel.origin;
      if (travel.departure != null) _departure = TimeOfDay.fromDateTime(travel.departure!.toLocal());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _lines.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _start => _allDay
      ? _startDay
      : DateTime(_startDay.year, _startDay.month, _startDay.day, _startTime.hour, _startTime.minute);

  DateTime get _end => _allDay
      ? _endDay.add(const Duration(days: 1))
      : DateTime(_endDay.year, _endDay.month, _endDay.day, _endTime.hour, _endTime.minute);

  bool get _rangeValid => _end.isAfter(_start);

  /// 출발 시각은 시작일 기준. 시작 시각보다 늦으면 전날 출발로 본다(야간 이동).
  DateTime? get _departureAt {
    final d = _departure;
    if (d == null || _allDay) return null;
    var at = DateTime(_startDay.year, _startDay.month, _startDay.day, d.hour, d.minute);
    if (at.isAfter(_start)) at = at.subtract(const Duration(days: 1));
    return at;
  }

  bool get _departureValid {
    final at = _departureAt;
    return at == null || _start.difference(at) <= const Duration(hours: 24);
  }

  PlanTravel? _travelFor(Plan plan) {
    final mode = _travelMode;
    if (mode == null) return null;
    return PlanTravel(
      planId: plan.id,
      fingerprint: PlanTravel.fingerprintOf(plan.title, plan.start),
      mode: mode,
      lines: PlanTravel.parseLines(_lines.text),
      originName: _origin == null ? null : _originName,
      origin: _origin,
      departure: _departureAt,
    );
  }

  // ───────── 선택기 ─────────

  Future<void> _pickDay({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDay : _endDay,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        // 길이를 유지하며 종료 시각도 함께 옮긴다.
        final span = _endDay.difference(_startDay);
        _startDay = picked;
        _endDay = picked.add(span);
      } else {
        _endDay = picked;
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _startTime : _endTime);
    if (picked == null) return;
    setState(() {
      if (start) {
        final before = _start;
        final span = _end.difference(before);
        _startTime = picked;
        // 종료 시각이 시작보다 앞서지 않도록 — 길이를 유지한다.
        final newEnd = _start.add(span.isNegative ? const Duration(hours: 1) : span);
        _endDay = _dateOnly(newEnd);
        _endTime = TimeOfDay.fromDateTime(newEnd);
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickPlace() async {
    final picked = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlaceSearchSheet(),
    );
    if (picked == null) return;
    setState(() {
      _locationText = picked.name;
      _city = picked.address.split(' ').first;
      _location = picked.location;
    });
  }

  Future<void> _pickOrigin() async {
    final picked = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlaceSearchSheet(),
    );
    if (picked == null) return;
    setState(() {
      _originName = picked.name;
      _origin = picked.location;
    });
  }

  Future<void> _pickDeparture() async {
    final initial = _departure ??
        TimeOfDay.fromDateTime(_start.subtract(const Duration(hours: 1)));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() => _departure = picked);
  }

  // ───────── 저장 / 삭제 ─────────

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty;
      _error = null;
    });
    if (title.isEmpty || !_rangeValid || !_departureValid) return;

    final note = _note.text.trim();
    final plan = Plan(
      id: _plan?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      start: _start,
      end: _end,
      locationText: _locationText,
      city: _city,
      location: _location,
      source: _plan?.source ?? 'local',
      note: note.isEmpty ? null : note,
      attendance: _plan?.attendance ?? 'unknown',
    );

    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final plans = ref.read(plansProvider.notifier);
      if (_isCalendarPlan) {
        await ref.read(calendarProvider.notifier).savePlan(plan);
      } else if (_toCalendar) {
        // 캘린더에 새 일정으로 기록되므로 앱 안의 사본은 필요 없다.
        await ref.read(calendarProvider.notifier).savePlan(plan.copyWith(source: 'local'));
        if (_plan?.source == 'local') await plans.removeLocal(plan.id);
      } else {
        await plans.saveLocal(plan);
      }
      // 이동 방법은 기기에만 저장한다 (캘린더 ID가 바뀌어도 제목+시작 시각으로 찾는다).
      await ref.read(planTravelProvider.notifier).save(_travelFor(plan), previousPlanId: _plan?.id);
      navigator.pop();
      Toast.show(l10n.planSaved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.planSaveError(friendlyError(l10n, e));
        });
      }
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final deleted = await deletePlanWithConfirm(context, ref, _plan!);
    if (!mounted) return;
    if (deleted) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
    }
  }


  // ───────── UI ─────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lang = context.lang;
    final cal = ref.watch(calendarProvider);
    final canDelete = _plan != null && _plan!.isEditable;
    final showCalendarToggle = !_isCalendarPlan && cal.isConnected && isGoogleSignInConfigured;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.sm, 0),
            child: Row(
              children: [
                Expanded(child: Text(_isNew ? l10n.planNew : l10n.planEdit, style: t.titleLarge)),
                IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    autofocus: _isNew,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    style: t.titleMedium,
                    decoration: InputDecoration(
                      labelText: l10n.planTitle,
                      hintText: l10n.planTitleHint,
                      errorText: _titleError ? l10n.planTitleRequired : null,
                    ),
                    onChanged: (_) {
                      if (_titleError) setState(() => _titleError = false);
                    },
                  ),
                  const SizedBox(height: Space.lg),

                  // 시간
                  _Group(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 20, color: p.textMuted),
                          const SizedBox(width: Space.md),
                          Expanded(child: Text(l10n.planAllDay, style: t.bodyLarge)),
                          Switch(value: _allDay, onChanged: (v) => setState(() => _allDay = v)),
                        ],
                      ),
                      _TimeRow(
                        label: l10n.planStart,
                        day: DateFormat.MMMEd(lang).format(_startDay),
                        time: _allDay ? null : _startTime.format(context),
                        onDay: () => _pickDay(start: true),
                        onTime: () => _pickTime(start: true),
                      ),
                      _TimeRow(
                        label: l10n.planEnd,
                        day: DateFormat.MMMEd(lang).format(_endDay),
                        time: _allDay ? null : _endTime.format(context),
                        onDay: () => _pickDay(start: false),
                        onTime: () => _pickTime(start: false),
                        error: !_rangeValid,
                      ),
                      if (!_rangeValid)
                        Padding(
                          padding: const EdgeInsets.only(left: 32, bottom: Space.sm),
                          child: Text(l10n.planEndBeforeStart, style: t.bodySmall!.copyWith(color: p.danger)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.md),

                  // 장소
                  _Group(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: _pickPlace,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.sm),
                          child: Row(
                            children: [
                              Icon(Icons.place_outlined, size: 20, color: p.textMuted),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: _locationText.isEmpty
                                    ? Text(l10n.planLocationAdd, style: t.bodyLarge!.copyWith(color: p.primary))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _locationText,
                                            style: t.bodyLarge,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_city.isNotEmpty) Text(_city, style: t.bodySmall),
                                        ],
                                      ),
                              ),
                              if (_locationText.isNotEmpty)
                                IconButton(
                                  tooltip: l10n.planLocationRemove,
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() {
                                    _locationText = '';
                                    _city = '';
                                    _location = null;
                                  }),
                                )
                              else
                                Icon(Icons.chevron_right_rounded, color: p.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),

                  if (!_allDay) ...[
                    _travelSection(context),
                    const SizedBox(height: Space.md),
                  ],

                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.planNote, hintText: l10n.planNoteHint),
                  ),
                  const SizedBox(height: Space.md),

                  // 캘린더
                  if (_isCalendarPlan)
                    _InfoLine(
                      icon: Icons.calendar_month_outlined,
                      text: l10n.planCalendarSynced,
                      action: _plan!.htmlLink == null
                          ? null
                          : TextButton(
                              onPressed: () => openCalendar(htmlLink: _plan!.htmlLink, at: _plan!.start),
                              child: Text(l10n.openInCalendar),
                            ),
                    )
                  else if (showCalendarToggle)
                    _Group(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 20, color: p.textMuted),
                            const SizedBox(width: Space.md),
                            Expanded(child: Text(l10n.planSaveToCalendar, style: t.bodyLarge)),
                            Switch(value: _toCalendar, onChanged: (v) => setState(() => _toCalendar = v)),
                          ],
                        ),
                      ],
                    ),
                  if (_plan?.source == 'sample') ...[
                    const SizedBox(height: Space.sm),
                    _InfoLine(icon: Icons.info_outline_rounded, text: l10n.planSampleHint),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: t.bodySmall!.copyWith(color: p.danger)),
                  ],
                ],
              ),
            ),
          ),

          // 행동 (항상 아래)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
                child: Row(
                  children: [
                    if (canDelete) ...[
                      OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.danger,
                          side: BorderSide(color: p.border),
                          minimumSize: const Size(52, 52),
                          padding: EdgeInsets.zero,
                        ),
                        child: Tooltip(message: l10n.planDelete, child: const Icon(Icons.delete_outline_rounded)),
                      ),
                      const SizedBox(width: Space.md),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving ? AppSpinner(size: 20, color: p.textMuted) : Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── 이동 방법 ─────────

  Widget _travelSection(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mode = _travelMode;
    return _Group(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              Icon(Icons.commute_rounded, size: 20, color: p.textMuted),
              const SizedBox(width: Space.md),
              Expanded(child: Text(l10n.planTravelTitle, style: t.bodyLarge)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32, right: Space.sm, bottom: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.planTravelHint, style: t.bodySmall),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(l10n.planTravelNone),
                    selected: mode == null,
                    onSelected: (_) => setState(() => _travelMode = null),
                  ),
                  for (final m in planTravelModes)
                    ChoiceChip(
                      avatar: Icon(planTravelIcon(m), size: 16),
                      label: Text(planTravelModeLabel(context, m)),
                      selected: mode == m,
                      onSelected: (_) => setState(() => _travelMode = m),
                    ),
                ],
              ),
              if (mode != null) ...[
                const SizedBox(height: Space.md),
                if (mode != 'car')
                  TextField(
                    controller: _lines,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.planTravelLines,
                      hintText: l10n.planTravelLinesHint,
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    InputChip(
                      avatar: const Icon(Icons.trip_origin_rounded, size: 16),
                      label: Text(_originName ?? l10n.planTravelOriginAdd),
                      onPressed: _pickOrigin,
                      onDeleted: _origin == null
                          ? null
                          : () => setState(() {
                              _origin = null;
                              _originName = null;
                            }),
                    ),
                    InputChip(
                      avatar: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text(
                        _departure == null
                            ? l10n.planTravelDepartureAdd
                            : l10n.planTravelDepartAt(_departure!.format(context)),
                      ),
                      onPressed: _pickDeparture,
                      onDeleted: _departure == null ? null : () => setState(() => _departure = null),
                    ),
                  ],
                ),
                if (!_departureValid)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(l10n.planTravelDepartureAfterStart, style: t.bodySmall!.copyWith(color: p.danger)),
                  ),
                if (mode == 'air')
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(l10n.planTravelAirNote, style: t.bodySmall),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 차분한 배경의 그룹 블록.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
    decoration: BoxDecoration(color: context.palette.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.day,
    required this.time,
    required this.onDay,
    required this.onTime,
    this.error = false,
  });

  final String label;
  final String day;
  final String? time;
  final VoidCallback onDay;
  final VoidCallback onTime;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: Space.sm, bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodyMedium),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ValueButton(day, onDay, error: error),
              if (time != null) _ValueButton(time!, onTime, error: error),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueButton extends StatelessWidget {
  const _ValueButton(this.text, this.onTap, {this.error = false});
  final String text;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        side: BorderSide(color: error ? p.danger : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
          child: Text(
            text,
            style: context.textStyles.labelLarge!.copyWith(
              color: error ? p.danger : p.text,
              decoration: error ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 18, color: p.textMuted),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: context.textStyles.bodySmall)),
        ?action,
      ],
    );
  }
}

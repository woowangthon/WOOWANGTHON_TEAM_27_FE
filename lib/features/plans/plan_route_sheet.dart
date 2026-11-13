import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/toast.dart';
import '../../core/errors.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../data/plan_routes.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../route/route_panel.dart' show PlaceSearchSheet;

Future<void> showPlanRouteSheet(
  BuildContext context, {
  required Plan from,
  required Plan to,
  PlanRoute? saved,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true, // 하단 내비게이션이 저장 버튼을 가리지 않게
  builder: (_) => _PlanRouteSheet(from: from, to: to, saved: saved),
);

class _PlanRouteSheet extends ConsumerStatefulWidget {
  const _PlanRouteSheet({required this.from, required this.to, this.saved});
  final Plan from, to;
  final PlanRoute? saved;
  @override
  ConsumerState<_PlanRouteSheet> createState() => _PlanRouteSheetState();
}

class _PlanRouteSheetState extends ConsumerState<_PlanRouteSheet> {
  late Place? _origin = widget.saved == null
      ? _place(widget.from)
      : Place(
          name: widget.saved!.origin,
          address: '',
          location: widget.saved!.originLocation,
        );
  late Place? _destination = widget.saved == null
      ? _place(widget.to)
      : Place(
          name: widget.saved!.destination,
          address: '',
          location: widget.saved!.destinationLocation,
        );
  late DateTime _departure =
      widget.saved?.departure.toLocal() ?? widget.from.end.toLocal();
  // A previously confirmed route can be saved again without another network call.
  late TravelRoute? _result = widget.saved == null
      ? null
      : TravelRoute(
          distanceMeters: 0,
          durationSeconds: widget.saved!.durationSeconds,
          mode: TravelMode.transit,
          transitLines: widget.saved!.lines,
        );
  late String _originName = widget.saved?.origin ?? widget.from.locationText;
  late String _destinationName =
      widget.saved?.destination ?? widget.to.locationText;
  bool _busy = false;
  String? _error;

  Place? _place(Plan p) => p.location == null
      ? null
      : Place(name: p.locationText, address: '', location: p.location!);

  bool get _validDeparture =>
      !_departure.isBefore(widget.from.end) &&
      !_departure.isAfter(widget.to.start);

  Future<void> _pickPlace(bool origin) async {
    final picked = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlaceSearchSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (origin) {
        _origin = picked;
        _originName = picked.name;
      } else {
        _destination = picked;
        _destinationName = picked.name;
      }
      _result = null;
      _error = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (picked == null || !mounted) return;
    final day = widget.from.end.toLocal();
    setState(() {
      _departure = DateTime(
        day.year,
        day.month,
        day.day,
        picked.hour,
        picked.minute,
      );
      _result = null;
      _error = null;
    });
  }

  Future<void> _search() async {
    if (_origin == null || _destination == null || !_validDeparture || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(googleApiProvider)
          .transit(
            _origin!.location,
            _destination!.location,
            departure: _departure,
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(context.l10n, e));
        Toast.show(context.l10n.planRouteError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy || (!remove && (_result == null || !_validDeparture))) return;
    // A sync/edit/account change while the sheet is open must not save an obsolete route.
    final plans = ref.read(plansProvider);
    final currentFrom = plans.where((p) => p.id == widget.from.id).firstOrNull;
    final currentTo = plans.where((p) => p.id == widget.to.id).firstOrNull;
    final ordered = [...plans]..sort((a, b) => a.start.compareTo(b.start));
    final fromIndex = ordered.indexWhere((p) => p.id == widget.from.id);
    final adjacent =
        fromIndex >= 0 &&
        fromIndex + 1 < ordered.length &&
        ordered[fromIndex + 1].id == widget.to.id;
    final route = _result == null
        ? null
        : PlanRoute.fromSearch(
            from: widget.from,
            to: widget.to,
            origin: _originName,
            destination: _destinationName,
            originLocation: _origin!.location,
            destinationLocation: _destination!.location,
            departure: _departure,
            route: _result!,
          );
    if (!remove &&
        (!adjacent ||
            currentFrom == null ||
            currentTo == null ||
            !route!.matches(currentFrom, currentTo))) {
      setState(() => _error = context.l10n.planRouteStale);
      Toast.show(context.l10n.planRouteStale, type: ToastType.warning);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(planRoutesProvider.notifier);
      if (remove) {
        await controller.remove(planRouteKey(widget.from, widget.to));
      } else {
        await controller.save(route!);
      }
      if (mounted) {
        Toast.show(
          remove ? context.l10n.planRouteRemoved : context.l10n.planRouteSaved,
          type: remove ? ToastType.info : ToastType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final msg = friendlyError(context.l10n, e);
        setState(() => _error = msg);
        Toast.show(msg, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous != next && mounted) Navigator.pop(context);
    });
    final p = context.palette, t = context.textStyles;
    final l10n = context.l10n;
    final result = _result;
    final minutes = result == null ? 0 : (result.durationSeconds / 60).ceil();
    final arrival = result == null
        ? null
        : _departure.add(Duration(seconds: result.durationSeconds));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.planRouteAdd, style: t.titleLarge)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(l10n.planRouteAutoLocations, style: t.bodySmall),
              const SizedBox(height: Space.md),
              Container(
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Column(
                  children: [
                    _endpoint(l10n.routeFrom, _originName, true),
                    Divider(
                      height: 1,
                      indent: Space.md,
                      endIndent: Space.md,
                      color: p.border,
                    ),
                    _endpoint(l10n.routeTo, _destinationName, false),
                  ],
                ),
              ),
              if (_origin == null || _destination == null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  l10n.planRouteMissingLocation,
                  style: t.bodySmall!.copyWith(color: p.primary),
                ),
              ],
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.directions_transit_rounded,
                      size: 18,
                      color: p.primary,
                    ),
                    label: Text(l10n.travelTransit),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      '${l10n.planRouteDeparture} ${DateFormat.Hm(context.lang).format(_departure)}',
                    ),
                    onPressed: _busy ? null : _pickTime,
                  ),
                ],
              ),
              if (!_validDeparture) ...[
                const SizedBox(height: Space.sm),
                Text(
                  l10n.planRouteOutsideGap,
                  style: t.bodySmall!.copyWith(color: p.danger),
                ),
              ],
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed:
                    _busy ||
                        _origin == null ||
                        _destination == null ||
                        !_validDeparture
                    ? null
                    : _search,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route_rounded),
                label: Text(_busy ? l10n.searching : l10n.planRouteSearch),
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: t.bodySmall!.copyWith(color: p.danger)),
              ],
              if (result != null) ...[
                const SizedBox(height: Space.md),
                Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: p.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: p.primary,
                            size: 22,
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              l10n.hoursMinutes(minutes ~/ 60, minutes % 60),
                              style: t.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        result.transitLines.isEmpty
                            ? l10n.travelTransit
                            : result.transitLines.join(' → '),
                        style: t.labelLarge,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${l10n.planRouteArrival} ${DateFormat.Hm(context.lang).format(arrival!)}',
                        style: t.bodySmall,
                      ),
                      if (arrival.isAfter(widget.to.start)) ...[
                        const SizedBox(height: Space.sm),
                        Text(
                          l10n.planRouteLate,
                          style: t.bodySmall!.copyWith(color: p.danger),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: _busy || result == null || !_validDeparture
                    ? null
                    : () => _save(),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.planRouteSave),
              ),
              if (widget.saved != null)
                TextButton(
                  onPressed: _busy ? null : () => _save(remove: true),
                  child: Text(
                    l10n.planRouteDelete,
                    style: TextStyle(color: p.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endpoint(String label, String name, bool origin) => ListTile(
    enabled: !_busy,
    leading: Icon(
      origin ? Icons.trip_origin_rounded : Icons.place_outlined,
      color: context.palette.primary,
    ),
    title: Text(label, style: context.textStyles.labelSmall),
    subtitle: Text(
      name.isEmpty ? context.l10n.noLocation : name,
      style: context.textStyles.titleSmall,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.edit_outlined, size: 18),
    onTap: () => _pickPlace(origin),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'package:liferadar_core/liferadar_core.dart';

/// 주어진 장소와 날짜의 날씨: "☀️ 15° / 7° · 구름 없음".
/// 날짜가 10일 예보 범위 밖이면 "~10일 전에 공개".
/// 오류이거나 키가 없으면 아무것도 표시하지 않는다 (주요 UI를 깨지 않음).
class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key, required this.location, required this.date});

  final GeoPoint location;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final style = context.textStyles.bodySmall;
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final daysAhead = day.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (daysAhead < 0) return const SizedBox.shrink();
    if (daysAhead > 9) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_queue_rounded, size: 16, color: p.textMuted),
          const SizedBox(width: 6),
          Text(l10n.weatherLater, style: style),
        ],
      );
    }

    final forecast = ref.watch(forecastProvider(forecastKey(location, context.lang)));
    return forecast.when(
      loading: () => const Shimmer(child: SkeletonBox(width: 140, height: 14)),
      error: (_, _) => const SizedBox.shrink(),
      data: (days) {
        final w = days.where((d) => d.date == day).firstOrNull;
        if (w == null) return const SizedBox.shrink();
        final rain = w.likelyRain;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(weatherIcon(w.type), size: 16, color: rain ? p.info : p.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                [
                  if (w.maxC != null && w.minC != null) '${w.maxC}° / ${w.minC}°',
                  w.condition,
                  if ((w.rainChance ?? 0) >= 30) '${l10n.rainChance} ${w.rainChance}%',
                ].join(' · '),
                style: style?.copyWith(
                  color: rain ? p.info : p.text,
                  fontWeight: rain ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

IconData weatherIcon(String type) {
  if (type.contains('THUNDER')) return Icons.thunderstorm;
  if (type.contains('SNOW')) return Icons.ac_unit;
  if (type.contains('RAIN') || type.contains('SHOWER') || type.contains('DRIZZLE')) return Icons.umbrella;
  if (type.contains('FOG') || type.contains('HAZE')) return Icons.foggy;
  if (type.contains('WIND')) return Icons.air;
  if (type == 'CLEAR' || type.contains('SUNNY')) return Icons.wb_sunny;
  return Icons.cloud;
}

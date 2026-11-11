import 'package:flutter/material.dart';
import 'package:liferadar_core/liferadar_core.dart';
import '../../core/l10n_ext.dart';
import '../../core/widgets.dart';

/// Labels are localized; the source's Korean title/evidence is preserved verbatim.
class TrafficMetadata extends StatelessWidget {
  const TrafficMetadata(this.notice, {super.key, this.detailed = false});
  final TrafficNotice notice;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final n = notice;
    String label(String ko, String en) => context.tr(LocalizedText(ko: ko, en: en));
    String at(DateTime value) {
      final k = trafficKst(value);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${k.year}-${two(k.month)}-${two(k.day)} ${two(k.hour)}:${two(k.minute)} KST';
    }

    final observed = n.lastSeenAt ?? n.fetchedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaRow(
          Icons.schedule_outlined,
          '${label('통제 시간', 'Notice period')}: ${n.timePrecision == 'minute' ? at(n.start) : at(n.start).split(' ').first} – ${n.end == null ? label('종료 시각 미확인', 'End time unknown') : at(n.end!)}',
        ),
        MetaRow(
          Icons.place_outlined,
          '${label('공지 위치', 'Notice location')}: ${n.locationText ?? n.roadName ?? label('지도에서 확인', 'Check on map')}',
        ),
        Text('${label('출처', 'Source')}: ${n.sourceName}'),
        Text('${label('마지막 확인', 'Last checked')}: ${observed == null ? label('확인 시각 없음', 'Unknown') : at(observed)}'),
        if (n.source == 'utic' && n.staleAt(DateTime.now().toUtc()))
          Text(label('이전 정보 · 최신 상태 확인 필요', 'Older information · check current status')),
        if (detailed) ...[
          if (n.sourceUpdatedAt != null) Text('${label('원문 갱신', 'Source updated')}: ${at(n.sourceUpdatedAt!)}'),
          if (n.fetchedAt != null) Text('${label('우리 수집 시각', 'Fetched by us')}: ${at(n.fetchedAt!)}'),
          Text(n.detail),
          if (n.evidenceText != null) Text('${label('통제 근거', 'Control evidence')}: ${n.evidenceText}'),
          for (final e in n.evidenceRefs)
            Text('${e['sourceName'] ?? e['source']} · ${e['sourceRecordId'] ?? e['id']} · ${e['lastSeenAt'] ?? ''}'),
          if (n.sourceUrlKind != 'record')
            Text(label('출처 센터 링크입니다. 개별 원문 링크가 아닙니다.', 'This opens the source center, not an individual notice.')),
        ],
      ],
    );
  }
}

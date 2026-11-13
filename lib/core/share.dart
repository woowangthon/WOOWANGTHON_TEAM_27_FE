import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liferadar_core/liferadar_core.dart';
import 'package:share_plus/share_plus.dart';

import 'l10n_ext.dart';
import 'toast.dart';

/// 행사를 휴대폰 공유 창으로 보낸다 (카카오톡·인스타그램·메시지 …). 앱별 API 연동 없이
/// 기기 공유 기능만 쓴다. 공유 창이 없는 환경(데스크톱 웹 등)에서는 글을 클립보드에 복사한다.
Future<void> shareEvent(BuildContext context, RadarEvent e) async {
  final l10n = context.l10n;
  final sameDay = DateUtils.isSameDay(e.start, e.end);
  final when = e.isApplication && e.deadline != null ? '${l10n.applicationDeadline}: ${context.formatDate(e.applicationDate(e.deadline!))}' : sameDay
      ? context.formatDateTime(e.start)
      : '${context.formatDate(e.start)} – ${context.formatDate(e.end)}';
  final link = e.registerUrl ?? e.url;
  final text = [
    context.tr(e.title),
    '📅 $when',
    if (!e.placeless) '📍 ${e.venue} · ${e.city}',
    ?link,
    '',
    l10n.shareFooter,
  ].join('\n');
  try {
    final r = await SharePlus.instance.share(ShareParams(text: text, subject: context.tr(e.title)));
    if (r.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // 아래에서 복사로 대신한다.
  }
  await Clipboard.setData(ClipboardData(text: text));
  Toast.show(l10n.shareCopied);
}

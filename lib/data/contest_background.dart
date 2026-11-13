import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_feed.dart';
import 'live_events.dart';
import 'weekly_contests.dart';

/// Android JobScheduler persists a small due-check across process death/reboot.
/// Site requests are still controlled by WeeklyContests' seven-day checkpoints.
class ContestBackground {
  static const channel = MethodChannel('liferadar/contest_background');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> register() async {
    if (!supported) return;
    final handle = PluginUtilities.getCallbackHandle(contestBackgroundMain);
    if (handle == null) return;
    final scheduled = await channel.invokeMethod<bool>('configure', {
      'callbackHandle': handle.toRawHandle(),
    });
    if (scheduled != true) {
      throw StateError('Contest background job was not scheduled');
    }
  }

  /// Native process-wide lock prevents foreground and headless Flutter engines
  /// from overwriting each other's SharedPreferences snapshots.
  static Future<EventFeed?> collect(WeeklyContests collector) async {
    if (!supported) return collector.collect(DateTime.now());
    bool acquired;
    try {
      acquired = await channel.invokeMethod<bool>('claim') ?? false;
    } on MissingPluginException {
      return collector.collect(DateTime.now());
    }
    if (!acquired) return null;
    try {
      return await collector.collect(DateTime.now());
    } finally {
      await channel.invokeMethod<void>('release');
    }
  }
}

@pragma('vm:entry-point')
void contestBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var success = false;
  var updated = false;
  var count = 0;
  try {
    final prefs = await SharedPreferences.getInstance();
    final seed = await LiveEvents.initial(prefs);
    final result = await WeeklyContests(
      prefs,
      seed: seed,
    ).collect(DateTime.now());
    updated = result != null;
    count = result?.events.length ?? 0;
    success = true;
  } catch (_) {
    success = false;
  } finally {
    await ContestBackground.channel.invokeMethod<void>('finished', {
      'success': success,
      'updated': updated,
      'count': count,
    });
  }
}

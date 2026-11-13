import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:liferadar_core/liferadar_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_feed.dart';
import '../core/env.dart';

/// App-driven collection: each portal is due independently every seven days.
/// Android reads public pages directly by default; configured HTTPS adapters
/// can replace that path (including web clients restricted by browser CORS).
class WeeklyContests {
  WeeklyContests(
    this.prefs, {
    http.Client? client,
    Map<String, String>? endpoints,
    this.seed = EventFeed.empty,
    bool? directEnabled,
    this.directCollector,
  }) : _client = client,
       directEnabled =
           directEnabled ??
           (endpoints == null &&
               !kIsWeb &&
               const bool.fromEnvironment(
                 'CONTEST_DIRECT_ENABLED',
                 defaultValue: true,
               )),
       endpoints = endpoints ?? configuredEndpoints;
  final SharedPreferences prefs;
  final http.Client? _client;
  final Map<String, String> endpoints;
  final EventFeed seed;
  final bool directEnabled;
  final PublicContestCollector? directCollector;
  static const interval = Duration(days: 7);
  static const retryInterval = Duration(hours: 6);
  static const cacheKey = 'weekly_contests_feed_v1';
  static const configuredEndpoints = {
    'contest-linkareer': String.fromEnvironment('CONTEST_LINKAREER_URL'),
    'contest-thinkgood': String.fromEnvironment('CONTEST_THINKGOOD_URL'),
    'contest-allforyoung': String.fromEnvironment('CONTEST_ALLFORYOUNG_URL'),
  };
  Future<EventFeed?>? _running;

  EventFeed? cached() {
    try {
      final raw = prefs.getString(cacheKey);
      return raw == null ? null : EventFeed.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<EventFeed?> collect(DateTime now) =>
      _running ??= _collect(now).whenComplete(() => _running = null);

  bool _due(String key, DateTime now, Duration age) {
    final last = DateTime.tryParse(prefs.getString(key) ?? '');
    return last == null || now.toUtc().difference(last.toUtc()) >= age;
  }

  Future<EventFeed?> _collect(DateTime now) async {
    await prefs.reload();
    var feed =
        cached() ??
        EventFeed(
          events: seed.events.where((e) => e.isApplication).toList(),
          sourceMetadata: seed.sourceMetadata
              .where(
                (m) =>
                    '${m['id']}'.startsWith('contest-') ||
                    m['id'] == 'sotong-contest',
              )
              .toList(),
          sources: seed.sources,
          generatedAt: seed.generatedAt,
        );
    var changed = false;
    final client = _client ?? http.Client();
    final geo = KakaoContestGeocoder(client, Env.kakaoRestApiKey);
    final direct =
        directCollector ?? PublicContestCollector(client, geocode: geo.call);
    try {
      for (final entry in endpoints.entries) {
        final source = entry.key;
        final uri = Uri.tryParse(entry.value);
        if (!configuredEndpoints.containsKey(source) ||
            (entry.value.isEmpty
                ? !directEnabled
                : (uri == null || uri.scheme != 'https' || uri.host.isEmpty))) {
          continue;
        }
        final successKey = 'weekly_contests:$source:success';
        final attemptKey = 'weekly_contests:$source:attempt';
        if (!_due(successKey, now, interval) ||
            !_due(attemptKey, now, retryInterval)) {
          continue;
        }
        await prefs.setString(attemptKey, now.toUtc().toIso8601String());
        try {
          if (entry.value.isEmpty) {
            final reviewKey = 'weekly_contests:$source:checked_urls';
            final reviews =
                (jsonDecode(prefs.getString(reviewKey) ?? '{}') as Map)
                    .cast<String, dynamic>();
            final recent = reviews.entries
                .where((e) {
                  final date = DateTime.tryParse('${e.value}');
                  return date != null &&
                      now.toUtc().difference(date.toUtc()) <
                          const Duration(days: 7);
                })
                .map((e) => e.key)
                .toSet();
            final report = await direct.collect(
              source,
              now,
              previous: feed.events,
              recentChecks: recent,
            );
            final events = [
              ...feed.events.where(
                (e) =>
                    !(e.source == source &&
                        report.replacedUrls.contains(e.url)),
              ),
              ...report.events.where((e) => e.applicationVisible(now)),
            ];
            final meta = {
              'id': source,
              'name': PublicContestParser.sourceNames[source],
              'status': report.complete ? 'success' : 'partial',
              'coverage': 'incremental-public-pages',
              'cacheSnapshot': true,
              'snapshotAt': now.toUtc().toIso8601String(),
              'collectionStatus': report.complete ? 'success' : 'partial',
              'count': events.where((e) => e.source == source).length,
              'verifiedAt': report.complete
                  ? now.toUtc().toIso8601String()
                  : feed.sourceMetadata
                        .where((m) => m['id'] == source)
                        .firstOrNull?['verifiedAt'],
              'issues': report.issues,
              'reviewCount': report.reviewedUrls.length,
            };
            final candidate = EventFeed(
              generatedAt: now.toUtc(),
              events: events,
              sourceMetadata: [
                ...feed.sourceMetadata.where((m) => m['id'] != source),
                meta,
              ],
              sources: {
                ...feed.sources,
                PublicContestParser.sourceNames[source]!,
              }.toList(),
            );
            if (!await prefs.setString(
              cacheKey,
              jsonEncode(candidate.toJson()),
            )) {
              continue;
            }
            feed = candidate;
            changed = true;
            for (final url in {
              ...report.reviewedUrls,
              ...report.replacedUrls,
            }) {
              reviews[url] = now.toUtc().toIso8601String();
            }
            reviews.removeWhere(
              (k, v) =>
                  !recent.contains(k) &&
                  !report.reviewedUrls.contains(k) &&
                  !report.replacedUrls.contains(k),
            );
            await prefs.setString(reviewKey, jsonEncode(reviews));
            if (report.complete) {
              await prefs.setString(successKey, now.toUtc().toIso8601String());
            }
            continue;
          }
          // The adapter performs collection or serves a verified recent cache.
          // No API key, login credential, or arbitrary target URL is sent.
          final response = await client
              .post(uri!, headers: {'accept': 'application/json'})
              .timeout(const Duration(seconds: 25));
          if (response.statusCode != 200 ||
              response.bodyBytes.length > 5 * 1024 * 1024) {
            continue;
          }
          final data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          final metadata = (data['sources'] as List)
              .cast<Map<String, dynamic>>();
          final meta = metadata.single;
          final verified = DateTime.parse(meta['verifiedAt'] as String).toUtc();
          if (meta['id'] != source ||
              meta['status'] != 'success' ||
              meta['coverage'] != 'complete' ||
              verified.isAfter(now.toUtc()) ||
              now.toUtc().difference(verified) > const Duration(days: 1)) {
            continue;
          }
          final rawEvents = (data['events'] as List)
              .cast<Map<String, dynamic>>();
          final events = <RadarEvent>[];
          for (final raw in rawEvents) {
            final e = RadarEvent.fromJson({
              ...raw,
              'verificationTtlHours': 192,
            });
            final checked = e.lastVerifiedAt;
            if (e.source != source ||
                !e.id.startsWith('$source-') ||
                !e.isApplication ||
                e.deadline == null ||
                checked == null ||
                !checked.isUtc ||
                checked.isAfter(now.toUtc()) ||
                now.toUtc().difference(checked) > const Duration(days: 1) ||
                e.eligibilityText?.isNotEmpty != true ||
                e.url == null ||
                Uri.tryParse(e.url!)?.scheme != 'https' ||
                (!e.placeless &&
                    (e.applicationStart == null ||
                        e.venue.isEmpty ||
                        !e.location.lat.isFinite ||
                        !e.location.lng.isFinite ||
                        e.location.lat < 33 ||
                        e.location.lat > 39 ||
                        e.location.lng < 124 ||
                        e.location.lng > 132 ||
                        e.end.isBefore(e.start)))) {
              throw FormatException('Invalid normalized contest record');
            }
            events.add(e);
          }
          if (events.map((e) => e.id).toSet().length != events.length ||
              meta['count'] != events.length) {
            continue;
          }
          final candidate = EventFeed(
            generatedAt: now.toUtc(),
            events: [
              ...feed.events.where((e) => e.source != source),
              ...events,
            ],
            sourceMetadata: [
              ...feed.sourceMetadata.where((s) => s['id'] != source),
              meta,
            ],
            sources: {...feed.sources, meta['name'] as String}.toList(),
          );
          // Store snapshot first. Never postpone a week after a failed parse/save.
          if (!await prefs.setString(
            cacheKey,
            jsonEncode(candidate.toJson()),
          )) {
            continue;
          }
          feed = candidate;
          await prefs.setString(successKey, now.toUtc().toIso8601String());
          changed = true;
        } catch (error) {
          // Independent source failure: keep its previous verified snapshot.
          await prefs.setString(
            'weekly_contests:$source:last_error',
            jsonEncode({
              'at': now.toUtc().toIso8601String(),
              'type': error.runtimeType.toString(),
            }),
          );
        }
      }
    } finally {
      if (_client == null) client.close();
    }
    return changed ? feed : null;
  }
}

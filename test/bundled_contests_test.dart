import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferadar/data/event_feed.dart';
import 'package:liferadar/data/live_events.dart';
import 'package:liferadar_core/demo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedBundle extends CachingAssetBundle {
  FeedBundle(this.base, this.contests);
  final String base;
  final String contests;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(
    key == EventFeed.contestsAsset ? contests : base,
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String base(String at, {bool declaresContests = false}) => jsonEncode({
    'generatedAt': at,
    'sources': [if (declaresContests) {'id': 'sotong-contest', 'name': '소통24 공모전', 'count': 0}],
    'events': [for (var i = 0; i < 20; i++) {...sampleEvents.first.toJson(), 'id': 'base-$i'}],
  });

  test('APK retains reviewed contests and validates any added API competitions', () async {
    final feed = await EventFeed.load();
    final contests = feed.events.where((e) => e.source == 'sotong-contest').toList();
    expect(feed.isUsable, isTrue);
    expect(contests, hasLength(14));
    final all = feed.events.where((e) => e.isApplication).toList();
    expect(all.length, greaterThanOrEqualTo(17));
    expect(all.map((e) => e.source).toSet().length, greaterThanOrEqualTo(4));
    expect(all.every((e) => e.placeless && e.lastVerifiedAt != null && e.deadlinePrecision != null), isTrue);
    expect(all.every((e) => e.isFree == null), isTrue);
    expect(contests.every((e) => e.placeless && e.lastVerifiedAt != null), isTrue);
    expect(contests.any((e) => e.title.ko.contains('캐릭터')), isTrue);
  });

  test('newer legacy cache and network refresh retain bundled contest source', () async {
    final snapshot = await rootBundle.loadString(EventFeed.contestsAsset);
    final expected = 20 + EventFeed.parse(snapshot).events.length;
    SharedPreferences.setMockInitialValues({LiveEvents.prefsKey: base('2026-11-13T00:00:00Z')});
    final prefs = await SharedPreferences.getInstance();
    final feed = await LiveEvents.initial(prefs, bundle: FeedBundle(base('2026-11-10T00:00:00Z'), snapshot));
    expect(feed.events, hasLength(expected));
    final fresh = await LiveEvents.fetch(prefs, feed, url: 'https://example.test/events.json',
      client: MockClient((_) async => http.Response.bytes(utf8.encode(base('2026-11-14T00:00:00Z')), 200)));
    expect(fresh!.events, hasLength(expected));
    expect(EventFeed.parse(prefs.getString(LiveEvents.prefsKey)!).events.where((e) => e.source == 'sotong-contest'), hasLength(14));
    expect(fresh.withMissingContestSourceFrom(feed).events, hasLength(expected));
  });

  test('explicit authoritative empty contest source supersedes bundled snapshot', () async {
    final old = await EventFeed.load();
    final authoritative = EventFeed.parse(base('2026-11-14T00:00:00Z', declaresContests: true));
    final merged = authoritative.withMissingContestSourceFrom(old);
    expect(merged.events.where((e) => e.source == 'sotong-contest'), isEmpty);
    expect(merged.events.length, 20 + old.events.where((e)=>e.isApplication && e.source!='sotong-contest').length);
  });

  test('new APK source snapshot replaces cached three even with newer global cache', () async {
    final bundle = await EventFeed.load();
    final cached = EventFeed.parse(jsonEncode({
      'generatedAt': '2026-11-13T00:00:00Z',
      'sources': [{'id': 'sotong-contest', 'name': '소통24 공모전', 'verifiedAt': '2026-11-12T02:45:00Z'}],
      'events': bundle.events.where((e) => !e.isApplication).map((e) => e.toJson()).toList()
        ..addAll(bundle.events.where((e) => e.source == 'sotong-contest').take(3).map((e) => e.toJson())),
    }));
    final merged = cached.withMissingContestSourceFrom(bundle);
    expect(merged.events.where((e) => e.isApplication).length, bundle.events.where((e)=>e.isApplication).length);
    expect(merged.events.map((e) => e.id).toSet().length, merged.events.length);
    expect(merged.withMissingContestSourceFrom(bundle).events.length, merged.events.length);
  });

  test('removed K-Startup API stays absent from legacy cache and remote refresh', () async {
    final template=(await EventFeed.load()).events.firstWhere((e)=>e.isApplication).toJson();
    String legacy(String at) => jsonEncode({
      'generatedAt':at,
      'sources':[{'id':'kstartup','name':'old startup API'},{'id':'contest-kstartup','name':'old contest API'}],
      'events':[
        for(var i=0;i<20;i++) {...sampleEvents.first.toJson(),'id':'base-$i'},
        for(final source in ['kstartup','contest-kstartup']) {...template,'id':'kstartup-$source','source':source},
      ],
    });
    final parsed=EventFeed.parse(legacy('2026-11-13T00:00:00Z'));
    expect(parsed.events,hasLength(20)); expect(parsed.sourceMetadata,isEmpty);
    SharedPreferences.setMockInitialValues({LiveEvents.prefsKey:legacy('2026-11-13T00:00:00Z')});
    final prefs=await SharedPreferences.getInstance();
    final current=await LiveEvents.initial(prefs);
    expect(current.events.any((e)=>e.id.startsWith('kstartup-')),isFalse);
    final fresh=await LiveEvents.fetch(prefs,current,url:'https://example.test/events.json',
      client:MockClient((_)async=>http.Response.bytes(utf8.encode(legacy('2026-11-14T00:00:00Z')),200)));
    expect(fresh,isNotNull);
    expect(fresh!.events.any((e)=>e.id.startsWith('kstartup-')),isFalse);
    expect(fresh.events.where((e)=>e.isApplication),hasLength(17));
    expect(EventFeed.parse(prefs.getString(LiveEvents.prefsKey)!).events.any((e)=>e.source.contains('kstartup')),isFalse);
  });
}

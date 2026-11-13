package com.liferadar.weeklyprobe;

import android.app.Instrumentation;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/** Separate, same-certificate instrumentation APK. Never shipped in the app. */
public final class WeeklyProbe extends Instrumentation {
    private boolean makeDue;
    private boolean expireVenue;
    private static final String EXPIRED = "2000-01-01T00:00:00.000Z";
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        makeDue = arguments != null && "make_due".equals(arguments.getString("mode"));
        expireVenue = arguments != null && "true".equals(arguments.getString("expireVenue"));
        start();
    }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            Context context = getTargetContext();
            SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            SharedPreferences backup = context.getSharedPreferences("liferadar_weekly_probe_backup", Context.MODE_PRIVATE);
            String raw = prefs.getString("flutter.weekly_contests_feed_v1", "{}");
            JSONObject cache = new JSONObject(raw);
            JSONArray events = cache.optJSONArray("events");
            if (events != null && makeDue && expireVenue) {
                SharedPreferences.Editor saved = backup.edit();
                int expired = 0;
                for (int i = 0; i < events.length(); i++) {
                    JSONObject event = events.getJSONObject(i);
                    if ("https://linkareer.com/activity/363236".equals(event.optString("url"))) {
                        saved.putString(event.getString("id"), event.optString("lastVerifiedAt"));
                        event.put("lastVerifiedAt", EXPIRED); expired++;
                    }
                }
                if (!saved.commit() || !prefs.edit().putString("flutter.weekly_contests_feed_v1", cache.toString()).commit())
                    throw new IllegalStateException("Venue test checkpoint update failed");
                result.putInt("venueSessionsExpiredForTest", expired);
            } else if (events != null && !makeDue && !backup.getAll().isEmpty()) {
                int restored = 0;
                for (int i = 0; i < events.length(); i++) {
                    JSONObject event = events.getJSONObject(i);
                    String original = backup.getString(event.optString("id"), null);
                    if (original != null && EXPIRED.equals(event.optString("lastVerifiedAt"))) {
                        event.put("lastVerifiedAt", original); restored++;
                    }
                }
                if (!prefs.edit().putString("flutter.weekly_contests_feed_v1", cache.toString()).commit())
                    throw new IllegalStateException("Venue test checkpoint restore failed");
                backup.edit().clear().commit();
                result.putInt("unrefreshedTestTimestampsRestored", restored);
            }
            if (makeDue) {
                SharedPreferences.Editor edit = prefs.edit();
                int changed = 0;
                for (String key : prefs.getAll().keySet()) {
                    if (key.startsWith("flutter.weekly_contests:") &&
                            (key.endsWith(":success") || key.endsWith(":attempt") || key.endsWith(":checked_urls"))) {
                        edit.remove(key); changed++;
                    }
                }
                if (!edit.commit()) throw new IllegalStateException("Checkpoint update failed");
                result.putInt("checkpointsReset", changed);
            }
            int mapped = 0;
            int refreshedVenue = 0;
            JSONObject counts = new JSONObject();
            if (events != null) for (int i = 0; i < events.length(); i++) {
                JSONObject event = events.getJSONObject(i);
                String source = event.optString("source");
                counts.put(source, counts.optInt(source) + 1);
                if (!event.optBoolean("placeless")) mapped++;
                if (event.optString("id").startsWith("contest-linkareer-363236-") && !EXPIRED.equals(event.optString("lastVerifiedAt"))) refreshedVenue++;
            }
            result.putString("sourceEventCounts", counts.toString());
            result.putInt("mappedSessions", mapped);
            result.putInt("refreshedVenueSessions", refreshedVenue);
            JSONArray sources = cache.optJSONArray("sources");
            if (sources != null) for (int i = 0; i < sources.length(); i++) {
                JSONObject source = sources.getJSONObject(i);
                String id = source.optString("id");
                if (!id.startsWith("contest-")) continue;
                result.putString("state." + id, source.optString("collectionStatus", source.optString("status")));
                result.putString("snapshot." + id, source.optString("snapshotAt", source.optString("verifiedAt")));
            }
            for (Map.Entry<String, ?> entry : prefs.getAll().entrySet()) {
                String key = entry.getKey();
                if (key.startsWith("flutter.weekly_contests:") &&
                        (key.endsWith(":success") || key.endsWith(":attempt") || key.endsWith(":last_error"))) {
                    result.putString(key.substring("flutter.".length()), String.valueOf(entry.getValue()));
                }
            }
            // Android may stop the target when instrumentation starts. Restore
            // only this app's previously configured periodic job if necessary.
            long callback = context.getSharedPreferences("liferadar_contest_scheduler", Context.MODE_PRIVATE)
                    .getLong("callback", -1);
            JobScheduler scheduler = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
            JobInfo job = scheduler.getPendingJob(270713);
            if (job == null && callback >= 0) {
                job = new JobInfo.Builder(270713, new ComponentName(context,
                        "com.liferadar.liferadar.ContestCollectionJob"))
                        .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPersisted(true)
                        .setPeriodic(TimeUnit.HOURS.toMillis(6), TimeUnit.HOURS.toMillis(1)).build();
                result.putBoolean("jobRestored", scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS);
            }
            result.putBoolean("jobRegistered", scheduler.getPendingJob(270713) != null);
            finish(-1, result);
        } catch (Exception error) {
            result.putString("error", error.getClass().getSimpleName() + ": " + error.getMessage());
            finish(0, result);
        }
    }
}

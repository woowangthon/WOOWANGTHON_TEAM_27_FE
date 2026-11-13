package com.liferadar.trafficprobe;

import android.app.Instrumentation;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;
import org.json.JSONArray;

/** Same-certificate test APK. Reads only our app's settings and test alerts. */
public final class TrafficProbe extends Instrumentation {
    private boolean cleanup;
    @Override public void onCreate(Bundle args) {
        super.onCreate(args);
        cleanup = args != null && "cleanup".equals(args.getString("mode"));
        start();
    }
    @Override public void onStart() {
        Bundle out = new Bundle();
        try {
            Context c = getTargetContext();
            NotificationManager manager = (NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
            out.putBoolean("appPreferenceEnabled", c.getSharedPreferences("FlutterSharedPreferences", 0).getBoolean("flutter.notify_enabled", false));
            out.putBoolean("osNotificationsEnabled", manager.areNotificationsEnabled());
            NotificationChannel channel = manager.getNotificationChannel("signals");
            out.putInt("signalsChannelImportance", channel == null ? -1 : channel.getImportance());
            JSONArray titles = new JSONArray();
            for (StatusBarNotification n : manager.getActiveNotifications()) {
                String title = String.valueOf(n.getNotification().extras.getCharSequence(Notification.EXTRA_TITLE));
                if (title.startsWith("[검증용]")) {
                    titles.put(title);
                    if (cleanup) manager.cancel(n.getId());
                }
            }
            out.putInt("verificationNotificationCount", titles.length());
            out.putString("verificationNotificationTitles", titles.toString());
            finish(0, out);
        } catch (Exception e) {
            out.putString("error", e.toString()); finish(1, out);
        }
    }
}

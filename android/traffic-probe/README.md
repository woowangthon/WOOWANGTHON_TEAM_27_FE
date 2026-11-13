# Traffic notification device verification

This separate instrumentation APK inspects only LifeRadar's notification
settings and notifications whose titles start with `[검증용]`. It is never
included in the production app. Sign it with the same certificate as the test
app; the build script defaults to the standard Android debug keystore.

On Windows, set `ANDROID_HOME` and `JAVA_HOME`, then run `./build.ps1` from
this directory. It requires Android platform 36, build-tools 36.1.0 and Python.
The script builds, installs and inspects the probe. Do not run against a
production-signed app with a different certificate.

`tool/verify_traffic_notifications_device.dart` is a separate Flutter diagnostic
entrypoint using isolated in-memory preferences and historical fixtures with
the real notification plugin. It does not change user calendar data or the
phone clock. See `docs/verification/traffic-notifications-20261113.md` for the
recorded checks and current background limitations.

After testing, cancel only test notifications, restore the original app APK,
and uninstall the probe:

```sh
adb shell am instrument -w -e mode cleanup com.liferadar.trafficprobe/.TrafficProbe
adb install -r ORIGINAL_APP.apk
adb uninstall com.liferadar.trafficprobe
adb shell am start -n com.liferadar.liferadar/.MainActivity
```

Instrumentation can terminate the target app process. Start the restored app
after the last inspection, rather than treating that termination as an app crash.

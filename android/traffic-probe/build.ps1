param(
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetTempPath()) 'liferadar-traffic-probe')
)
$ErrorActionPreference = 'Stop'
if (!$AndroidSdk -or !$JavaHome) { throw 'Set ANDROID_HOME and JAVA_HOME, or pass -AndroidSdk and -JavaHome.' }
$sdk = $AndroidSdk
$jdk = Join-Path $JavaHome 'bin'
$bt = "$sdk/build-tools/36.1.0"
$out = $OutputDirectory
$env:JAVA_HOME = $JavaHome
New-Item -ItemType Directory -Force "$out/classes", "$out/dex" | Out-Null
& "$jdk/javac.exe" --release 8 -encoding UTF-8 -classpath "$sdk/platforms/android-36/android.jar" -d "$out/classes" "$PSScriptRoot/TrafficProbe.java"
if ($LASTEXITCODE) { throw 'javac failed' }
& "$jdk/jar.exe" --create --file "$out/classes.jar" -C "$out/classes" .
& "$jdk/java.exe" -cp "$bt/lib/d8.jar" com.android.tools.r8.D8 --lib "$sdk/platforms/android-36/android.jar" --output "$out/dex" "$out/classes.jar"
if ($LASTEXITCODE) { throw 'd8 failed' }
& "$bt/aapt.exe" package -f -M "$PSScriptRoot/AndroidManifest.xml" -I "$sdk/platforms/android-36/android.jar" -F "$out/base.apk"
if ($LASTEXITCODE) { throw 'aapt failed' }
@'
import sys, zipfile
from pathlib import Path
p=Path(sys.argv[1])
with zipfile.ZipFile(p/'base.apk', 'a') as z: z.write(p/'dex/classes.dex', 'classes.dex')
'@ | python - $out
& "$bt/zipalign.exe" -f 4 "$out/base.apk" "$out/aligned.apk"
& "$bt/apksigner.bat" sign --ks (Join-Path $env:USERPROFILE '.android/debug.keystore') --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out "$out/probe.apk" "$out/aligned.apk"
if ($LASTEXITCODE) { throw 'sign failed' }
& "$sdk/platform-tools/adb.exe" install -r "$out/probe.apk"
if ($LASTEXITCODE) { throw 'install failed' }
& "$sdk/platform-tools/adb.exe" shell am instrument -w com.liferadar.trafficprobe/.TrafficProbe

#!/usr/bin/env python3
"""
Passt das von `flutter create` erzeugte Android-Projekt an:
  - Internet-Berechtigung (für Heldenbilder)
  - App-Name "E&P Analyzer"
  - Link-Öffnen für url_launcher (Android 11+)
Autor: FGSeRaser – https://github.com/FGSeRaser
"""
import re
from pathlib import Path

m = Path("android/app/src/main/AndroidManifest.xml")
xml = m.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in xml:
    xml = re.sub(r"(<manifest[^>]*>)",
                 r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', xml, count=1)
# Updates aus der App heraus installieren (Android fragt trotzdem jedes Mal nach)
if "REQUEST_INSTALL_PACKAGES" not in xml:
    xml = re.sub(r"(<manifest[^>]*>)",
                 r'\1\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>', xml, count=1)

xml = re.sub(r'android:label="[^"]*"', 'android:label="E&amp;P Analyzer"', xml, count=1)

link_intent = ('<intent>\n            <action android:name="android.intent.action.VIEW"/>\n'
               '            <data android:scheme="https"/>\n        </intent>')
if 'android:scheme="https"' not in xml:
    if "<queries>" in xml:
        xml = xml.replace("<queries>", "<queries>\n        " + link_intent, 1)
    else:
        xml = xml.replace("</manifest>", "    <queries>\n        " + link_intent + "\n    </queries>\n</manifest>")

m.write_text(xml, encoding="utf-8")
print("AndroidManifest angepasst.")

# ML Kit Texterkennung: optionale Sprachmodelle (Chinesisch, Japanisch …) sind nicht
# eingebunden – R8 soll beim Release-Build nicht darüber stolpern.
# Das Flutter-Gradle-Plugin liest android/app/proguard-rules.pro automatisch ein.
regeln = Path("android/app/proguard-rules.pro")
inhalt = regeln.read_text(encoding="utf-8") if regeln.exists() else ""
if "mlkit" not in inhalt:
    inhalt += """
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.** { *; }
"""
    regeln.write_text(inhalt, encoding="utf-8")
    print("ProGuard-Regeln für ML Kit angelegt.")

# App-Icon (aus tools/icon_bauen.py) in alle Auflösungen kopieren + adaptives Icon für Android 8+
import shutil  # noqa: E402

res = Path("android/app/src/main/res")
quelle = Path("android-icon")
if quelle.exists():
    for ordner in quelle.iterdir():
        if ordner.is_dir():
            ziel = res / ordner.name
            ziel.mkdir(parents=True, exist_ok=True)
            for datei in ordner.iterdir():
                shutil.copy(datei, ziel / datei.name)
    adaptiv = res / "mipmap-anydpi-v26"
    adaptiv.mkdir(parents=True, exist_ok=True)
    xml_icon = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    (adaptiv / "ic_launcher.xml").write_text(xml_icon, encoding="utf-8")
    (adaptiv / "ic_launcher_round.xml").write_text(xml_icon, encoding="utf-8")
    werte = res / "values"
    werte.mkdir(parents=True, exist_ok=True)
    (werte / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#16224E</color>
</resources>
""", encoding="utf-8")
    m = Path("android/app/src/main/AndroidManifest.xml")
    xml = m.read_text(encoding="utf-8")
    if "android:roundIcon" not in xml:
        xml = xml.replace('android:icon="@mipmap/ic_launcher"',
                          'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"', 1)
        m.write_text(xml, encoding="utf-8")
    print("App-Icon eingebaut.")

# Feste Signatur: jede APK mit android-signatur/debug.keystore signieren,
# damit Updates über die installierte App gehen (sonst "App nicht installiert")
kts = Path("android/app/build.gradle.kts")
groovy = Path("android/app/build.gradle")
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "festeSignatur" not in g:
        block = """    signingConfigs {
        create("festeSignatur") {
            storeFile = file("../../android-signatur/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {"""
        g = g.replace("    buildTypes {", block, 1)
        g = g.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("festeSignatur")')
        kts.write_text(g, encoding="utf-8")
    print("Signatur fest eingestellt (build.gradle.kts).")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "festeSignatur" not in g:
        block = """    signingConfigs {
        festeSignatur {
            storeFile file("../../android-signatur/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }

    buildTypes {"""
        g = g.replace("    buildTypes {", block, 1)
        g = g.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.festeSignatur")
        groovy.write_text(g, encoding="utf-8")
    print("Signatur fest eingestellt (build.gradle).")

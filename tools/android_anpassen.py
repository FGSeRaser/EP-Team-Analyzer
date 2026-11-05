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

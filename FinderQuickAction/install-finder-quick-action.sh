#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE="$HOME/Library/Services/Convert with Convertly.workflow"
mkdir -p "$HOME/Library/Services" "$SERVICE/Contents"
cat > "$SERVICE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.thisulzen.convertly.finderquickaction</string>
<key>CFBundleName</key><string>Convert with Convertly</string>
<key>CFBundlePackageType</key><string>WORK</string>
<key>NSServices</key>
<array>
  <dict>
    <key>NSMenuItem</key>
    <dict><key>default</key><string>Convert with Convertly</string></dict>
    <key>NSMessage</key><string>runWorkflowAsService</string>
    <key>NSSendTypes</key><array><string>public.item</string></array>
  </dict>
</array>
</dict></plist>
PLIST
SCRIPT_B64="$(/usr/bin/base64 < "$ROOT/FinderQuickAction/convert-selected-files.sh" | tr -d '\n')"
export SCRIPT_B64
/usr/bin/python3 - "$SERVICE/Contents/document.wflow" <<'PY'
import base64, os, plistlib, sys
script = base64.b64decode(os.environ["SCRIPT_B64"]).decode("utf-8")
action = {
 "action": {
  "AMAccepts":{"Container":"List","Optional":True,"Types":["public.item"]},
  "AMActionVersion":"2.0.3","AMApplication":["Automator"],
  "AMParameterProperties":{"COMMAND_STRING":{"default":""},"CheckedForUserDefaultShell":{"default":False},"inputMethod":{"default":1},"shell":{"default":"/bin/bash"}},
  "AMProvides":{"Container":"List","Types":["com.apple.cocoa.string"]},
  "ActionBundlePath":"/System/Library/Automator/Run Shell Script.action","ActionName":"Run Shell Script",
  "ActionParameters":{"COMMAND_STRING":script,"CheckedForUserDefaultShell":False,"inputMethod":1,"shell":"/bin/bash"}},
 "isViewVisible":True,"location":"300.000000, 200.000000","workflowActionType":"com.apple.RunShellScript"}
workflow={"AMApplicationBuild":"510","AMApplicationVersion":"2.10","AMDocumentVersion":"2","actions":[action],"connectors":[],"workflowMetaData":{"serviceInputTypeIdentifier":"com.apple.Automator.fileSystemObject","serviceOutputTypeIdentifier":"com.apple.Automator.nothing","serviceProcessesInput":True,"workflowTypeIdentifier":"com.apple.Automator.servicesMenu"}}
with open(sys.argv[1],"wb") as f: plistlib.dump(workflow,f,fmt=plistlib.FMT_XML,sort_keys=False)
PY
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
/usr/bin/osascript -e 'display dialog "Convert with Convertly was installed. In Finder, right-click a file and choose Quick Actions → Convert with Convertly." buttons {"OK"} default button "OK" with title "Convertly"'

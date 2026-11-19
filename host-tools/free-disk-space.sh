#!/bin/bash
# Removes large preinstalled tools from a hosted macOS runner that the AOSP
# host build does not need: unselected Xcode versions, simulator runtimes
# and the Android SDK/NDK.
set -uo pipefail

df -h /
selected="$(cd "$(xcode-select -p)/../.." && pwd -P)"
for app in /Applications/Xcode*.app; do
  [ -L "$app" ] && continue
  [ "$(cd "$app" && pwd -P)" = "$selected" ] && continue
  sudo rm -rf "$app"
done
xcrun simctl delete all > /dev/null 2>&1
sudo rm -rf /Library/Developer/CoreSimulator/Profiles/Runtimes \
  /Library/Developer/CoreSimulator/Images \
  /Library/Developer/CoreSimulator/Volumes/* \
  ~/Library/Developer/CoreSimulator \
  ~/Library/Android/sdk \
  ~/hostedtoolcache \
  /Users/runner/.dotnet /usr/local/share/dotnet 2> /dev/null
df -h /

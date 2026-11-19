#!/usr/bin/env bash
# Stops the device. With --logs, prints the tail of the device logs first.
source "$(dirname "$0")/common.sh"

instance="$CF_HOME/cuttlefish/instances/cvd-1"
if [ "${1:-}" = --logs ]; then
  for name in launcher.log kernel.log logcat; do
    file="$instance/logs/$name"
    [ -f "$file" ] || continue
    group "$name"
    # Connection retries can fill the log, so drop them before trimming.
    grep -av 'Failed to connect:' "$file" > "$file.trimmed" || true
    if [ "$(wc -l < "$file.trimmed")" -gt 500 ]; then
      head -n 200 "$file.trimmed"
      echo "[...]"
      tail -n 300 "$file.trimmed"
    else
      cat "$file.trimmed"
    fi
    endgroup
  done
fi

group "Stop Cuttlefish"
adb disconnect "$CF_SERIAL" > /dev/null 2>&1 || true
if [ -x "$CF_HOME/bin/stop_cvd" ] && [ -e "$CF_HOME/.cuttlefish_config.json" ]; then
  if [ "$(host_os)" = linux ]; then
    sudo -u "$USER" env HOME="$CF_HOME" "$CF_HOME/bin/stop_cvd" < /dev/null || true
  else
    HOME="$CF_HOME" "$CF_HOME/bin/stop_cvd" < /dev/null || true
  fi
fi
endgroup

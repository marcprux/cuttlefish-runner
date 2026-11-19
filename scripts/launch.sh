#!/usr/bin/env bash
# Boots the Cuttlefish device and waits until adb reports it as booted.
# Inputs (environment): CF_CPUS, CF_MEMORY_MB, CF_BOOT_TIMEOUT, CF_LAUNCH_ARGS
source "$(dirname "$0")/common.sh"

os="$(host_os)"
timeout="${CF_BOOT_TIMEOUT:-900}"
args=(
  --daemon
  --report_anonymous_usage_stats=n
  --run_adb_connector=false
)
[ -n "${CF_CPUS:-}" ] && args+=(--cpus="$CF_CPUS")
[ -n "${CF_MEMORY_MB:-}" ] && args+=(--memory_mb="$CF_MEMORY_MB")
if [ "$os" = macos ]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/launch-args-macos.sh"
fi
# shellcheck disable=SC2206
[ -n "${CF_LAUNCH_ARGS:-}" ] && args+=($CF_LAUNCH_ARGS)

group "Launch Cuttlefish"
log "launch_cvd ${args[*]}"
cd "$CF_HOME"
if [ "$os" = linux ]; then
  # The group memberships added during setup only apply to new sessions.
  sudo -u "$USER" env HOME="$CF_HOME" PATH="$PATH" "$CF_HOME/bin/launch_cvd" "${args[@]}" < /dev/null &
else
  HOME="$CF_HOME" "$CF_HOME/bin/launch_cvd" "${args[@]}" < /dev/null &
fi
launcher=$!
deadline=$((SECONDS + timeout))
launcher_log="$CF_HOME/cuttlefish/instances/cvd-1/logs/launcher.log"
while kill -0 "$launcher" 2> /dev/null; do
  [ "$SECONDS" -lt "$deadline" ] || die "launch_cvd did not report a booted device within ${timeout}s"
  if grep -aqs 'Stopping all monitored processes due to unexpected exit' "$launcher_log"; then
    die "a Cuttlefish host process exited unexpectedly"
  fi
  sleep 2
done
wait "$launcher" || die "launch_cvd failed"
endgroup

group "Wait for device"
if ! command -v adb > /dev/null; then
  # Fall back to the SDK's platform-tools, then to the adb shipped with the
  # host tools, and expose it to the following steps as well.
  for dir in "${ANDROID_HOME:-}/platform-tools" "${ANDROID_SDK_ROOT:-}/platform-tools" "$CF_HOME/bin"; do
    if [ -x "$dir/adb" ]; then
      export PATH="$dir:$PATH"
      echo "$dir" >> "$GITHUB_PATH"
      break
    fi
  done
  command -v adb > /dev/null || die "adb was not found"
fi
adb start-server
until [ "$(adb -s "$CF_SERIAL" shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do
  [ "$SECONDS" -lt "$deadline" ] || die "device did not finish booting within ${timeout}s"
  adb connect "$CF_SERIAL" > /dev/null 2>&1 || true
  sleep 5
done
adb -s "$CF_SERIAL" shell input keyevent 82 || true
if [ "${CF_DISABLE_ANIMATIONS:-true}" = true ]; then
  for setting in window_animation_scale transition_animation_scale animator_duration_scale; do
    adb -s "$CF_SERIAL" shell settings put global "$setting" 0.0
  done
fi
adb devices -l
log "device $CF_SERIAL is ready (Android $(adb -s "$CF_SERIAL" shell getprop ro.build.version.release | tr -d '\r'), $(adb -s "$CF_SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r'))"
endgroup

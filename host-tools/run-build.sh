#!/bin/bash
# Runs build-cvd-host-package.sh until it finishes or a deadline passes.
# Usage: run-build.sh AOSP_ROOT JOBS DEADLINE
# DEADLINE is in seconds since the epoch. Exits with 0 when the build is
# complete, 75 when it was interrupted at the deadline and can be resumed
# from the out directory, and with the build's status when it failed.
#
# The job log is lost if a hosted runner runs out of memory and drops its
# connection, so when GH_TOKEN is set a progress report is also kept as an
# asset of the build-logs release.
set -uo pipefail

aosp="$1"
jobs="$2"
deadline="$3"
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${RUNNER_TEMP:-/tmp}"
log="$tmp/build.log"
report="$tmp/progress-${GITHUB_RUN_ID:-0}-${STAGE:-0}.txt"
: > "$log"

if [ -n "${GH_TOKEN:-}" ]; then
  gh release view build-logs > /dev/null 2>&1 ||
    gh release create build-logs --prerelease --title build-logs \
      --notes "Progress reports of build-host-tools runs." || true
  (while sleep 300; do
    {
      date -u
      df -h "$aosp" | tail -n 1
      sysctl -n vm.loadavg vm.swapusage
      ps -Ao rss,comm -m | head -n 8
      tail -n 150 "$log" | cut -c 1-400
    } > "$report" 2>&1
    gh release upload build-logs "$report" --clobber > /dev/null 2>&1 || true
  done) &
  reporter=$!
fi

tail -n +1 -f "$log" &
tailer=$!

# The build gets its own process group so that all of it can be interrupted.
env -i HOME="$HOME" USER="$USER" PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=dumb LANG=en_US.UTF-8 \
  /usr/bin/perl -MPOSIX -e 'setpgid(0, 0); exec @ARGV' \
  "$here/build-cvd-host-package.sh" "$aosp" "$jobs" > "$log" 2>&1 &
build=$!

interrupted=0
while kill -0 "$build" 2> /dev/null; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    interrupted=1
    # Not SIGINT, which background jobs of a script ignore.
    kill -TERM -- "-$build" 2> /dev/null
    for _ in $(seq 60); do
      kill -0 "$build" 2> /dev/null || break
      sleep 5
    done
    kill -KILL -- "-$build" 2> /dev/null
    break
  fi
  sleep 15
done
wait "$build"
status=$?

sleep 2
kill "$tailer" ${reporter:+"$reporter"} 2> /dev/null

if [ "$interrupted" = 1 ]; then
  echo "Build interrupted at the deadline"
  exit 75
fi
exit "$status"

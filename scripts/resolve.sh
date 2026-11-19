#!/usr/bin/env bash
# Resolves the build target and build ID and publishes them as step outputs.
# Inputs (environment): INPUT_BRANCH, INPUT_TARGET, INPUT_BUILD_ID
source "$(dirname "$0")/common.sh"

os="$(host_os)"
arch="$(uname -m)"
branch="${INPUT_BRANCH:-aosp-android-latest-release}"
target="${INPUT_TARGET:-}"
build_id="${INPUT_BUILD_ID:-latest}"

if [ -z "$target" ]; then
  case "$os-$arch" in
    linux-x86_64) target=aosp_cf_x86_64_only_phone-userdebug ;;
    linux-aarch64 | macos-arm64) target=aosp_cf_arm64_only_phone-userdebug ;;
    *) die "no default Cuttlefish target for $os on $arch" ;;
  esac
fi

if [ "$build_id" = latest ]; then
  status="$(curl --fail --silent --show-error --retry 5 --retry-all-errors \
    "$CI_ANDROID/branches/$branch/status.json")"
  build_id="$(printf '%s' "$status" | python3 -c '
import json, sys
name = sys.argv[1]
for target in json.load(sys.stdin).get("targets", []):
    if target.get("name") == name:
        print(target.get("last_known_good_build", ""))
        break
' "$target")"
  [ -n "$build_id" ] && [ "$build_id" != 0 ] ||
    die "no successful build of $target found on branch $branch"
fi

log "host: $os/$arch, branch: $branch, target: $target, build: $build_id"
{
  echo "os=$os"
  echo "arch=$arch"
  echo "branch=$branch"
  echo "target=$target"
  echo "build-id=$build_id"
  echo "product=${target%-*}"
  echo "root=$CF_ROOT"
  echo "downloads=$CF_DOWNLOADS"
  echo "serial=$CF_SERIAL"
} >> "$GITHUB_OUTPUT"

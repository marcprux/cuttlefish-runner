# Shared settings for the cuttlefish-runner scripts. Sourced, not executed.
set -euo pipefail

CF_ROOT="${CF_ROOT:-$HOME/.cuttlefish-runner}"
CF_DOWNLOADS="$CF_ROOT/downloads"
CF_HOST="$CF_ROOT/host"
CF_IMAGES="$CF_ROOT/images"
CF_RUN="$CF_ROOT/run"
CF_QEMU="$CF_ROOT/qemu"
CF_ADB_PORT="${CF_ADB_PORT:-6520}"
CF_SERIAL="127.0.0.1:$CF_ADB_PORT"
CI_ANDROID="https://ci.android.com/builds"

log() { echo "[cuttlefish-runner] $*"; }
die() { echo "::error::$*" >&2; exit 1; }
group() { echo "::group::$*"; }
endgroup() { echo "::endgroup::"; }

host_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    *) die "unsupported host OS: $(uname -s)" ;;
  esac
}

# download URL DEST: fetch with retries, writing atomically.
download() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl --fail --location --silent --show-error \
    --retry 5 --retry-delay 5 --retry-all-errors \
    --output "$dest.part" "$url"
  mv "$dest.part" "$dest"
}

# fetch_artifact BRANCH TARGET BUILD_ID NAME DEST: download a build artifact
# from ci.android.com unless it is already present (e.g. restored from cache).
fetch_artifact() {
  local target="$2" build_id="$3" name="$4" dest="$5"
  if [ -s "$dest" ]; then
    log "using cached $name"
    return
  fi
  log "downloading $name from build $build_id ($target)"
  download "$CI_ANDROID/submitted/$build_id/$target/latest/raw/$name" "$dest"
}

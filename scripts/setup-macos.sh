#!/usr/bin/env bash
# Unpacks the macOS Cuttlefish host tools, QEMU and the device images.
# Inputs (environment): CF_BRANCH, CF_TARGET, CF_BUILD_ID, CF_PRODUCT,
#   CF_HOST_TOOLS_REPOSITORY, CF_HOST_TOOLS_RELEASE
source "$(dirname "$0")/common.sh"

[ "$(uname -m)" = arm64 ] || die "the macOS host tools require Apple silicon"

group "Fetch Cuttlefish host tools and images"
release="https://github.com/$CF_HOST_TOOLS_REPOSITORY/releases/download/$CF_HOST_TOOLS_RELEASE"
tools="$CF_DOWNLOADS/$CF_HOST_TOOLS_RELEASE"
for asset in cvd-host_package-darwin.tar.gz qemu-darwin-arm64.tar.gz; do
  if [ -s "$tools/$asset" ]; then
    log "using cached $asset"
  else
    log "downloading $asset from $CF_HOST_TOOLS_REPOSITORY@$CF_HOST_TOOLS_RELEASE"
    download "$release/$asset" "$tools/$asset"
  fi
done

dl="$CF_DOWNLOADS/$CF_TARGET-$CF_BUILD_ID"
img_zip="$CF_PRODUCT-img-$CF_BUILD_ID.zip"
fetch_artifact "$CF_BRANCH" "$CF_TARGET" "$CF_BUILD_ID" "$img_zip" "$dl/$img_zip"

rm -rf "$CF_HOME" "$CF_QEMU" "$CF_QEMU_SHIM"
mkdir -p "$CF_HOME" "$CF_QEMU_SHIM"
tar -xzf "$tools/cvd-host_package-darwin.tar.gz" -C "$CF_HOME"
tar -xzf "$tools/qemu-darwin-arm64.tar.gz" -C "$CF_ROOT"
unzip -q "$dl/$img_zip" -d "$CF_HOME"

# launch_cvd looks for QEMU and qemu-img in a single directory. Everything
# but the system emulator is linked through unchanged.
for tool in "$CF_QEMU"/bin/*; do
  ln -s "$tool" "$CF_QEMU_SHIM/$(basename "$tool")"
done
rm "$CF_QEMU_SHIM/qemu-system-aarch64"
cp "$(dirname "$0")/qemu-shim.sh" "$CF_QEMU_SHIM/qemu-system-aarch64"
chmod +x "$CF_QEMU_SHIM/qemu-system-aarch64"

"$CF_QEMU/bin/qemu-system-aarch64" --version | head -n 1
if [ "$(sysctl -n kern.hv_support 2> /dev/null || echo 0)" = 1 ]; then
  log "Hypervisor.framework is available, the device will run accelerated"
else
  log "Hypervisor.framework is not available, the device will run under software emulation"
fi
df -h "$CF_ROOT"
endgroup

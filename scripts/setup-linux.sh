#!/usr/bin/env bash
# Installs the Cuttlefish host packages and unpacks the host tools and images.
# Inputs (environment): CF_BRANCH, CF_TARGET, CF_BUILD_ID, CF_PRODUCT
source "$(dirname "$0")/common.sh"

[ -e /dev/kvm ] || die "/dev/kvm is not available on this runner"

group "Install Cuttlefish host packages"
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' |
  sudo tee /etc/udev/rules.d/99-kvm4all.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm

sudo curl --fail --silent --show-error --location --retry 5 \
  --output /etc/apt/trusted.gpg.d/artifact-registry.asc \
  https://us-apt.pkg.dev/doc/repo-signing-key.gpg
echo "deb https://us-apt.pkg.dev/projects/android-cuttlefish-artifacts android-cuttlefish main" |
  sudo tee /etc/apt/sources.list.d/android-cuttlefish.list > /dev/null
sudo apt-get update -qq
if ! apt-cache policy libxml2 | grep -q 'Candidate: [0-9]'; then
  # cuttlefish-base depends on "libxml2", which newer Ubuntu releases ship
  # under a versioned name. Only the network setup from the package is used
  # here, so an empty package is enough to satisfy the dependency.
  shim="$(mktemp -d)"
  mkdir -p "$shim/libxml2/DEBIAN"
  cat > "$shim/libxml2/DEBIAN/control" <<CONTROL
Package: libxml2
Version: 2.99-cuttlefish-runner
Architecture: all
Maintainer: cuttlefish-runner
Description: Empty package satisfying the cuttlefish-base dependency
CONTROL
  dpkg-deb --build "$shim/libxml2" "$shim/libxml2.deb" > /dev/null
  sudo dpkg -i "$shim/libxml2.deb" > /dev/null
  rm -rf "$shim"
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends cuttlefish-base
sudo usermod -aG kvm,cvdnetwork,render "$USER"
sudo modprobe -a vhost_vsock vhost_net
sudo systemctl restart cuttlefish-host-resources
ip -brief link show | grep cvd || die "Cuttlefish network interfaces were not created"
endgroup

group "Fetch Cuttlefish host tools and images"
dl="$CF_DOWNLOADS/$CF_TARGET-$CF_BUILD_ID"
img_zip="$CF_PRODUCT-img-$CF_BUILD_ID.zip"
fetch_artifact "$CF_BRANCH" "$CF_TARGET" "$CF_BUILD_ID" cvd-host_package.tar.gz "$dl/cvd-host_package.tar.gz"
fetch_artifact "$CF_BRANCH" "$CF_TARGET" "$CF_BUILD_ID" "$img_zip" "$dl/$img_zip"

rm -rf "$CF_HOST" "$CF_IMAGES" "$CF_RUN"
mkdir -p "$CF_HOST" "$CF_IMAGES" "$CF_RUN"
tar -xzf "$dl/cvd-host_package.tar.gz" -C "$CF_HOST"
unzip -q "$dl/$img_zip" -d "$CF_IMAGES"
df -h "$CF_ROOT"
endgroup

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
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends cuttlefish-base
sudo usermod -aG kvm,cvdnetwork,render "$USER"
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

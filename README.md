# cuttlefish-runner

A GitHub Action that boots an Android [Cuttlefish](https://source.android.com/docs/devices/cuttlefish)
virtual device and runs a script against it, typically instrumented tests.
It works on both `ubuntu-latest` and `macos-latest` runners.

The stock Android emulator cannot start on GitHub's Apple silicon macOS
runners because they are virtual machines without nested virtualization
([android-emulator-runner#350](https://github.com/ReactiveCircus/android-emulator-runner/issues/350)).
On macOS this action runs Cuttlefish on top of QEMU instead, using the macOS
host support that Meta published in
[cuttlefish-wearables](https://github.com/facebookincubator/cuttlefish-wearables)
and [qemu-wearables](https://github.com/facebookincubator/qemu-wearables)
([background](https://engineering.fb.com/2026/11/13/android/cuttlefish-on-mac/)).
QEMU falls back to software emulation when Hypervisor.framework is not
available, which is slow but does not need nested virtualization.

## Usage

```yaml
jobs:
  instrumented-tests:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-java@v6
        with:
          distribution: temurin
          java-version: 21
      - uses: marcprux/cuttlefish-runner@v1
        with:
          script: ./gradlew connectedCheck
```

The script runs with `bash -eo pipefail` once the device has finished booting.
`ANDROID_SERIAL` is set to the device's adb serial and `adb` is on the `PATH`.
The device is stopped when the script ends. If anything fails, the launcher,
kernel and logcat output are printed to the job log.

Building the app before the action starts keeps the device's uptime short,
which matters most on macOS:

```yaml
      - run: ./gradlew assembleDebug assembleDebugAndroidTest
      - uses: marcprux/cuttlefish-runner@v1
        with:
          script: ./gradlew connectedDebugAndroidTest
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `script` | required | Commands to run once the device has booted. |
| `working-directory` | `.` | Directory to run the script in. |
| `branch` | `aosp-android-latest-release` | Android CI branch to take the device images from. |
| `target` | host dependent | Build target. `aosp_cf_x86_64_only_phone-userdebug` on x86_64 Linux, `aosp_cf_arm64_only_phone-userdebug` on arm64. |
| `build-id` | `latest` | Android CI build ID. `latest` resolves to the last known good build of the target. Pin an ID for reproducible runs. |
| `cpus` | | Number of virtual CPUs. |
| `memory-mb` | | Guest memory in megabytes. |
| `boot-timeout` | host dependent | Seconds to wait for the device to boot. |
| `disable-animations` | `true` | Turn off window and transition animations after boot. |
| `launch-args` | | Extra arguments passed to `launch_cvd`. |
| `host-tools-repository` | `marcprux/cuttlefish-runner` | Repository whose releases provide the macOS host tools. |
| `host-tools-release` | `host-tools-1` | Release tag of the macOS host tools. |
| `cache` | `true` | Cache downloaded host tools and device images between runs. |

## Outputs

| Output | Description |
|--------|-------------|
| `serial` | adb serial of the device (`127.0.0.1:6520`). |
| `build-id` | Android CI build ID that was booted. |
| `target` | Build target that was booted. |

## How it works

Device images are downloaded from [ci.android.com](https://ci.android.com).
The downloads are stored with `actions/cache`, keyed on the target and build
ID, so only the first run of a given build has to fetch them.

### Linux

The action installs `cuttlefish-base` from the
[android-cuttlefish](https://github.com/google/android-cuttlefish) package
repository for the host network setup, gives the runner user access to
`/dev/kvm`, and starts the device with the `cvd-host_package` from the same
build as the images. The device runs under crosvm with KVM.

### macOS

The upstream host tools do not build for macOS, and there are no prebuilt
binaries of Meta's port. The [build-host-tools](.github/workflows/build-host-tools.yml)
workflow in this repository builds them on a hosted macOS runner and publishes
them as a release:

- `qemu-darwin-arm64.tar.gz`: QEMU from qemu-wearables, with its library
  dependencies bundled.
- `cvd-host_package-darwin.tar.gz`: the Cuttlefish host package built from
  AOSP `android-16.0.0_r1` with the cuttlefish-wearables patches applied.

The action downloads both, unpacks them next to the device images and starts
the device with `launch_cvd --vm_manager=qemu_cli`. The host tools always
request the HVF accelerator, a Cocoa window and CoreAudio output, so QEMU is
started through a [small wrapper](scripts/qemu-shim.sh) that makes the device
headless and switches to the TCG software emulator when
`sysctl kern.hv_support` reports that Hypervisor.framework is unavailable.
On a Mac where it is available (a self-hosted runner on real hardware, for
example) the device runs accelerated.

## Example project

[example](example) is a minimal Android Gradle project with instrumented
tests. The [ci](.github/workflows/ci.yml) workflow runs those tests through
this action on `ubuntu-latest` and `macos-latest`.

## Release assets

The host tool release assets are built from QEMU (GPL-2.0) and the Android
Open Source Project (Apache-2.0 and others) and remain under their respective
licenses. The exact source commits are recorded in each release.

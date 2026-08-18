#!/usr/bin/env bash
# YKS Level - one-shot macOS / Linux setup.
#
#   Downloads a JDK, the Flutter SDK and the Android command-line tools into
#   one folder, creates an emulator, clones the repo and launches the app.
#   Nothing is installed system-wide: delete $ROOT and every trace is gone.
#
#   Usage:
#     bash tools/setup_and_run.sh            # emulator
#     bash tools/setup_and_run.sh --device   # USB-connected phone instead
#
#   Roughly 4 GB of downloads.
set -euo pipefail

ROOT="${YKS_ROOT:-$HOME/yks-level-dev}"
REPO="https://github.com/melihcanaydemir7-cell/yks-lebel.git"
BRANCH="claude/yks-level-android-mvp-5zpf5w"
FLUTTER_VERSION="3.47.0"
SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"
USE_EMULATOR=1
[[ "${1:-}" == "--device" ]] && USE_EMULATOR=0

case "$(uname -s)" in
  Darwin) OS=mac;   CMDLINE_TOOLS=commandlinetools-mac-11076708_latest.zip ;;
  Linux)  OS=linux; CMDLINE_TOOLS=commandlinetools-linux-11076708_latest.zip ;;
  *) echo "Unsupported OS. On Windows use tools/setup_and_run.ps1"; exit 1 ;;
esac
ARCH="$(uname -m)"
if [[ "$OS" == "mac" && "$ARCH" == "arm64" ]]; then
  FLUTTER_ARCHIVE="flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
  JDK_ARCH="aarch64"
elif [[ "$OS" == "mac" ]]; then
  FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-stable.zip"
  JDK_ARCH="x64"
else
  FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  JDK_ARCH="x64"
fi

step() { printf '\n==> %s\n' "$1"; }

mkdir -p "$ROOT" && cd "$ROOT"

step "JDK 17 (needed by the Android tools)"
if [[ ! -d "$ROOT/jdk" ]]; then
  mkdir -p "$ROOT/jdk"
  curl -fsSL "https://api.adoptium.net/v3/binary/latest/17/ga/${OS}/${JDK_ARCH}/jdk/hotspot/normal/eclipse?project=jdk" \
    | tar xz -C "$ROOT/jdk" --strip-components=1
fi
export JAVA_HOME="$ROOT/jdk"
[[ "$OS" == "mac" && -d "$JAVA_HOME/Contents/Home" ]] && JAVA_HOME="$JAVA_HOME/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

step "Flutter SDK $FLUTTER_VERSION"
if [[ ! -d "$ROOT/flutter" ]]; then
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/${OS}/${FLUTTER_ARCHIVE}"
  if [[ "$FLUTTER_ARCHIVE" == *.tar.xz ]]; then
    curl -fsSL "$URL" | tar xJ -C "$ROOT"
  else
    curl -fsSL -o /tmp/flutter.zip "$URL" && unzip -q /tmp/flutter.zip -d "$ROOT" && rm /tmp/flutter.zip
  fi
fi
export PATH="$ROOT/flutter/bin:$PATH"
git config --global --add safe.directory "$ROOT/flutter" 2>/dev/null || true

step "Android SDK command-line tools"
SDK="$ROOT/android-sdk"
if [[ ! -d "$SDK/cmdline-tools/latest" ]]; then
  mkdir -p "$SDK/cmdline-tools"
  curl -fsSL -o /tmp/cmdline.zip "https://dl.google.com/android/repository/${CMDLINE_TOOLS}"
  unzip -q /tmp/cmdline.zip -d "$SDK/cmdline-tools"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm /tmp/cmdline.zip
fi
export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:$SDK/emulator:$PATH"

step "Accepting SDK licences"
yes | sdkmanager --licenses >/dev/null 2>&1 || true

step "Installing Android SDK components (this is the slow part)"
# The exact platform + build-tools this Flutter version needs are left for
# Gradle to auto-download on the first build, now that every licence has been
# accepted -- that avoids hardcoding a platform number that may not exist yet.
PACKAGES=(platform-tools)
(( USE_EMULATOR )) && PACKAGES+=(emulator "$SYSTEM_IMAGE")
sdkmanager "${PACKAGES[@]}" >/dev/null

if (( USE_EMULATOR )) && [[ ! -x "$SDK/emulator/emulator" ]]; then
  echo "error: emulator package reported success but $SDK/emulator/emulator is still missing." >&2
  echo "       re-run this script, or pass --device to use a USB-connected phone instead." >&2
  exit 1
fi

flutter config --android-sdk "$SDK" >/dev/null

step "Cloning the project"
[[ -d "$ROOT/yks-level" ]] || git clone --branch "$BRANCH" "$REPO" "$ROOT/yks-level"
cd "$ROOT/yks-level"
git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull --ff-only origin "$BRANCH"

step "Installing packages"
flutter pub get

if (( USE_EMULATOR )); then
  step "Creating and starting the emulator"
  avdmanager list avd | grep -q yks_level || \
    echo no | avdmanager create avd -n yks_level -k "$SYSTEM_IMAGE" -d pixel_7
  "$SDK/emulator/emulator" -avd yks_level >/dev/null 2>&1 &
  echo "    waiting for the emulator to boot..."
  adb wait-for-device
  until [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do sleep 2; done
fi

step "Launching YKS Level"
echo "    press r to hot reload, R to restart, q to quit"
flutter run

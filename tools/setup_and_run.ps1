# YKS Level - one-shot Windows setup.
#
#   Downloads a JDK, the Flutter SDK and the Android command-line tools into
#   one folder, creates an emulator, clones the repo and launches the app.
#   Nothing is installed system-wide and nothing else on your PC is touched:
#   delete $Root when you are done and every trace is gone.
#
#   Usage (PowerShell, no admin needed):
#     powershell -ExecutionPolicy Bypass -File tools\setup_and_run.ps1
#
#   Roughly 4 GB of downloads. Add -Device to skip the emulator and run on a
#   USB-connected phone instead.

param(
  [string]$Root   = "$env:USERPROFILE\yks-level-dev",
  [string]$Repo   = "https://github.com/melihcanaydemir7-cell/yks-lebel.git",
  [string]$Branch = "claude/yks-level-android-mvp-5zpf5w",
  [switch]$Device
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # 10x faster Invoke-WebRequest

$FlutterVersion = '3.47.0'
$CmdlineTools   = 'commandlinetools-win-11076708_latest.zip'
$SystemImage    = 'system-images;android-35;google_apis;x86_64'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Get-Archive($url, $zip, $dest) {
  if (Test-Path $dest) { Write-Host "    already present, skipping"; return }
  Write-Host "    downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $zip
  Write-Host "    extracting"
  Expand-Archive -Path $zip -DestinationPath $dest -Force
  Remove-Item $zip
}

New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-Location $Root

# ---------------------------------------------------------------------- JDK
Step "JDK 17 (needed by the Android tools)"
$JdkRoot = "$Root\jdk"
Get-Archive `
  'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk' `
  "$Root\jdk.zip" $JdkRoot
$env:JAVA_HOME = (Get-ChildItem $JdkRoot -Directory | Select-Object -First 1).FullName
$env:PATH      = "$env:JAVA_HOME\bin;$env:PATH"

# ------------------------------------------------------------------ Flutter
Step "Flutter SDK $FlutterVersion"
Get-Archive `
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip" `
  "$Root\flutter.zip" "$Root\flutter-sdk"
$env:PATH = "$Root\flutter-sdk\flutter\bin;$env:PATH"

# -------------------------------------------------------------- Android SDK
Step "Android SDK command-line tools"
$Sdk = "$Root\android-sdk"
if (-not (Test-Path "$Sdk\cmdline-tools\latest")) {
  New-Item -ItemType Directory -Force -Path "$Sdk\cmdline-tools" | Out-Null
  Invoke-WebRequest -Uri "https://dl.google.com/android/repository/$CmdlineTools" `
                    -OutFile "$Root\cmdline.zip"
  Expand-Archive "$Root\cmdline.zip" "$Sdk\cmdline-tools" -Force
  Rename-Item "$Sdk\cmdline-tools\cmdline-tools" "$Sdk\cmdline-tools\latest"
  Remove-Item "$Root\cmdline.zip"
}
$env:ANDROID_HOME     = $Sdk
$env:ANDROID_SDK_ROOT = $Sdk
$env:PATH             = "$Sdk\cmdline-tools\latest\bin;$Sdk\platform-tools;$Sdk\emulator;$env:PATH"

Step "Accepting SDK licences and installing components (this is the slow part)"
cmd /c "echo y| sdkmanager.bat --licenses" | Out-Null
$packages = @('platform-tools', 'platforms;android-36', 'build-tools;36.0.0')
if (-not $Device) { $packages += @('emulator', $SystemImage) }
cmd /c "sdkmanager.bat $($packages -join ' ')"

flutter config --android-sdk $Sdk | Out-Null

# ------------------------------------------------------------------ project
Step "Cloning the project"
if (-not (Test-Path "$Root\yks-level")) {
  git clone --branch $Branch $Repo "$Root\yks-level"
}
Set-Location "$Root\yks-level"
git fetch origin $Branch
git checkout $Branch
git pull --ff-only origin $Branch

Step "Installing packages"
flutter pub get

# ------------------------------------------------------------------- device
if (-not $Device) {
  Step "Creating and starting the emulator"
  if (-not (avdmanager.bat list avd | Select-String 'yks_level')) {
    cmd /c "echo no| avdmanager.bat create avd -n yks_level -k `"$SystemImage`" -d pixel_7"
  }
  Start-Process -FilePath "$Sdk\emulator\emulator.exe" -ArgumentList '-avd', 'yks_level'
  Write-Host "    waiting for the emulator to boot..."
  adb wait-for-device
  do { Start-Sleep 2 } until ((adb shell getprop sys.boot_completed 2>$null) -match '1')
}

Step "Launching YKS Level"
Write-Host "    press r to hot reload, R to restart, q to quit`n"
flutter run

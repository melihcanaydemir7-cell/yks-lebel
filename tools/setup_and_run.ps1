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

Step "Accepting SDK licences"
# sdkmanager prompts once per licence (SDK licence, preview licence, extras
# licence, ...) and treats a closed stdin as declining whatever it hasn't
# asked yet. Piping a single "y" (e.g. via `cmd /c "echo y| ..."`) answers
# only the first prompt, so later packages -- the emulator among them -- fail
# to install without the script noticing. Piping 25 answers covers every
# licence Android currently ships.
1..25 | ForEach-Object { 'y' } | & sdkmanager.bat --licenses *> $null

Step "Installing Android SDK components (this is the slow part)"
# The exact platform + build-tools this Flutter version needs are left for
# Gradle to auto-download on the first build. That only works because every
# licence was just accepted above; it also means this script never has to
# guess a platform number that may not exist yet.
$packages = @('platform-tools')
if (-not $Device) { $packages += @('emulator', $SystemImage) }
foreach ($pkg in $packages) {
  Write-Host "    installing $pkg"
  & sdkmanager.bat $pkg
  if ($LASTEXITCODE -ne 0) {
    throw "sdkmanager failed to install '$pkg' (exit $LASTEXITCODE). Re-run " +
          "this script -- everything already downloaded is skipped, so it " +
          "will only retry this step."
  }
}

if (-not $Device -and -not (Test-Path "$Sdk\emulator\emulator.exe")) {
  throw "The emulator package reported success but $Sdk\emulator\emulator.exe " +
        "is still missing. Re-run this script, or pass -Device to use a " +
        "USB-connected phone instead."
}

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
  $existingAvds = & avdmanager.bat list avd
  if (-not ($existingAvds | Select-String 'yks_level')) {
    Write-Host "    creating the yks_level AVD"
    'no' | & avdmanager.bat create avd -n yks_level -k $SystemImage -d pixel_7
    if ($LASTEXITCODE -ne 0) {
      throw "avdmanager failed to create the emulator (exit $LASTEXITCODE). " +
            "Re-run this script, or pass -Device to use a USB-connected " +
            "phone instead."
    }
  }
  # Start-Process alone is fire-and-forget: if the emulator crashes on launch
  # (missing hardware virtualization is the usual reason) the script would
  # never find out and `adb wait-for-device` below would hang forever with no
  # explanation. Capture its output and check it is still running before
  # waiting for a device.
  $emuLog = "$Root\emulator.log"
  $emuErr = "$Root\emulator-error.log"
  Remove-Item $emuLog, $emuErr -ErrorAction SilentlyContinue
  $emuProcess = Start-Process -FilePath "$Sdk\emulator\emulator.exe" `
    -ArgumentList '-avd', 'yks_level' `
    -RedirectStandardOutput $emuLog -RedirectStandardError $emuErr -PassThru

  Write-Host "    launching the emulator..."
  Start-Sleep 8
  if ($emuProcess.HasExited) {
    Write-Host ""
    Write-Host "    The emulator process exited immediately (exit code $($emuProcess.ExitCode))." -ForegroundColor Red
    if (Test-Path $emuErr) {
      Write-Host "    Its error output:" -ForegroundColor Red
      Get-Content $emuErr | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
    Write-Host ""
    Write-Host "    This is almost always one of:" -ForegroundColor Yellow
    Write-Host "      - Hardware virtualization is off. Task Manager > Performance > CPU" -ForegroundColor Yellow
    Write-Host "        should say Virtualization: Enabled. If not: enable VT-x/AMD-V in" -ForegroundColor Yellow
    Write-Host "        your BIOS, then turn on 'Windows Hypervisor Platform' under" -ForegroundColor Yellow
    Write-Host "        'Turn Windows features on or off'." -ForegroundColor Yellow
    Write-Host "      - Antivirus (incl. Windows Defender) quarantined or blocked a file" -ForegroundColor Yellow
    Write-Host "        under $Sdk\emulator -- add that folder to its exclusions." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Fastest way past this: plug in an Android phone over USB (enable" -ForegroundColor Yellow
    Write-Host "    USB debugging in Developer options) and re-run this script with" -ForegroundColor Yellow
    Write-Host "    -Device." -ForegroundColor Yellow
    throw "Emulator failed to start. See the error above."
  }

  Write-Host "    waiting for the device to appear..."
  adb wait-for-device

  # A silent multi-minute hang here is almost always Windows lacking hardware
  # virtualization (VT-x/AMD-V off in BIOS, or Windows Hypervisor Platform not
  # enabled), or another hypervisor (VirtualBox/Docker Desktop/WSL2/VMware)
  # holding the same CPU extensions. Report progress and, past 90s, say so
  # instead of leaving the user staring at a frozen-looking terminal.
  Write-Host "    device connected, waiting for Android to finish booting"
  $bootStart = Get-Date
  $hintShown = $false
  while ((adb shell getprop sys.boot_completed 2>$null) -notmatch '1') {
    $elapsed = [int]((Get-Date) - $bootStart).TotalSeconds
    Write-Host "    ... still booting (${elapsed}s)"

    if ($elapsed -gt 90 -and -not $hintShown) {
      $hintShown = $true
      Write-Host ""
      Write-Host "    Taking a while. Likely causes:" -ForegroundColor Yellow
      Write-Host "      - Hardware virtualization is off. Task Manager > Performance >" -ForegroundColor Yellow
      Write-Host "        CPU should say Virtualization: Enabled. If not: enable VT-x /" -ForegroundColor Yellow
      Write-Host "        AMD-V in your BIOS, then turn on 'Windows Hypervisor Platform'" -ForegroundColor Yellow
      Write-Host "        under 'Turn Windows features on or off'." -ForegroundColor Yellow
      Write-Host "      - Another hypervisor (VirtualBox, Docker Desktop, WSL2, VMware) is" -ForegroundColor Yellow
      Write-Host "        holding the same CPU virtualization extensions." -ForegroundColor Yellow
      Write-Host "      - The emulator crashed silently -- check Task Manager for a" -ForegroundColor Yellow
      Write-Host "        'qemu-system-x86_64' process; if it's gone, it crashed." -ForegroundColor Yellow
      Write-Host ""
      Write-Host "    Fastest way past this: plug in an Android phone over USB (enable" -ForegroundColor Yellow
      Write-Host "    USB debugging in Developer options) and re-run this script with" -ForegroundColor Yellow
      Write-Host "    -Device." -ForegroundColor Yellow
      Write-Host ""
    }

    if ($elapsed -gt 360) {
      throw "Emulator did not finish booting after 6 minutes. See the hints " +
            "above, or re-run this script with -Device to use a USB-connected " +
            "phone instead."
    }
    Start-Sleep 10
  }
}

Step "Launching YKS Level"
Write-Host "    press r to hot reload, R to restart, q to quit`n"
flutter run

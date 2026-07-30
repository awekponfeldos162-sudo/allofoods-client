# launch_all_devices.ps1
# Lance l'app allofoods sur tous les appareils connectés simultanément
# Usage : .\test\k6\launch_all_devices.ps1
# Usage (release) : .\test\k6\launch_all_devices.ps1 -mode release

param(
  [string]$mode = "debug",  # "debug" | "release" | "profile"
  [string]$target = ""       # chemin main.dart spécifique (optionnel)
)

Set-Location $PSScriptRoot\..\..\

Write-Host "=== allofoods — Lancement multi-appareils ===" -ForegroundColor Cyan
Write-Host "Mode : $mode" -ForegroundColor Yellow

# ── 1. Lister les appareils connectés ──────────────────────────────────────────
Write-Host "`nDétection des appareils..." -ForegroundColor Cyan
$devicesRaw = flutter devices 2>&1

# Parser les lignes de devices (format : "Nom (type) • ID • ...")
$deviceIds = @()
foreach ($line in $devicesRaw) {
  if ($line -match "•\s*(\S+)\s*•") {
    $id = $Matches[1]
    # Exclure les navigateurs pour le test mobile (garder android + windows)
    if ($id -notin @("chrome", "edge")) {
      $deviceIds += $id
    }
  }
}

if ($deviceIds.Count -eq 0) {
  Write-Host "Aucun appareil détecté. Connectez des appareils Android via USB." -ForegroundColor Red
  exit 1
}

Write-Host "Appareils trouvés : $($deviceIds -join ', ')" -ForegroundColor Green

# ── 2. Build (optionnel, une seule fois avant de déployer) ─────────────────────
if ($mode -eq "release") {
  Write-Host "`nBuild APK release..." -ForegroundColor Cyan
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Build échoué." -ForegroundColor Red
    exit 1
  }
}

# ── 3. Lancer sur chaque appareil dans une nouvelle fenêtre PowerShell ─────────
$mainFile = if ($target -ne "") { $target } else { "lib/main.dart" }
$jobs     = @()

Write-Host "`nLancement sur $($deviceIds.Count) appareil(s)..." -ForegroundColor Cyan

foreach ($deviceId in $deviceIds) {
  Write-Host "  → $deviceId" -ForegroundColor White

  $flutterArgs = "run -d $deviceId --$mode -t $mainFile"

  # Ouvrir une nouvelle fenêtre PowerShell par appareil
  $proc = Start-Process powershell -ArgumentList `
    "-NoExit", "-Command", `
    "Write-Host 'Device: $deviceId' -ForegroundColor Cyan; flutter $flutterArgs" `
    -PassThru

  $jobs += $proc
  Start-Sleep -Milliseconds 500  # petit délai pour éviter les conflits Gradle
}

Write-Host "`n$($jobs.Count) instance(s) lancée(s)." -ForegroundColor Green
Write-Host "Ferme les fenêtres manuellement pour arrêter." -ForegroundColor Gray

# Attendre que toutes les fenêtres soient fermées (optionnel)
# $jobs | ForEach-Object { $_.WaitForExit() }

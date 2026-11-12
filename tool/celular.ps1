# Runs the lab on the computer and shows it on an Android phone connected by
# USB cable (Chrome on the phone opens http://localhost:8000).
#
# Usage (PowerShell, from the project folder):
#   .\tool\celular.ps1              -> real Firebase project
#   .\tool\celular.ps1 -Emuladores  -> local emulators (fictitious data);
#                                      start them first in DeclaraHorario
#                                      with: npm run emulators
#
# Requirements: USB debugging enabled on the phone and the cable connected.
param([switch]$Emuladores)

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    Write-Host 'No se encontró adb en' $adb -ForegroundColor Red
    exit 1
}

$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
if (-not $devices) {
    Write-Host 'No hay ningún celular conectado.' -ForegroundColor Yellow
    Write-Host '1. Active Opciones de desarrollador > Depuración USB en el celular.'
    Write-Host '2. Conecte el cable y acepte "¿Permitir depuración USB?".'
    Write-Host '3. Vuelva a correr este script.'
    exit 1
}

# The phone's localhost:8000 goes to this computer's port 8000 through the cable.
$webPort = 8000
& $adb reverse "tcp:$webPort" "tcp:$webPort" | Out-Null

$defines = @()
if ($Emuladores) {
    # Same ports as DeclaraHorario's firebase.json: Auth, Firestore, Storage.
    foreach ($port in 9099, 8080, 9199) {
        & $adb reverse "tcp:$port" "tcp:$port" | Out-Null
    }
    $defines += '--dart-define=USE_EMULATORS=true'
}

Write-Host ''
Write-Host "Cuando diga 'is being served', abra en el Chrome del celular:" -ForegroundColor Green
Write-Host "    http://localhost:$webPort" -ForegroundColor Green
Write-Host "Para ver cambios: presione r aquí y recargue la página en el celular."
Write-Host ''

flutter run -d web-server --web-hostname 127.0.0.1 --web-port $webPort @defines

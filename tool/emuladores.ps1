# Starts the local Firebase emulators (in their own window) with
# DeclaraHorario's security rules and fills them with fictitious test
# accounts. Nothing touches the real Firebase project.
#
# Usage (PowerShell, from the project folder):  .\tool\emuladores.ps1
# Then run the app with the "emuladores" configuration in VS Code, or:
#   flutter run -d chrome --dart-define=USE_EMULATORS=true
$project = 'declarahorario-b186f'
$root = Split-Path -Parent $PSScriptRoot

function Test-Port([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1', $port); return $true }
    catch { return $false }
    finally { $client.Dispose() }
}

if (-not ((Test-Port 8080) -and (Test-Port 9099))) {
    # The Firebase CLI only reads rules inside this folder: copy
    # DeclaraHorario's current rules (read only, never edited) on every start.
    $rules = Join-Path $root 'firebase'
    New-Item -ItemType Directory -Force $rules | Out-Null
    foreach ($file in 'firestore.rules', 'storage.rules') {
        Copy-Item (Join-Path $root "..\DeclaraHorario\$file") (Join-Path $rules $file) -Force
    }

    Write-Host 'Iniciando los emuladores en otra ventana (no la cierre)...'
    Start-Process powershell -WorkingDirectory $root -ArgumentList @(
        '-NoExit', '-Command',
        "firebase emulators:start --only auth,firestore,storage --project $project"
    )
    $waited = 0
    while (-not ((Test-Port 8080) -and (Test-Port 9099))) {
        Start-Sleep -Seconds 2
        $waited += 2
        if ($waited -ge 120) {
            Write-Host 'Los emuladores no arrancaron en 2 minutos. Revise la otra ventana.' -ForegroundColor Red
            exit 1
        }
    }
}

$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node (Join-Path $PSScriptRoot 'seed_emuladores.js')

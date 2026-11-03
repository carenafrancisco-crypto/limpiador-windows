# Saca apps del inicio de Windows (siguen instaladas, se abren a mano).
# Para reactivar una: Administrador de tareas > Aplicaciones de arranque > Habilitar.
#
# Uso: doble clic en desactivar_inicio.bat
#      Simulacion (no cambia nada): powershell -ExecutionPolicy Bypass -File desactivar_inicio.ps1 -Simular

param([switch]$Simular, [switch]$SinPausa)

# ===================== CONFIGURACION =====================
# Patrones (con comodines *) de apps a sacar del inicio.
# Se comparan con el nombre de la entrada de inicio o del paquete de la app.
$Apagar = @(
    '*Codex*', '*ChatGPT*', '*OpenAI*'
    '*CCleaner*'
    'MicrosoftEdgeAutoLaunch*'
    '*Teams*'
    'Mozilla-Firefox*'
    '*WhatsApp*'
)
# Servicios a pasar de Automatico a Manual (no arrancan con Windows)
$ServiciosManual = @('CCleaner*')
# =========================================================

$ErrorActionPreference = 'SilentlyContinue'

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin -and -not $Simular) {
    Write-Host 'Pidiendo permisos de administrador...'
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    exit
}

function Coincide([string]$texto) {
    foreach ($p in $Apagar) { if ($texto -like $p) { return $true } }
    return $false
}

$script:cambios = 0
$apagadoBytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes((Get-Date).ToFileTime()))

function Reportar([string]$estado, [string]$nombre, [string]$color) {
    Write-Host ('  [{0,-10}] {1}' -f $estado, $nombre) -ForegroundColor $color
}

# --- Entradas clasicas: claves Run y carpetas Inicio ---
# Windows guarda si estan habilitadas en StartupApproved (byte 0 par = on, impar = off)
function Revisar-Entradas([string[]]$nombres, [string]$aprobadoKey) {
    $aprobado = Get-Item $aprobadoKey
    foreach ($n in ($nombres | Sort-Object -Unique)) {
        if (-not $n) { continue }
        $val = if ($aprobado) { $aprobado.GetValue($n) } else { $null }
        $estaOff = $val -and ($val[0] -band 1)
        if ($estaOff) { Reportar 'ya off' $n DarkGray; continue }
        if (Coincide $n) {
            if (-not $Simular) {
                if (-not (Test-Path $aprobadoKey)) { New-Item $aprobadoKey -Force | Out-Null }
                Set-ItemProperty $aprobadoKey -Name $n -Value $apagadoBytes -Type Binary
            }
            Reportar 'APAGADO' $n Yellow
            $script:cambios++
        } else {
            Reportar 'sigue' $n Gray
        }
    }
}

function Nombres-Run([string]$runKey, [string]$aprobadoKey) {
    @((Get-Item $runKey).GetValueNames()) + @((Get-Item $aprobadoKey).GetValueNames())
}

$sa = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
Write-Host ''
Write-Host "Apps de inicio en $env:COMPUTERNAME" -ForegroundColor Cyan
if ($Simular) { Write-Host '(SIMULACION: no se cambia nada)' -ForegroundColor Magenta }
Write-Host ''

Write-Host 'Programas (usuario):'
Revisar-Entradas (Nombres-Run 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' "HKCU:\$sa\Run") "HKCU:\$sa\Run"
Write-Host 'Programas (todos los usuarios):'
Revisar-Entradas (Nombres-Run 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' "HKLM:\$sa\Run") "HKLM:\$sa\Run"
Revisar-Entradas (Nombres-Run 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' "HKLM:\$sa\Run32") "HKLM:\$sa\Run32"

Write-Host 'Carpetas de Inicio:'
$carpetaUsuario = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -File | ForEach-Object Name
$carpetaComun   = Get-ChildItem "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -File | ForEach-Object Name
Revisar-Entradas ($carpetaUsuario | Where-Object { $_ -ne 'desktop.ini' }) "HKCU:\$sa\StartupFolder"
Revisar-Entradas ($carpetaComun   | Where-Object { $_ -ne 'desktop.ini' }) "HKLM:\$sa\StartupFolder"

# --- Apps de Microsoft Store (WhatsApp, Teams, Codex, ChatGPT...) ---
# State: 2 = habilitada, 1 = deshabilitada por el usuario
Write-Host 'Apps de Microsoft Store:'
$appx = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
Get-ChildItem $appx | ForEach-Object {
    $paquete = $_.PSChildName
    Get-ChildItem $_.PSPath | ForEach-Object {
        $estado = (Get-ItemProperty $_.PSPath).State
        if ($null -eq $estado) { return }
        $nombre = ($paquete -split '_')[0] + ' / ' + $_.PSChildName
        if ($estado -ne 2) { Reportar 'ya off' $nombre DarkGray; return }
        if ((Coincide $paquete) -or (Coincide $_.PSChildName)) {
            if (-not $Simular) { Set-ItemProperty $_.PSPath -Name State -Value 1 -Type DWord }
            Reportar 'APAGADO' $nombre Yellow
            $script:cambios++
        } else {
            Reportar 'sigue' $nombre Gray
        }
    }
}

# --- Servicios ---
Write-Host 'Servicios:'
foreach ($patron in $ServiciosManual) {
    Get-Service $patron | ForEach-Object {
        if ($_.StartType -eq 'Automatic') {
            if (-not $Simular) {
                Stop-Service $_.Name -Force
                Set-Service $_.Name -StartupType Manual
            }
            Reportar 'MANUAL' $_.Name Yellow
            $script:cambios++
        } else {
            Reportar 'ya manual' "$($_.Name) ($($_.StartType))" DarkGray
        }
    }
}

Write-Host ''
$verbo = if ($Simular) { 'Se cambiarian' } else { 'Cambios aplicados' }
Write-Host "$verbo`: $($script:cambios). Efecto completo al reiniciar." -ForegroundColor Green
Write-Host 'Para agregar mas apps, edita la lista $Apagar arriba del script.'
if (-not $SinPausa) { Read-Host 'Enter para cerrar' | Out-Null }

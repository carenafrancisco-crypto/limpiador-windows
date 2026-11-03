@echo off
setlocal EnableExtensions
title Limpieza de disco - Windows 10/11

:: ============================================================
::  CONFIGURACION (cambiar segun la PC)
::    1 = si, 0 = no
:: ============================================================
:: Cerrar Chrome/Edge/Brave/Firefox para poder limpiar su cache
set "CERRAR_NAVEGADORES=1"
:: Cerrar WhatsApp y limpiar su cache (NO borra chats ni sesion)
set "LIMPIAR_WHATSAPP=1"
:: Hibernacion: auto = desactivar solo en PCs sin bateria (escritorio)
::              1 = desactivar siempre / 0 = no tocar
set "DESACTIVAR_HIBERNACION=auto"
:: DISM /ResetBase: libera mas, pero ya no se pueden desinstalar updates
set "RESETBASE=1"
:: Ejecutar el Liberador de espacio de Windows (cleanmgr)
set "USAR_CLEANMGR=1"

:: ============================================================
::  AUTO-ELEVACION A ADMINISTRADOR
:: ============================================================
net session >nul 2>&1
if errorlevel 1 (
    echo Pidiendo permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

color 0A
set "DRV=%SystemDrive:~0,1%"

echo ============================================
echo   LIMPIEZA DE DISCO - Windows 10/11
echo   PC: %COMPUTERNAME%   Unidad: %SystemDrive%
echo ============================================
echo.
echo Puede tardar 10-20 minutos. NO cierres esta ventana.
if "%CERRAR_NAVEGADORES%"=="1" echo AVISO: se van a cerrar los navegadores. Guarda lo que tengas abierto.
echo.
pause

for /f %%A in ('powershell -NoProfile -Command "(Get-PSDrive %DRV%).Free"') do set "LIBRE_ANTES=%%A"

:: ============================================================
:: 1. CERRAR APPS
:: ============================================================
echo [1/9] Cerrando apps...
if "%CERRAR_NAVEGADORES%"=="1" (
    rem Primero cierre normal (para que restauren pestanas), despues forzado
    for %%P in (chrome.exe msedge.exe brave.exe firefox.exe) do taskkill /IM %%P >nul 2>&1
    timeout /t 3 /nobreak >nul
    for %%P in (chrome.exe msedge.exe brave.exe firefox.exe) do taskkill /IM %%P /F >nul 2>&1
)
if "%LIMPIAR_WHATSAPP%"=="1" taskkill /IM WhatsApp.exe /F >nul 2>&1

:: ============================================================
:: 2. RESIDUOS DE ACTUALIZACIONES DE WINDOWS
:: ============================================================
echo [2/9] Borrando residuos de actualizaciones...
rmdir /s /q "%SystemDrive%\$WINDOWS.~BT" >nul 2>&1
rmdir /s /q "%SystemDrive%\$WinREAgent" >nul 2>&1
rmdir /s /q "%SystemDrive%\System.Sav" >nul 2>&1

net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
rmdir /s /q "%SystemRoot%\SoftwareDistribution\Download" >nul 2>&1
mkdir "%SystemRoot%\SoftwareDistribution\Download" >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1

:: Cache de Optimizacion de distribucion (updates P2P)
powershell -NoProfile -Command "try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop } catch {}" >nul 2>&1

:: ============================================================
:: 3. WinSxS (componentes obsoletos)
:: ============================================================
echo [3/9] Limpiando WinSxS - tarda varios minutos...
if "%RESETBASE%"=="1" (
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase >nul 2>&1
) else (
    Dism.exe /online /Cleanup-Image /StartComponentCleanup >nul 2>&1
)

:: ============================================================
:: 4. HIBERNACION
:: ============================================================
echo [4/9] Hibernacion...
set "HIB=%DESACTIVAR_HIBERNACION%"
if /i "%HIB%"=="auto" (
    powershell -NoProfile -Command "if (Get-CimInstance Win32_Battery) { exit 1 } else { exit 0 }"
    if errorlevel 1 (set "HIB=0") else (set "HIB=1")
)
if "%HIB%"=="1" (
    powercfg -h off >nul 2>&1
    echo       desactivada
) else (
    echo       sin cambios ^(notebook o desactivado en config^)
)

:: ============================================================
:: 5. TEMPORALES
:: ============================================================
echo [5/9] Limpiando temporales...
del /f /s /q "%TEMP%\*" >nul 2>&1
for /d %%D in ("%TEMP%\*") do rmdir /s /q "%%D" >nul 2>&1
del /f /s /q "%SystemRoot%\Temp\*" >nul 2>&1
for /d %%D in ("%SystemRoot%\Temp\*") do rmdir /s /q "%%D" >nul 2>&1

:: ============================================================
:: 6. CACHE DE NAVEGADORES (todos los perfiles)
:: ============================================================
echo [6/9] Limpiando cache de navegadores...
if "%CERRAR_NAVEGADORES%"=="1" (
    for %%B in (
        "%LocalAppData%\Google\Chrome\User Data"
        "%LocalAppData%\Microsoft\Edge\User Data"
        "%LocalAppData%\BraveSoftware\Brave-Browser\User Data"
    ) do if exist "%%~B" (
        for /d %%P in ("%%~B\Default" "%%~B\Profile *") do (
            rmdir /s /q "%%~P\Cache" >nul 2>&1
            rmdir /s /q "%%~P\Code Cache" >nul 2>&1
            rmdir /s /q "%%~P\GPUCache" >nul 2>&1
        )
    )
    if exist "%LocalAppData%\Mozilla\Firefox\Profiles" (
        for /d %%P in ("%LocalAppData%\Mozilla\Firefox\Profiles\*") do rmdir /s /q "%%~P\cache2" >nul 2>&1
    )
)

:: ============================================================
:: 7. CACHE DE WHATSAPP (solo cache, nunca la app ni los chats)
:: ============================================================
echo [7/9] Limpiando cache de WhatsApp...
if "%LIMPIAR_WHATSAPP%"=="1" (
    rem WhatsApp Desktop clasico
    for %%C in ("WhatsApp Temp" "Cache" "Code Cache" "GPUCache") do rmdir /s /q "%AppData%\WhatsApp\%%~C" >nul 2>&1
    rem WhatsApp de Microsoft Store: solo carpeta temporal
    for /d %%W in ("%LocalAppData%\Packages\*WhatsAppDesktop*") do rmdir /s /q "%%~W\AC\Temp" >nul 2>&1
)

:: ============================================================
:: 8. PAPELERA Y MINIATURAS
:: ============================================================
echo [8/9] Vaciando papelera y cache de miniaturas...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
del /f /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1

:: ============================================================
:: 9. LIBERADOR DE ESPACIO DE WINDOWS
:: ============================================================
echo [9/9] Ejecutando liberador de espacio de Windows...
if "%USAR_CLEANMGR%"=="1" (
    rem Marca todas las categorias para el perfil 99, EXCEPTO la carpeta Descargas
    powershell -NoProfile -Command "$k='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'; Get-ChildItem $k | ForEach-Object { if ($_.PSChildName -eq 'DownloadsFolder') { Remove-ItemProperty -Path $_.PSPath -Name StateFlags0099 -ErrorAction SilentlyContinue } else { New-ItemProperty -Path $_.PSPath -Name StateFlags0099 -Value 2 -PropertyType DWord -Force | Out-Null } }" >nul 2>&1
    start "" /wait cleanmgr /sagerun:99
)

:: ============================================================
:: RESULTADO
:: ============================================================
for /f %%A in ('powershell -NoProfile -Command "(Get-PSDrive %DRV%).Free"') do set "LIBRE_DESPUES=%%A"
echo.
echo ============================================
echo   LISTO
echo ============================================
powershell -NoProfile -Command "$a=%LIBRE_ANTES%; $d=%LIBRE_DESPUES%; Write-Host ('Liberado: {0:N2} GB' -f (($d-$a)/1GB)); Write-Host ('Libre ahora en %SystemDrive%: {0:N2} GB' -f ($d/1GB))"
echo.
echo Reinicia la PC cuando puedas para que Windows
echo termine de liberar todo.
echo.
pause
endlocal

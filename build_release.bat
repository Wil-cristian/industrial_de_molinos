@echo off
REM ============================================
REM Script de Build + Empaquetado
REM Industrial de Molinos
REM ============================================
REM
REM USO:
REM   build_release.bat              (usa version del pubspec.yaml)
REM   build_release.bat 1.2.0        (especifica version)
REM
REM REQUISITOS:
REM   - Flutter SDK instalado
REM   - Visual Studio Build Tools (C++)
REM   - Inno Setup instalado (para crear el instalador)
REM ============================================

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Build Release - Industrial de Molinos
echo ========================================
echo.

REM --- Detectar version ---
if "%~1"=="" (
    REM Leer version del pubspec.yaml
    for /f "tokens=2 delims=: " %%a in ('findstr /B "version:" pubspec.yaml') do (
        for /f "tokens=1 delims=+" %%b in ("%%a") do set APP_VERSION=%%b
    )
) else (
    set APP_VERSION=%~1
)

echo Version: %APP_VERSION%
echo.

REM --- Paso 1: Limpiar build anterior ---
echo [1/4] Limpiando build anterior...
if exist "build\windows\x64\runner\Release" (
    rmdir /s /q "build\windows\x64\runner\Release" 2>nul
)
echo       OK
echo.

REM --- Paso 2: Compilar Flutter ---
echo [2/4] Compilando Flutter para Windows (release)...
echo       Esto puede tomar unos minutos...
flutter build windows --release
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la compilacion de Flutter
    echo Verifica que tienes Visual Studio Build Tools instalado.
    pause
    exit /b 1
)
echo       OK
echo.

REM --- Paso 3: Verificar que existe el exe ---
if not exist "build\windows\x64\runner\Release\molinos_app.exe" (
    echo ERROR: No se encontro molinos_app.exe en el build
    echo Verifica la salida de flutter build
    pause
    exit /b 1
)
echo [3/4] Build verificado: molinos_app.exe encontrado
echo.

REM --- Paso 4: Crear instalador con Inno Setup ---
echo [4/4] Creando instalador...

REM Buscar Inno Setup en ubicaciones comunes
set ISCC=""
if exist "C:\Users\wilo\AppData\Local\Programs\Inno Setup 6\ISCC.exe" (
    set ISCC="C:\Users\wilo\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
)
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set ISCC="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set ISCC="C:\Program Files\Inno Setup 6\ISCC.exe"
)

if %ISCC%=="" (
    echo.
    echo AVISO: Inno Setup no encontrado.
    echo El build de Flutter se completo exitosamente en:
    echo   build\windows\x64\runner\Release\
    echo.
    echo Para crear el instalador:
    echo   1. Descarga Inno Setup: https://jrsoftware.org/isdl.php
    echo   2. Abre installer\molinos_app.iss con Inno Setup
    echo   3. Click en Compile
    echo.
    pause
    exit /b 0
)

REM Crear carpeta de salida
if not exist "build\installer" mkdir "build\installer"

REM Compilar el instalador
%ISCC% /DMyAppVersion=%APP_VERSION% "installer\molinos_app.iss"
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la creacion del instalador
    pause
    exit /b 1
)

echo.
echo ========================================
echo   BUILD COMPLETADO EXITOSAMENTE
echo ========================================
echo.
echo   Version:     %APP_VERSION%
echo   Ejecutable:  build\windows\x64\runner\Release\molinos_app.exe
if exist "build\installer\MolinosApp_Setup_%APP_VERSION%.exe" (
    echo   Instalador:  build\installer\MolinosApp_Setup_%APP_VERSION%.exe
)
echo.
echo SIGUIENTE PASO:
echo   1. Sube el instalador a GitHub Releases o tu servidor
echo   2. Actualiza la tabla app_releases en Supabase con:
echo      - version: %APP_VERSION%
echo      - download_url: [URL del instalador]
echo      - release_notes: [Notas del release]
echo.
pause

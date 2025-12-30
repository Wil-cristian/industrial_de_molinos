@echo off
REM ============================================
REM Script para compilar Flutter en Windows
REM Soluciona el problema del compilador C++
REM ============================================

echo.
echo ========================================
echo   Compilando Industrial de Molinos
echo   para Windows Desktop
echo ========================================
echo.

REM Configurar el entorno de Visual Studio 2026
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"

REM Verificar que el compilador está disponible
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: No se encontró el compilador C++
    echo Por favor instala Visual Studio 2022 Build Tools
    pause
    exit /b 1
)

echo Compilador encontrado correctamente
echo.

REM Limpiar build anterior
echo Limpiando build anterior...
cd /d "%~dp0"
if exist "build\windows" rmdir /s /q "build\windows"

REM Ejecutar flutter build
echo Ejecutando flutter build windows --release...
flutter build windows --release

if errorlevel 1 (
    echo.
    echo ========================================
    echo   ERROR: La compilación falló
    echo ========================================
    echo.
    echo Si el error persiste, intenta:
    echo 1. Instalar Visual Studio 2022 Build Tools
    echo 2. O ejecutar este script como administrador
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Compilación exitosa!
echo ========================================
echo.
echo El ejecutable está en:
echo build\windows\x64\runner\Release\molinos_app.exe
echo.
pause

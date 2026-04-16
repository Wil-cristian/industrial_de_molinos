@echo off
echo Configurando entorno de Visual Studio 2022...
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 (
    echo Error configurando VS 2022, intentando VS 2026...
    call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
)
set PATH=C:\Users\wilo\AppData\Local\Microsoft\WinGet\Links;%PATH%
cd /d "c:\Users\wilo\OneDrive\Desktop\industrial de molinos"
echo.
echo Limpiando build anterior...
rmdir /s /q build\windows 2>nul
echo.
echo Compilando proyecto Flutter para Windows...
flutter build windows --release
echo.
echo Build completado!
pause

@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set PATH=C:\Users\wilo\AppData\Local\Microsoft\WinGet\Links;%PATH%
cd /d "c:\Users\wilo\OneDrive\Desktop\industrial de molinos"
flutter build windows --release

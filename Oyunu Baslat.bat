@echo off
rem Gokkalkan'i baslatir (Godot winget ile kurulu olmali)
for /d %%G in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
  for %%E in ("%%G\Godot_v*_win64.exe") do (
    echo %%~nxE | find /i "console" >nul || ( start "" "%%E" --path "%~dp0" & exit /b )
  )
)
echo Godot bulunamadi. Kurmak icin: winget install GodotEngine.GodotEngine
pause

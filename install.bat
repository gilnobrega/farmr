echo Please run this bat as an admin
echo .
echo Installing chocolatey
echo .
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
choco feature enable -n=allowGlobalConfirmation
pause

echo Installing git
echo.
choco install git

echo Installing dart
echo.
choco install dart-sdk

echo You are ready to go! Please open run.bat
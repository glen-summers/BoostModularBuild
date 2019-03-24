@echo off
cls
setlocal EnableDelayedExpansion

set buildFile=%~dp0windows\build.build
set msbuildVersion=15.0
set requires=Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64

set vswherecmd="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires %requires% -property installationPath
for /F "tokens=* usebackq" %%i in (`%vswherecmd%`) do set vsInstallationPath=%%i
if "%vsInstallationPath%" equ "" echo Visual studio not found & exit /b 1
echo VisualStudio=%vsInstallationPath%

set msb="%vsInstallationPath%\MSBuild\%msbuildVersion%\Bin\amd64\MSBuild.exe"
if not exist %msb% echo MSBuild not found at %msb% & exit /b 1
echo MsBuild=%msb%

set args=%*
if "%1" NEQ "" set args=/t:%*

call "%vsInstallationPath%\VC\Auxiliary\Build\vcvars64.bat"
%msb% /toolsversion:4.0 /p:vsInstallationPath="%vsInstallationPath%" %buildFile% %args%

exit /b 0
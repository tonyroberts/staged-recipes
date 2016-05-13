:: Set the right msvc version according to Python version
REM write a temporary batch file to map cl.exe version to visual studio version
echo @echo 15=9 > msvc_versions.bat
echo @echo 16=10 >> msvc_versions.bat
echo @echo 17=11 >> msvc_versions.bat
echo @echo 18=12 >> msvc_versions.bat
echo @echo 19=14 >> msvc_versions.bat

REM Run cl.exe to find which version our compiler is
for /f "delims=" %%A in ('cl /? 2^>^&1 ^| findstr /C:"Version"') do set "CL_TEXT=%%A"
FOR /F "tokens=1,2 delims==" %%i IN ('msvc_versions.bat') DO echo %CL_TEXT% | findstr /C:"Version %%i" > nul && set VSVERSION=%%j && goto FOUND
EXIT 1
:FOUND

call :TRIM VSVERSION %VSVERSION%

if "%ARCH%"=="32" (
   set ARCH=Win32
   set COPYSUFFIX=
) else (
  set ARCH=x64
  set COPYSUFFIX=64
)

:: Build without exports (first pass)
msbuild /m /p:useenv=true /p:Configuration=Release;Platform=%ARCH% QuantLib_vc%VSVERSION%.sln /t:QuantLib
if errorlevel 1 exit 1

:: Generate symbols
python generate_symbols.py %VSVERSION%
if errorlevel 1 exit 1

:: Build with exported symbols (seconds pass)
msbuild /m /p:useenv=true /p:Configuration=Release;Platform=%ARCH% QuantLib_vc%VSVERSION%.sln /t:QuantLib
if errorlevel 1 exit 1

:: Install includes (robocopy uses non-standard exit codes)
ROBOCOPY ql %LIBRARY_INC%/ql *.hpp /e
if errorlevel 0 goto COPIED_OK
if errorlevel 1 goto COPIED_OK
exit 1
:COPIED_OK

:: Install libs
MOVE lib\*.lib "%LIBRARY_LIB%"
if errorlevel 1 exit 1

:: Install dlls
MOVE lib\*.dll "%LIBRARY_BIN%"
if errorlevel 1 exit 1

:TRIM
  SetLocal EnableDelayedExpansion
  set Params=%*
  for /f "tokens=1*" %%a in ("!Params!") do EndLocal & set %1=%%b
  exit /B

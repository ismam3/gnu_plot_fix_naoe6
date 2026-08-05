@echo off
rem ==================================================================
rem  Gnuplot Environment Variable Fix
rem  NAOE 3210 - Computer Programming for Engineers
rem  Bangladesh Maritime University
rem
rem  Adds the gnuplot bin folder to the PATH environment variable so
rem  that _popen("gnuplot ...") works from a C++ program.
rem
rem  With admin rights  : fixes the machine for every user account.
rem  Without admin      : fixes the current user account only.
rem ==================================================================

setlocal EnableExtensions EnableDelayedExpansion
title Gnuplot Environment Variable Fix

set "SCOPE=USER"
set "GPDIR="

rem ---------- is this window running as administrator? ----------
set "ISADMIN=0"
fltmc >nul 2>&1 && set "ISADMIN=1"

cls
echo ==============================================================
echo    Gnuplot Environment Variable Fix
echo    NAOE 3210 - Computer Programming for Engineers
echo ==============================================================
echo.

rem ==================================================================
rem  1. Is gnuplot already reachable from the command line?
rem ==================================================================
where gnuplot.exe >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%I in ('where gnuplot.exe') do (
        if not defined GPDIR set "GPDIR=%%~dpI"
    )
    if defined GPDIR set "GPDIR=!GPDIR:~0,-1!"
    echo  [OK] gnuplot is already on the PATH:
    echo       !GPDIR!
    echo.
    echo  The environment variable does not need to be changed.
    goto :offer_test
)

echo  [..] gnuplot is NOT on the PATH.
echo       Searching for the installation folder...
echo.

call :FindGnuplot
if not defined GPDIR goto :notfound

echo  [OK] Found gnuplot here:
echo       !GPDIR!
echo.

rem ==================================================================
rem  2. Decide the scope: whole machine or this account only
rem ==================================================================
if "%ISADMIN%"=="1" (
    set "SCOPE=SYSTEM"
    echo  [i]  Running as administrator. The fix will apply to
    echo       EVERY user account on this computer.
    echo.
) else (
    if /i "%~1"=="/noelevate" (
        set "SCOPE=USER"
    ) else (
        echo  This window does not have administrator rights.
        echo.
        echo    [1] Fix for ALL users on this PC   ^(will ask for admin^)
        echo    [2] Fix for MY account only        ^(no admin needed^)
        echo.
        choice /c 12 /n /m "  Choose 1 or 2: "
        echo.
        if errorlevel 2 (
            set "SCOPE=USER"
        ) else (
            goto :elevate
        )
    )
)

goto :writepath

rem ==================================================================
rem  Relaunch this same file with administrator rights
rem ==================================================================
:elevate
echo  [..] Asking Windows for administrator rights...
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
if errorlevel 1 (
    echo  [!!] Administrator rights were refused or not available.
    echo       Continuing for your own account only.
    echo.
    set "SCOPE=USER"
    goto :writepath
)
rem The elevated copy takes over from here.
exit /b

rem ==================================================================
rem  3. Read the existing PATH from the correct registry hive.
rem     Never use %%PATH%% here. That is system and user merged, and
rem     writing it back would duplicate the whole system PATH.
rem ==================================================================
:writepath
if /i "!SCOPE!"=="SYSTEM" (
    set "HIVE=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    set "WHO=all users on this computer"
) else (
    set "HIVE=HKCU\Environment"
    set "WHO=your account only"
)

set "OLDPATH="
set "PTYPE=REG_EXPAND_SZ"
for /f "tokens=1,2,*" %%A in ('reg query "!HIVE!" /v Path 2^>nul') do (
    if /i "%%A"=="Path" (
        set "PTYPE=%%B"
        set "OLDPATH=%%C"
    )
)

rem ---------- already present? ----------
if defined OLDPATH (
    echo(!OLDPATH! | findstr /i /c:"!GPDIR!" >nul
    if not errorlevel 1 (
        echo  [OK] That folder is already in the PATH for !WHO!.
        echo       You only need to close and reopen your editor.
        goto :offer_test
    )
)

rem ---------- build the new value ----------
if defined OLDPATH (
    set "NEWPATH=!OLDPATH!;!GPDIR!"
) else (
    set "NEWPATH=!GPDIR!"
)
set "NEWPATH=!NEWPATH:;;=;!"
if "!NEWPATH:~-1!"=="\" set "NEWPATH=!NEWPATH:~0,-1!"

rem ---------- keep a backup of the old value ----------
set "BACKUP=%USERPROFILE%\gnuplot-path-backup.txt"
> "!BACKUP!" echo(!OLDPATH!
echo  [..] Old PATH saved to:
echo       !BACKUP!
echo.

rem ==================================================================
rem  4. Write it.
rem     reg add is used instead of setx because setx silently cuts
rem     the value at 1024 characters, and a system PATH is often
rem     longer than that. reg add has no such limit and keeps the
rem     REG_EXPAND_SZ type intact.
rem ==================================================================
reg add "!HIVE!" /v Path /t !PTYPE! /d "!NEWPATH!" /f >nul 2>&1
if errorlevel 1 (
    echo  [XX] Writing the PATH failed.
    echo       Nothing was changed.
    goto :end
)

rem ==================================================================
rem  5. Tell Windows the environment changed.
rem     setx broadcasts a settings-change message to the whole
rem     desktop, so a short extra variable is written here purely to
rem     trigger that broadcast. GNUPLOT_HOME is also useful on its own.
rem ==================================================================
if /i "!SCOPE!"=="SYSTEM" (
    setx /M GNUPLOT_HOME "!GPDIR!" >nul 2>&1
) else (
    setx GNUPLOT_HOME "!GPDIR!" >nul 2>&1
)

echo  [OK] PATH updated for !WHO!.
echo  [OK] GNUPLOT_HOME set to !GPDIR!
echo.
echo  --------------------------------------------------------------
echo   IMPORTANT
echo   A program that is already running keeps its old environment.
echo   Close EVERY window of VS Code, Code::Blocks, Dev-C++ and cmd,
echo   then open them again. If VS Code was started from a terminal,
echo   close that terminal too. If it still fails, sign out of
echo   Windows and sign in again.
echo  --------------------------------------------------------------
goto :offer_test

rem ==================================================================
rem  Locate gnuplot.exe
rem ==================================================================
:FindGnuplot
rem --- the registry App Paths key. This is the key the Win+R box
rem     uses, which is why Run finds gnuplot when cmd cannot. ---
for %%K in (
  "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\gnuplot.exe"
  "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\gnuplot.exe"
  "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\gnuplot.exe"
  "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\wgnuplot.exe"
) do (
    if not defined GPDIR (
        for /f "tokens=1,2,*" %%A in ('reg query %%K /ve 2^>nul') do (
            if /i "%%A"=="(Default)" call :SetDir "%%C"
        )
    )
)

rem --- the usual install folders ---
if not defined GPDIR (
    for %%D in (
      "C:\Program Files\gnuplot\bin"
      "C:\Program Files (x86)\gnuplot\bin"
      "C:\gnuplot\bin"
      "D:\gnuplot\bin"
      "D:\Program Files\gnuplot\bin"
      "%LOCALAPPDATA%\Programs\gnuplot\bin"
      "%USERPROFILE%\gnuplot\bin"
    ) do (
        if not defined GPDIR if exist "%%~D\gnuplot.exe" set "GPDIR=%%~D"
    )
)

rem --- ask the student ---
if not defined GPDIR (
    echo  [!!] gnuplot.exe could not be found automatically.
    echo.
    echo       Open the gnuplot folder in File Explorer, go inside the
    echo       "bin" folder, click the address bar, copy the path, and
    echo       paste it below. Press Enter alone to cancel.
    echo.
    set /p "GPDIR=       bin folder: "
    if not defined GPDIR exit /b
    if "!GPDIR:~-1!"=="\" set "GPDIR=!GPDIR:~0,-1!"
    if not exist "!GPDIR!\gnuplot.exe" (
        echo.
        echo  [XX] gnuplot.exe is not in that folder.
        set "GPDIR="
    )
)
exit /b

:SetDir
set "EXE=%~1"
if exist "%EXE%" (
    for %%I in ("%EXE%") do set "GPDIR=%%~dpI"
    if defined GPDIR set "GPDIR=!GPDIR:~0,-1!"
)
exit /b

rem ==================================================================
rem  Optional test plot, using a temporary PATH for this window only
rem ==================================================================
:offer_test
echo.
choice /c YN /n /m "  Run a quick test plot now? [Y/N] "
echo.
if errorlevel 2 goto :end

if defined GPDIR set "PATH=%PATH%;!GPDIR!"
> "%TEMP%\gptest.plt" echo set title "gnuplot is working"
>> "%TEMP%\gptest.plt" echo set xlabel "x"
>> "%TEMP%\gptest.plt" echo set ylabel "sin(x)"
>> "%TEMP%\gptest.plt" echo set grid
>> "%TEMP%\gptest.plt" echo plot sin(x) with lines lw 2
gnuplot -persist "%TEMP%\gptest.plt"
if errorlevel 1 (
    echo  [XX] The test plot did not run.
) else (
    echo  [OK] A plot window should be on your screen now.
)
goto :end

:notfound
echo.
echo  [XX] gnuplot is not installed on this computer, or it was
echo       installed somewhere unusual.
echo.
echo       Install it first from the link on Lecture 8, slide 3:
echo       gp602-win64-mingw.exe from sourceforge.net
echo.

:end
echo.
pause
endlocal

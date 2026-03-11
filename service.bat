@echo off
chcp 1251 > nul
set "LOCAL_VERSION=1.0"
set "TEAM_NAME=LxTeam"
set "GITHUB_REPO=https://github.com/LxTeams/zapret-lxteam"
set "GITHUB_RAW_VERSION=https://raw.githubusercontent.com/LxTeams/zapret-lxteam/main/version.txt"

:: ========== LxTeam Zapret SERVICE ==========
:: Версия: 1.0
:: GitHub: https://github.com/LxTeams/zapret-lxteam
:: ============================================

:: Проверяем, что это прямой запуск service.bat, а не вызов из другого батника
if "%~1"=="" (
    echo ========================================
    echo        %TEAM_NAME% Zapret Service v%LOCAL_VERSION%
    echo        GitHub: %GITHUB_REPO%
    echo ========================================
    echo.
    echo This is service management script.
    echo Use it to install/remove/configure zapret service.
    echo.
    echo Available commands:
    echo   service.bat install     - Install service
    echo   service.bat remove      - Remove service
    echo   service.bat status      - Check status
    echo   service.bat start       - Start service
    echo   service.bat stop        - Stop service
    echo   service.bat menu        - Show menu
    echo.
    goto :eof
)

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if exist "%~dp0utils\check_updates.enabled" (
        if not "%~2"=="soft" (
            start /b service check_updates soft
        ) else (
            call :service_check_updates soft
        )
    )
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh

    echo Started with admin rights
    goto menu
)

if "%1"=="install" (
    call :check_extracted
    call :check_command powershell
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)

if "%1"=="remove" (
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin remove_service\"' -Verb RunAs"
    exit
)

if "%1"=="status" (
    call :service_status
    exit /b
)

if "%1"=="start" (
    sc start zapret >nul 2>&1
    echo Service started
    exit /b
)

if "%1"=="stop" (
    sc stop zapret >nul 2>&1
    echo Service stopped
    exit /b
)

if "%1"=="menu" (
    call :check_extracted
    call :check_command powershell
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)

if "%1"=="remove_service" (
    call :service_remove
    exit /b
)

goto :eof


:: MENU ================================
:menu
setlocal EnableDelayedExpansion
cls
call :check_updates_start
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status

:menu_loop
cls
echo ========================================
echo        %TEAM_NAME% Zapret Service v%LOCAL_VERSION%
echo        GitHub: %GITHUB_REPO%
echo ========================================
echo.
echo 1. Install Service
echo 2. Remove Services
echo 3. Check Status
echo 4. Run Diagnostics
echo 5. Check for Updates
echo 6. Switch Auto Check Updates (%CheckUpdatesStatus%)
echo 7. Switch Game Filter (%GameFilterStatus%)
echo 8. Switch ipset (%IPsetStatus%)
echo 9. Update ipset list
echo 10. Update hosts file (for discord voice)
echo 11. Run Tests
echo 12. Open GitHub Page
echo 0. Exit
echo.
set "menu_choice="
set /p "menu_choice=Enter choice (0-12): "

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto service_diagnostics
if "%menu_choice%"=="5" goto service_check_updates
if "%menu_choice%"=="6" goto check_updates_switch
if "%menu_choice%"=="7" goto game_switch
if "%menu_choice%"=="8" goto ipset_switch
if "%menu_choice%"=="9" goto ipset_update
if "%menu_choice%"=="10" goto hosts_update
if "%menu_choice%"=="11" goto run_tests
if "%menu_choice%"=="12" start "" "%GITHUB_REPO%" & goto menu_loop
if "%menu_choice%"=="0" exit /b
goto menu_loop


:: CHECK UPDATES AT START ===================
:check_updates_start
set "GITHUB_VERSION="
for /f "delims=" %%a in ('powershell -Command "try { (Invoke-WebRequest -Uri '%GITHUB_RAW_VERSION%' -UseBasicParsing -TimeoutSec 3).Content.Trim() } catch { '' }" 2^>nul') do set "GITHUB_VERSION=%%a"

if not defined GITHUB_VERSION goto :eof
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" goto :eof

echo.
echo ====== UPDATE AVAILABLE ======
echo Current version: %LOCAL_VERSION%
echo Latest version: %GITHUB_VERSION%
echo.
echo Would you like to open the GitHub page?
set "update_choice="
set /p "update_choice=Open GitHub? (Y/N): "

if /i "%update_choice%"=="Y" start "" "%GITHUB_REPO%"
if /i "%update_choice%"=="Yes" start "" "%GITHUB_REPO%"
echo.
pause
goto :eof


:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS ==============================
:service_status
cls
chcp 437 > nul

echo ===== %TEAM_NAME% Zapret Status =====
echo.

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v %TEAM_NAME%-zapret 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "Bypass (winws.exe) is RUNNING."
) else (
    call :PrintRed "Bypass (winws.exe) is NOT running."
)

echo.
pause
goto menu_loop

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" is ALREADY RUNNING as service, use "service.bat" and choose "Remove Services" first if you want to run standalone bat.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" service is RUNNING.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING, that may be caused by a conflict with another bypass. Run Diagnostics to try to fix conflicts"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" service is NOT running.
)

exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 1251 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Service "%SRVCNAME%" is not installed.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

echo.
call :PrintGreen "Services removed successfully!"
pause
goto menu_loop


:: INSTALL =============================
:service_install
cls
chcp 1251 > nul

:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

echo ===== %TEAM_NAME% Zapret Service Installation =====
echo.

:: Searching for .bat files in current folder, except files that start with "service"
echo Pick one of the options:
set "count=0"
for %%f in (*.bat) do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%f
        set "file!count!=%%f"
    )
)

:: Choosing file
echo.
set "choice="
set /p "choice=Input file index (number): "
if "!choice!"=="" (
    echo The choice is empty, exiting...
    pause
    goto menu_loop
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Invalid choice, exiting...
    pause
    goto menu_loop
)

:: Args that should be followed by value
set "args_with_value=sni host altorder"

:: Parsing args (mergeargs: 2=start param|3=arg with value|1=params args|0=default)
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: Creating service with parsed args
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "%TEAM_NAME% Zapret" start= auto
sc description %SRVCNAME% "%TEAM_NAME% Zapret - DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v %TEAM_NAME%-zapret /t REG_SZ /d "!filename!" /f

echo.
call :PrintGreen "Service installed and started successfully!"
pause
goto menu_loop


:: CHECK UPDATES =======================
:service_check_updates
cls
echo ===== %TEAM_NAME% Zapret Update Check =====
echo.
echo Current version: %LOCAL_VERSION%
echo.

:: Проверяем последнюю версию на GitHub
set "GITHUB_VERSION="
for /f "delims=" %%a in ('powershell -Command "try { (Invoke-WebRequest -Uri '%GITHUB_RAW_VERSION%' -UseBasicParsing -TimeoutSec 5).Content.Trim() } catch { '' }" 2^>nul') do set "GITHUB_VERSION=%%a"

if not defined GITHUB_VERSION (
    call :PrintYellow "⚠ Could not check for updates. Check your internet connection."
    echo.
    echo GitHub page: %GITHUB_REPO%
    echo.
    pause
    goto menu_loop
)

echo Latest version on GitHub: %GITHUB_VERSION%
echo.

if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    call :PrintGreen "✓ You have the latest version!"
    echo.
    pause
    goto menu_loop
)

:: Если версии разные - предлагаем обновление
call :PrintYellow "⚠ NEW VERSION AVAILABLE: %GITHUB_VERSION%"
echo.
echo A new version of %TEAM_NAME% Zapret is available!
echo Current: %LOCAL_VERSION%  |  Latest: %GITHUB_VERSION%
echo.
echo Would you like to open the GitHub page to download it?
echo.
set "update_choice="
set /p "update_choice=Open GitHub page? (Y/N): "

if /i "%update_choice%"=="Y" start "" "%GITHUB_REPO%"
if /i "%update_choice%"=="Yes" start "" "%GITHUB_REPO%"

if "%1"=="soft" exit 
echo.
pause
goto menu_loop


:: DIAGNOSTICS =========================
:service_diagnostics
chcp 437 > nul
cls

echo ===== %TEAM_NAME% Zapret Diagnostics =====
echo.

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "✓ Base Filtering Engine check passed"
) else (
    call :PrintRed "✗ Base Filtering Engine is not running. This service is required for zapret to work"
)
echo:

:: Proxy check
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    
    call :PrintYellow "⚠ System proxy is enabled: !proxyServer!"
    call :PrintYellow "Make sure it's valid or disable it if you don't use a proxy"
) else (
    call :PrintGreen "✓ Proxy check passed"
)
echo:

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "✓ TCP timestamps check passed"
) else (
    call :PrintYellow "⚠ TCP timestamps are disabled. Enabling timestamps..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "✓ TCP timestamps successfully enabled"
    ) else (
        call :PrintRed "✗ Failed to enable TCP timestamps"
    )
)
echo:

:: Check for conflicting services
set "conflict_found=0"

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "✗ Adguard process found. Adguard may cause problems"
    set "conflict_found=1"
)

:: Killer services
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "✗ Killer services found. Killer conflicts with zapret"
    set "conflict_found=1"
)

:: Intel Connectivity
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "✗ Intel Connectivity Network Service found. It conflicts with zapret"
    set "conflict_found=1"
)

if !conflict_found!==0 (
    call :PrintGreen "✓ No conflicting services found"
)
echo:

:: WinDivert check
set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "✗ WinDivert64.sys file NOT found."
) else (
    call :PrintGreen "✓ WinDivert driver found"
)
echo:

:: GitHub connectivity check
echo Testing GitHub connection...
ping github.com -n 2 > nul 2>&1
if !errorlevel!==0 (
    call :PrintGreen "✓ GitHub is reachable"
) else (
    call :PrintYellow "⚠ GitHub is not reachable. Updates may not work."
)
echo:

call :PrintGreen "Diagnostics complete!"
echo.
pause
goto menu_loop


:: GAME SWITCH ========================
:game_switch_status
chcp 437 > nul

set "gameFlagFile=%~dp0utils\game_filter.enabled"

if exist "%gameFlagFile%" (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
)
exit /b


:game_switch
chcp 437 > nul
cls

if not exist "%gameFlagFile%" (
    echo Enabling game filter...
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Restart the zapret to apply the changes"
) else (
    echo Disabling game filter...
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Restart the zapret to apply the changes"
)

pause
goto menu_loop


:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
chcp 437 > nul

set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"

if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b


:check_updates_switch
chcp 437 > nul
cls

if not exist "%checkUpdatesFlag%" (
    echo Enabling check updates...
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo Disabling check updates...
    del /f /q "%checkUpdatesFlag%"
)

pause
goto menu_loop


:: IPSET SWITCH =======================
:ipset_switch_status
chcp 437 > nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b


:ipset_switch
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo Switching to none mode...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatus%"=="none" (
    echo Switching to any mode...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatus%"=="any" (
    echo Switching to loaded mode...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Error: no backup to restore. Update list from service menu first
        pause
        goto menu_loop
    )
    
)

pause
goto menu_loop


:: IPSET UPDATE =======================
:ipset_update
chcp 1251 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"

echo Updating ipset list...
echo.
echo Download the latest ipset list from our GitHub:
echo %GITHUB_REPO%/blob/main/lists/ipset-all.txt
echo.
start "" "%GITHUB_REPO%"

pause
goto menu_loop


:: HOSTS UPDATE =======================
:hosts_update
chcp 1251 > nul
cls

echo ===== Hosts File Update =====
echo.
echo To update hosts file for Discord voice:
echo.
echo 1. Open our GitHub: %GITHUB_REPO%
echo 2. Find the latest hosts file
echo 3. Copy the content to:
echo    C:\Windows\System32\drivers\etc\hosts
echo.
set "hosts_choice="
set /p "hosts_choice=Open GitHub? (Y/N): "

if /i "%hosts_choice%"=="Y" (
    start "" "%GITHUB_REPO%"
)

pause
goto menu_loop


:: RUN TESTS =============================
:run_tests
chcp 1251 >nul
cls

echo ===== %TEAM_NAME% Zapret Tests =====
echo.
echo Running configuration tests...
echo.

:: Require PowerShell 3.0+
powershell -NoProfile -Command "if ($PSVersionTable -and $PSVersionTable.PSVersion -and $PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo PowerShell 3.0 or newer is required.
    echo Please upgrade PowerShell and rerun this script.
    echo.
    pause
    goto menu_loop
)

if exist "%~dp0utils\test zapret.ps1" (
    echo Starting configuration tests in PowerShell window...
    start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zapret.ps1"
) else (
    echo Test file not found. Download tests from our GitHub:
    echo %GITHUB_REPO%
    start "" "%GITHUB_REPO%"
)

pause
goto menu_loop


:: Utility functions

:PrintGreen
powershell -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 not found in PATH
    echo Fix your PATH variable
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"

if not exist "%~dp0bin\" set "extracted=0"

if "%extracted%"=="0" (
    echo Zapret must be extracted from archive first or bin folder not found for some reason
    pause
    exit
)
exit /b 0
@echo off
chcp 65001 > nul
:: 65001 - UTF-8
setlocal EnableDelayedExpansion

set "LOCAL_VERSION=1.0"
set "GITHUB_REPO=https://github.com/LxTeams/zapret-lxteam"
set "GITHUB_RAW_VERSION=https://raw.githubusercontent.com/LxTeams/zapret-lxteam/main/version.txt"

echo ========================================
echo        LxTeam Zapret v%LOCAL_VERSION%
echo        GitHub: %GITHUB_REPO%
echo ========================================
echo.

:: Проверка обновлений
set "GITHUB_VERSION="
for /f "delims=" %%a in ('powershell -Command "try { (Invoke-WebRequest -Uri '%GITHUB_RAW_VERSION%' -UseBasicParsing -TimeoutSec 3).Content.Trim() } catch { '' }" 2^>nul') do set "GITHUB_VERSION=%%a"

if defined GITHUB_VERSION (
    if not "%LOCAL_VERSION%"=="!GITHUB_VERSION!" (
        echo.
        echo ====== UPDATE AVAILABLE ======
        echo Current version: %LOCAL_VERSION%
        echo Latest version: !GITHUB_VERSION!
        echo.
        set /p "update_choice=Open GitHub to download? (Y/N): "
        if /i "!update_choice!"=="Y" start "" "%GITHUB_REPO%"
        if /i "!update_choice!"=="Yes" start "" "%GITHUB_REPO%"
        echo.
    )
) else (
    echo [Could not check for updates]
)

cd /d "%~dp0"
echo:


if "%GameFilter%"=="" set "GameFilter=12"

set "BIN=%~dp0bin\"
set "LISTS=%~dp0lists\"
cd /d %BIN%

start "zapret: %~n0" /min "%BIN%winws.exe" --wf-tcp=80,443,2053,2083,2087,2096,8443,%GameFilter% --wf-udp=443,19294-19344,50000-50100,%GameFilter% ^
--filter-udp=443 --hostlist="%LISTS%list-general.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin" --new ^
--filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord="%BIN%quic_initial_www_google_com.bin" --dpi-desync-fake-stun="%BIN%quic_initial_www_google_com.bin" --dpi-desync-repeats=6 --new ^
--filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls="%BIN%tls_clienthello_4pda_to.bin" --dpi-desync-fake-tls-mod=none --new ^
--filter-tcp=443 --hostlist="%LISTS%list-google.txt" --ip-id=zero --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls="%BIN%tls_clienthello_www_google_com.bin" --new ^
--filter-tcp=80,443 --hostlist="%LISTS%list-general.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls="%BIN%tls_clienthello_4pda_to.bin" --dpi-desync-fake-tls-mod=none --new ^
--filter-udp=443 --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin" --new ^
--filter-tcp=80,443,%GameFilter% --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls-mod=rnd,sni=www.google.com --dpi-desync-fake-tls="%BIN%tls_clienthello_4pda_to.bin" --dpi-desync-fake-tls-mod=none --new ^
--filter-udp=%GameFilter% --ipset="%LISTS%ipset-all.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --dpi-desync=fake --dpi-desync-autottl=2 --dpi-desync-repeats=12 --dpi-desync-any-protocol=1 --dpi-desync-fake-unknown-udp="%BIN%quic_initial_www_google_com.bin" --dpi-desync-cutoff=n2

echo.
echo Zapret запущен в фоновом режиме
echo.
pause


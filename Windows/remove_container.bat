@echo off
setlocal enabledelayedexpansion

:: When double-clicked with no arguments, prompt for container name
if "%~1"=="" (
    set /p CONTAINER_NAME=Enter container name to remove:
) else (
    set CONTAINER_NAME=%~1
)

:: Check for --verbose parameter
set "VERBOSE=0"
for %%a in (%*) do (
    if "%%a"=="--verbose" set "VERBOSE=1"
)

set PROJECT_DIR=%~dp0
set CONTAINERS_DIR=%PROJECT_DIR%containers
set DOCKER_COMPOSE_FILE=%PROJECT_DIR%docker-compose.yml
set "temp_file=%PROJECT_DIR%\docker-compose-temp.yml"

:: Remove double backslashes in paths
set "PROJECT_DIR=%PROJECT_DIR:\\=\%"
set "CONTAINERS_DIR=%CONTAINERS_DIR:\\=\%"
set "DOCKER_COMPOSE_FILE=%DOCKER_COMPOSE_FILE:\\=\%"

:: Debug output only if --verbose is passed
if "%VERBOSE%"=="1" (
    echo CONTAINER_NAME: %CONTAINER_NAME%
    echo PROJECT_DIR: %PROJECT_DIR%
    echo CONTAINERS_DIR: %CONTAINERS_DIR%
    echo DOCKER_COMPOSE_FILE: %DOCKER_COMPOSE_FILE%
    echo TEMP FILE: %temp_file%
)

:: Check if Docker is installed
where docker >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker is not installed or not in PATH
    pause
    exit /b 1
)

if not exist "%CONTAINERS_DIR%\%CONTAINER_NAME%" (
    echo ERROR: Container directory "%CONTAINERS_DIR%\%CONTAINER_NAME%" does not exist
    pause
    exit /b 1
)

if not exist "%DOCKER_COMPOSE_FILE%" (
    echo ERROR: docker-compose.yml not found at "%DOCKER_COMPOSE_FILE%"
    pause
    exit /b 1
)

:: Stop container
echo Running: docker compose -f "%DOCKER_COMPOSE_FILE%" rm -sf "%CONTAINER_NAME%"
docker compose -f "%DOCKER_COMPOSE_FILE%" rm -sf "%CONTAINER_NAME%"

:: Remove container directory
echo Removing directory: "%CONTAINERS_DIR%\%CONTAINER_NAME%"
rmdir /s /q "%CONTAINERS_DIR%\%CONTAINER_NAME%" 2>nul

:: Create empty temp file first
type nul > "%temp_file%"
if not exist "%temp_file%" (
    echo ERROR: Failed to create temp file "%temp_file%"
    pause
    exit /b 1
)

:: PRESERVING THE EXACT STRUCTURE
:: First, let's always ensure we capture the version line
findstr /R "^version:" "%DOCKER_COMPOSE_FILE%" > "%temp_file%" 2>nul

:: Now add the services: line if it's not there
findstr /R "^services:" "%DOCKER_COMPOSE_FILE%" >> "%temp_file%" 2>nul
if errorlevel 1 (
    echo services:>> "%temp_file%"
)

:: Process service definitions
set "in_service=0"
set "in_networks=0"
set "service_pattern=  %CONTAINER_NAME%:"
set "networks_pattern=networks:"

for /f "usebackq delims=" %%a in ("%DOCKER_COMPOSE_FILE%") do (
    set "line=%%a"

    :: Skip version and services lines as we've already handled them
    echo !line! | findstr /R "^version:" > nul
    if not errorlevel 1 goto continue_loop

    echo !line! | findstr /R "^services:" > nul
    if not errorlevel 1 goto continue_loop

    :: Check if we're entering our service
    echo !line! | findstr /C:"%service_pattern%" > nul
    if not errorlevel 1 (
        set "in_service=1"
        goto continue_loop
    )

    :: Check if this is networks section - skip for now
    echo !line! | findstr /C:"%networks_pattern%" > nul
    if not errorlevel 1 (
        set "in_networks=1"
        goto continue_loop
    )

    :: If we're in the service, check if we're exiting
    if "!in_service!"=="1" (
        :: Count spaces at beginning
        set "spaces=0"
        set "temp=!line!"
        :count_start
        if "!temp:~0,1!"==" " (
            set /a "spaces+=1"
            set "temp=!temp:~1!"
            goto count_start
        )

        :: If line has content and indentation is 2 or less, we've exited the service
        if "!temp!" neq "" (
            if !spaces! LEQ 2 (
                set "in_service=0"
            )
        )
    )

    :: If we're in networks section, skip it (we'll add it back later)
    if "!in_networks!"=="1" (
        goto continue_loop
    )

    :: If we're not in our service and not in networks section, copy the line
    if "!in_service!"=="0" (
        echo !line!>> "%temp_file%"
    )

    :continue_loop
)

:: Now add the networks section exactly as specified
echo networks:>> "%temp_file%"
echo   comfyui_network:>> "%temp_file%"
echo     external: true>> "%temp_file%"

:: Check if temp file is empty or has content
for %%A in ("%temp_file%") do if %%~zA==0 (
    echo ERROR: Temp file is empty. Aborting to prevent data loss.
    del "%temp_file%" 2>nul
    pause
    exit /b 1
)

:: Replace original docker-compose.yml
echo Replacing "%DOCKER_COMPOSE_FILE%" with "%temp_file%"
move /y "%temp_file%" "%DOCKER_COMPOSE_FILE%" > nul

echo Container %CONTAINER_NAME% has been removed successfully
echo.
pause
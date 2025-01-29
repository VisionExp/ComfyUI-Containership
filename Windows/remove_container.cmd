@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: remove_container.cmd ^<container_name^>
    exit /b 1
)
:: Check for --verbose parameter
set "VERBOSE=0"
for %%a in (%*) do (
    if "%%a"=="--verbose" set "VERBOSE=1"
)

set CONTAINER_NAME=%~1
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
    exit /b 1
)

if not exist "%CONTAINERS_DIR%\%CONTAINER_NAME%" (
    echo ERROR: Container directory "%CONTAINERS_DIR%\%CONTAINER_NAME%" does not exist
    exit /b 1
)

if not exist "%DOCKER_COMPOSE_FILE%" (
    echo ERROR: docker-compose.yml not found at "%DOCKER_COMPOSE_FILE%"
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
    exit /b 1
)

:: Remove service from docker-compose.yml
set "in_service=0"
set "indent_level=0"

for /f "usebackq delims=" %%a in ("%DOCKER_COMPOSE_FILE%") do (
    set "line=%%a"

    :: Check if this is the start of our service
    if "!line!"=="  %CONTAINER_NAME%:" (
        set "in_service=1"
        set "indent_level=2"
    ) else (
        :: If we're in the service, check indentation to see if we're still in it
        if "!in_service!"=="1" (
            for /f "tokens=1,* delims= " %%b in ("!line!") do (
                if "%%b" neq "" (
                    set "current_indent=0"
                    set "temp_line=!line!"
                    :count_spaces
                    if "!temp_line:~0,1!"==" " (
                        set /a "current_indent+=1"
                        set "temp_line=!temp_line:~1!"
                        goto count_spaces
                    )
                    if !current_indent! LEQ !indent_level! (
                        set "in_service=0"
                    )
                )
            )
        )

        :: If we're not in the service we want to remove, write the line
        if "!in_service!"=="0" (
            echo !line!>>"%temp_file%"
        )
    )
)

:: Check if temp file is empty or has content
for %%A in ("%temp_file%") do if %%~zA==0 (
    echo ERROR: Temp file is empty. Aborting to prevent data loss.
    del "%temp_file%" 2>nul
    exit /b 1
)

:: Replace original docker-compose.yml
echo Replacing "%DOCKER_COMPOSE_FILE%" with "%temp_file%"
move /y "%temp_file%" "%DOCKER_COMPOSE_FILE%" > nul

echo Container %CONTAINER_NAME% has been removed successfully
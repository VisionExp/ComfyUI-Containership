@echo off
setlocal enabledelayedexpansion

rem Configuration variables
set "BASE_DIR=containers"
set "SHARED_MODELS_DIR=%CD%\shared_models"
set "DOCKER_NETWORK=comfyui_network"
set "BASE_PORT=8188"
set "DOCKER_COMPOSE_FILE=docker-compose.yml"
set "TEMPLATES_DIR=templates"

rem Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please run this script as Administrator
    pause
    exit /b 1
)

rem Ensure Docker is running
docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo Docker is not running. Please start Docker Desktop.
    pause
    exit /b 1
)

rem Ensure base directory exists
if not exist "%BASE_DIR%" (
    mkdir "%BASE_DIR%" 2>nul
    if errorlevel 1 (
        echo Failed to create base directory
        exit /b 1
    )
)

rem Check for templates directory and files
if not exist "%TEMPLATES_DIR%" (
    echo Error: Templates directory not found!
    echo Required structure:
    echo  - %TEMPLATES_DIR%\dockerfile.template
    echo  - %TEMPLATES_DIR%\service.template
    echo  - %TEMPLATES_DIR%\setup.template
    pause
    exit /b 1
)

for %%f in (dockerfile service setup) do (
    if not exist "%TEMPLATES_DIR%\%%f.template" (
        echo Error: %%f.template not found in %TEMPLATES_DIR%
        pause
        exit /b 1
    )
)

rem Check if container name was provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<container_name^>
    echo Example: %~nx0 mycomfy
    pause
    exit /b 1
)

set "CONTAINER_NAME=%~1"
set "CONTAINER_PATH=%BASE_DIR%\%CONTAINER_NAME%"

rem Create shared models directory
if not exist "%SHARED_MODELS_DIR%" mkdir "%SHARED_MODELS_DIR%" 2>nul

rem Create Docker network if it doesn't exist
docker network inspect %DOCKER_NETWORK% >nul 2>&1 || (
    docker network create %DOCKER_NETWORK%
)

rem Find next available port
set /a PORT=%BASE_PORT%
for /f "tokens=1 delims=:" %%p in ('findstr /r ".*:[0-9]*:8188" "%DOCKER_COMPOSE_FILE%" 2^>nul') do (
    set "FOUND_PORT=%%p"
    set "FOUND_PORT=!FOUND_PORT:~-4!"
    if !FOUND_PORT! GTR !PORT! set /a PORT=!FOUND_PORT!+1
)

rem Create container directory structure
for %%d in (
    "%CONTAINER_PATH%"
    "%CONTAINER_PATH%\input"
    "%CONTAINER_PATH%\output"
    "%CONTAINER_PATH%\custom_nodes"
    "%CONTAINER_PATH%\scripts"
) do (
    if not exist "%%~d" mkdir "%%~d" 2>nul
)

rem Process templates
for %%t in (dockerfile service setup) do (
    set "TEMPLATE_FILE=%TEMPLATES_DIR%\%%t.template"
    if "%%t"=="dockerfile" set "OUTPUT_FILE=%CONTAINER_PATH%\Dockerfile"
    if "%%t"=="service" set "OUTPUT_FILE=temp_service.yml"
    if "%%t"=="setup" set "OUTPUT_FILE=%CONTAINER_PATH%\scripts\example_setup.sh"

    if exist "!OUTPUT_FILE!" del "!OUTPUT_FILE!" 2>nul

    for /f "delims=" %%l in ('type "!TEMPLATE_FILE!"') do (
        set "line=%%l"
        set "line=!line:{{container_name}}=%CONTAINER_NAME%!"
        set "line=!line:{{port}}=%PORT%!"
        set "line=!line:{{shared_models_dir}}=%SHARED_MODELS_DIR%!"
        set "line=!line:{{network}}=%DOCKER_NETWORK%!"
        echo !line!>>"!OUTPUT_FILE!"
    )
)

rem Update docker-compose.yml
if exist "temp_service.yml" (
    type "temp_service.yml" >> "%DOCKER_COMPOSE_FILE%"
    del "temp_service.yml" 2>nul
)

echo.
echo Container setup complete!
echo New service '%CONTAINER_NAME%' added to %DOCKER_COMPOSE_FILE%
echo Port assigned: %PORT%
echo.
echo To start all containers:
echo   docker-compose up -d --build
echo.
echo To start only this container:
echo   docker-compose up -d --build %CONTAINER_NAME%
echo.
echo Access new ComfyUI instance at http://localhost:%PORT%
echo.
echo Note: All containers are stored in: %BASE_DIR%
echo Note: All containers share models from: %SHARED_MODELS_DIR%
echo.

pause
endlocal
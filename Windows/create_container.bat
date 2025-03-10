@echo off
setlocal enabledelayedexpansion

rem Configuration variables
set "SCRIPT_DIR=%~dp0"
set "BASE_DIR=%SCRIPT_DIR%containers"
set "SHARED_MODELS_DIR=%SCRIPT_DIR%shared_models"
set "DOCKER_NETWORK=comfyui_network"
set "BASE_PORT=8188"
set "BASE_JUPYTER_PORT=8888"
set "DOCKER_COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yml"
set "TEMPLATES_DIR=%SCRIPT_DIR%templates"

rem Clear screen and show welcome message
cls
echo ComfyUI Containership 1.0.5
echo ============================
echo.

rem Get container name from user input
:get_container_name
set "CONTAINER_NAME="
set /p "CONTAINER_NAME=Please enter container name: "

if "%CONTAINER_NAME%"=="" (
    echo Container name cannot be empty. Please try again.
    echo.
    goto get_container_name
)

rem Remove special characters from container name
set "CONTAINER_NAME=%CONTAINER_NAME:"=%"
set "CONTAINER_NAME=%CONTAINER_NAME: =%"
set "CONTAINER_NAME=%CONTAINER_NAME:/=%"
set "CONTAINER_NAME=%CONTAINER_NAME:\=%"

rem Show selected name and confirm
echo.
echo Container name will be: %CONTAINER_NAME%
set /p "CONFIRM=Is this correct? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto get_container_name

set "CONTAINER_PATH=%BASE_DIR%\%CONTAINER_NAME%"

echo.
echo Creating directories...
echo Base directory: %BASE_DIR%
echo Container path: %CONTAINER_PATH%

rem Create base containers directory if it doesn't exist
if not exist "%BASE_DIR%" (
    echo Creating base directory: %BASE_DIR%
    mkdir "%BASE_DIR%"
    if errorlevel 1 (
        echo Failed to create base directory: %BASE_DIR%
        pause
        exit /b 1
    )
)

rem Check for templates directory and files
echo.
echo Checking templates...
echo Template directory: %TEMPLATES_DIR%

if not exist "%TEMPLATES_DIR%" (
    echo Error: Templates directory not found!
    echo Looking for: %TEMPLATES_DIR%
    echo.
    echo Please ensure the 'templates' folder exists in the same directory as this script
    echo with the following files:
    echo  - dockerfile.template
    echo  - service.template
    pause
    exit /b 1
)

for %%f in (dockerfile service startup) do (
    if not exist "%TEMPLATES_DIR%\%%f.template" (
        echo Error: %%f.template not found in %TEMPLATES_DIR%
        echo Please ensure all template files are present
        pause
        exit /b 1
    )
)

rem Create shared models directory
echo Creating shared models directory...
if not exist "%SHARED_MODELS_DIR%" (
    mkdir "%SHARED_MODELS_DIR%"
    echo Created: %SHARED_MODELS_DIR%
)

rem Find next available port
set /a PORT=%BASE_PORT%
if exist "%DOCKER_COMPOSE_FILE%" (
    rem Simple approach: increment port by 1 for each container
    for /f %%a in ('type "%DOCKER_COMPOSE_FILE%" ^| find /c "container_name:"') do (
        set /a PORT=%BASE_PORT% + %%a
    )
)

rem Find next available jupyter_port
set /a JUPYTER_PORT=%BASE_JUPYTER_PORT%
if exist "%DOCKER_COMPOSE_FILE%" (
    rem Simple approach: increment jupyter port by 1 for each container
    for /f %%a in ('type "%DOCKER_COMPOSE_FILE%" ^| find /c "container_name:"') do (
        set /a JUPYTER_PORT=%BASE_JUPYTER_PORT% + %%a
    )
)

echo ComfyUI port assigned: %PORT%
echo Jupyter port assigned: %JUPYTER_PORT%

rem Create container directory structure
echo.
echo Creating container directory structure...
for %%d in (
    "%CONTAINER_PATH%"
    "%CONTAINER_PATH%\input"
    "%CONTAINER_PATH%\output"
    "%CONTAINER_PATH%\custom_nodes"
    "%CONTAINER_PATH%\notebooks"
) do (
    echo Creating directory: %%~d
    mkdir "%%~d" 2>nul
    if errorlevel 1 (
        echo Failed to create directory: %%~d
        pause
        exit /b 1
    )
)

rem Process templates
echo.
echo Processing templates...
for %%t in (dockerfile service startup) do (
    set "TEMPLATE_FILE=%TEMPLATES_DIR%\%%t.template"
    if "%%t"=="dockerfile" set "OUTPUT_FILE=%CONTAINER_PATH%\Dockerfile"
    if "%%t"=="service" set "OUTPUT_FILE=temp_service.yml"
    if "%%t"=="startup" set "OUTPUT_FILE=%CONTAINER_PATH%\startup.sh"

    echo Processing template: %%t
    echo Input: !TEMPLATE_FILE!
    echo Output: !OUTPUT_FILE!

    if exist "!OUTPUT_FILE!" del "!OUTPUT_FILE!" 2>nul

    for /f "delims=" %%l in ('type "!TEMPLATE_FILE!"') do (
        set "line=%%l"
        set "line=!line:{{container_name}}=%CONTAINER_NAME%!"
        set "line=!line:{{port}}=%PORT%!"
        set "line=!line:{{jupyter_port}}=%JUPYTER_PORT%!"
        set "line=!line:{{shared_models_dir}}=%SHARED_MODELS_DIR%!"
        set "line=!line:{{network}}=%DOCKER_NETWORK%!"
        echo !line!>>"!OUTPUT_FILE!"
    )
)

rem Update docker-compose.yml
echo.
echo Updating docker-compose.yml...

rem Create temporary files
if exist "temp_service_indented.yml" del "temp_service_indented.yml"
if exist "temp_compose.yml" del "temp_compose.yml"

rem Create a new docker-compose file if it doesn't exist
if not exist "%DOCKER_COMPOSE_FILE%" (
    echo Creating new docker-compose.yml
    echo services:> "%DOCKER_COMPOSE_FILE%"
    echo networks:>> "%DOCKER_COMPOSE_FILE%"
    echo   comfyui_network:>> "%DOCKER_COMPOSE_FILE%"
    echo     external: true>> "%DOCKER_COMPOSE_FILE%"
)

rem Format the new service with proper indentation
echo   %CONTAINER_NAME%:> temp_service_indented.yml
for /f "skip=1 delims=" %%l in (temp_service.yml) do (
    set "line=%%l"
    set "indented_line=      !line!"
    echo !indented_line!>> temp_service_indented.yml
)

rem Create a temporary file with the updated content
type "%DOCKER_COMPOSE_FILE%" > temp_compose.yml

rem Find the position to insert the new service (after "services:" line)
set "insert_done="
for /f "delims=" %%a in (temp_compose.yml) do (
    if not defined insert_done (
        echo %%a > temp_compose_new.yml
        echo %%a | findstr /C:"services:" > nul
        if not errorlevel 1 (
            type temp_service_indented.yml >> temp_compose_new.yml
            set "insert_done=1"
        )
    ) else (
        echo %%a >> temp_compose_new.yml
    )
)

rem Replace the original file
move /y temp_compose_new.yml "%DOCKER_COMPOSE_FILE%" >nul

rem Clean up temporary files
if exist "temp_service.yml" del "temp_service.yml"
if exist "temp_service_indented.yml" del "temp_service_indented.yml"
if exist "temp_compose.yml" del "temp_compose.yml"

echo.
echo ============================
echo Container setup complete!
echo ============================
echo.
echo New service '%CONTAINER_NAME%' added to %DOCKER_COMPOSE_FILE%
echo Port assigned: %PORT%
echo Jupyter Port assigned: %JUPYTER_PORT%
echo.
echo Created directories:
echo - Base directory: %BASE_DIR%
echo - Container directory: %CONTAINER_PATH%
echo - Input directory: %CONTAINER_PATH%\input
echo - Output directory: %CONTAINER_PATH%\output
echo - Custom nodes directory: %CONTAINER_PATH%\custom_nodes
echo - Notebooks directory: %CONTAINER_PATH%\notebooks

echo.
echo Created files:
echo - Dockerfile: %CONTAINER_PATH%\Dockerfile
echo - Docker Compose: %DOCKER_COMPOSE_FILE%
echo - Startup script: %CONTAINER_PATH%\startup.sh
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
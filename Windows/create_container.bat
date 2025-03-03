@echo off
setlocal enabledelayedexpansion

rem Configuration variables
set "SCRIPT_DIR=%~dp0"
set "BASE_DIR=%SCRIPT_DIR%containers"
set "SHARED_MODELS_DIR=%SCRIPT_DIR%shared_models"
set "DOCKER_NETWORK=comfyui_network"
set "BASE_PORT=8188"
set "DOCKER_COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yml"
set "TEMPLATES_DIR=%SCRIPT_DIR%templates"

rem Clear screen and show welcome message
cls
echo ComfyUI Containership 1.0.0
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
    echo  - setup.template
    pause
    exit /b 1
)

for %%f in (dockerfile service setup startup) do (
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
:: Array of default folders to create inside the shared_models directory
set folders[0]=checkpoints
set folders[1]=clip
set folders[2]=clip_vision
set folders[3]=configs
set folders[4]=controlnet
set folders[4]=diffusers
set folders[4]=diffusion_models
set folders[4]=embeddings
set folders[4]=gligen
set folders[4]=hypernetworks
set folders[4]=loras
set folders[4]=photomaker
set folders[4]=style_models
set folders[4]=text_encoders
set folders[4]=unet
set folders[4]=upscale_models
set folders[4]=vae
set folders[4]=vae_approx

for /L %%i in (0,1,4) do (
    if not exist "%SHARED_MODELS_DIR%\!folders[%%i]!" (
        mkdir "%SHARED_MODELS_DIR%\!folders[%%i]!"
        echo Created: %SHARED_MODELS_DIR%\!folders[%%i]!
    ) else (
        echo Already exists: %SHARED_MODELS_DIR%\!folders[%%i]!
    )
)
rem Find next available port
set /a PORT=%BASE_PORT%
if exist "%DOCKER_COMPOSE_FILE%" (
    for /f "tokens=1 delims=:" %%p in ('findstr /r ".*:[0-9]*:8188" "%DOCKER_COMPOSE_FILE%" 2^>nul') do (
        set "FOUND_PORT=%%p"
        set "FOUND_PORT=!FOUND_PORT:~-4!"
        if !FOUND_PORT! GTR !PORT! set /a PORT=!FOUND_PORT!+1
    )
)

rem Create container directory structure
echo.
echo Creating container directory structure...
for %%d in (
    "%CONTAINER_PATH%"
    "%CONTAINER_PATH%\input"
    "%CONTAINER_PATH%\output"
    "%CONTAINER_PATH%\custom_nodes"
    "%CONTAINER_PATH%\scripts"
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
for %%t in (dockerfile service setup startup) do (
    set "TEMPLATE_FILE=%TEMPLATES_DIR%\%%t.template"
    if "%%t"=="dockerfile" set "OUTPUT_FILE=%CONTAINER_PATH%\Dockerfile"
    if "%%t"=="service" set "OUTPUT_FILE=temp_service.yml"
    if "%%t"=="setup" set "OUTPUT_FILE=%CONTAINER_PATH%\scripts\example_setup.sh"
    if "%%t"=="startup" set "OUTPUT_FILE=%CONTAINER_PATH%\startup.sh"

    echo Processing template: %%t
    echo Input: !TEMPLATE_FILE!
    echo Output: !OUTPUT_FILE!

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

rem Update docker-compose.yml with proper indentation
if exist "temp_service.yml" (
    if not exist "%DOCKER_COMPOSE_FILE%" (
        echo Creating new docker-compose.yml
        echo version: '3.3'>"%DOCKER_COMPOSE_FILE%"
        echo services:>>"%DOCKER_COMPOSE_FILE%"
    )

    echo Updating docker-compose.yml with proper indentation...

    rem Create a temporary file for the indented service
    if exist "temp_indented.yml" del "temp_indented.yml"

    rem Add indentation to each non-empty line
    for /f "delims=" %%l in (temp_service.yml) do (
        echo   %%l>>temp_indented.yml
    )

    rem Find the networks section if it exists
    set "networks_line="
    set "line_num=0"
    set "insert_line=0"

    for /f "delims=" %%l in ('type "%DOCKER_COMPOSE_FILE%"') do (
        set /a line_num+=1
        echo %%l | findstr /r "^networks:" >nul
        if not errorlevel 1 (
            set "networks_line=!line_num!"
        )
    )

    rem Create the final file
    if exist "temp_final.yml" del "temp_final.yml"

    if defined networks_line (
        rem Copy content up to networks line
        set /a insert_line=networks_line-1
        for /f "tokens=* delims=" %%a in ('type "%DOCKER_COMPOSE_FILE%"') do (
            set /a counter+=1
            if !counter! leq !insert_line! echo %%a>>temp_final.yml
        )

        rem Add the new service
        type temp_indented.yml>>temp_final.yml

        rem Add the networks section and remaining content
        set "copy_started="
        for /f "tokens=* delims=" %%a in ('type "%DOCKER_COMPOSE_FILE%"') do (
            if defined copy_started (
                echo %%a>>temp_final.yml
            ) else if "%%a" == "networks:" (
                echo %%a>>temp_final.yml
                set "copy_started=1"
            )
        )
    ) else (
        rem If no networks section, just append the service
        type "%DOCKER_COMPOSE_FILE%">temp_final.yml
        type temp_indented.yml>>temp_final.yml
    )

    rem Replace the original file
    move /y temp_final.yml "%DOCKER_COMPOSE_FILE%" >nul

    rem Clean up temporary files
    if exist "temp_service.yml" del "temp_service.yml"
    if exist "temp_indented.yml" del "temp_indented.yml"
)

echo.
echo ============================
echo Container setup complete!
echo ============================
echo.
echo New service '%CONTAINER_NAME%' added to %DOCKER_COMPOSE_FILE%
echo Port assigned: %PORT%
echo.
echo Created directories:
echo - Base directory: %BASE_DIR%
echo - Container directory: %CONTAINER_PATH%
echo - Input directory: %CONTAINER_PATH%\input
echo - Output directory: %CONTAINER_PATH%\output
echo - Custom nodes directory: %CONTAINER_PATH%\custom_nodes
echo - Scripts directory: %CONTAINER_PATH%\scripts
echo.
echo Created files:
echo - Dockerfile: %CONTAINER_PATH%\Dockerfile
echo - Setup script: %CONTAINER_PATH%\scripts\example_setup.sh
echo - Docker Compose: %DOCKER_COMPOSE_FILE%
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
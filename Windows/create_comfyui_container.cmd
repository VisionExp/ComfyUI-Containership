@echo off
setlocal enabledelayedexpansion

:: Configuration variables
set "BASE_DIR=containers"
set "SHARED_MODELS_DIR=%CD%\shared_models"
set "DOCKER_NETWORK=comfyui_network"
set "BASE_PORT=8188"
set "DOCKER_COMPOSE_FILE=docker-compose.yml"
set "TEMPLATES_DIR=templates"

:: Ensure base directory exists
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%"

:: Check for templates directory
if not exist "%TEMPLATES_DIR%" (
    echo Error: Templates directory not found!
    echo Please create '%TEMPLATES_DIR%' directory with:
    echo   - dockerfile.template
    echo   - service.template
    echo   - setup.template
    exit /b 1
)

:: Check for required template files
if not exist "%TEMPLATES_DIR%\dockerfile.template" (
    echo Error: dockerfile.template not found in %TEMPLATES_DIR%
    exit /b 1
)
if not exist "%TEMPLATES_DIR%\service.template" (
    echo Error: service.template not found in %TEMPLATES_DIR%
    exit /b 1
)
if not exist "%TEMPLATES_DIR%\setup.template" (
    echo Error: setup.template not found in %TEMPLATES_DIR%
    exit /b 1
)

:: Check if container name was provided
if "%~1"=="" (
    echo Usage: %0 ^<container_name^>
    exit /b 1
)

set "CONTAINER_NAME=%~1"
set "CONTAINER_PATH=%BASE_DIR%\%CONTAINER_NAME%"

:: Create shared models directory
if not exist "%SHARED_MODELS_DIR%" mkdir "%SHARED_MODELS_DIR%"

:: Create Docker network if it doesn't exist
docker network create %DOCKER_NETWORK% 2>nul

:: Find next available port using PowerShell
echo $content = Get-Content '%DOCKER_COMPOSE_FILE%' > find_port.ps1
echo $highest = 8188 >> find_port.ps1
echo $content ^| Select-String -Pattern "(\d+):8188" ^| ForEach-Object { >> find_port.ps1
echo     $port = [int]($_.Matches[0].Groups[1].Value) >> find_port.ps1
echo     if ($port -gt $highest) { $highest = $port } >> find_port.ps1
echo } >> find_port.ps1
echo $highest + 1 >> find_port.ps1

for /f %%i in ('powershell -ExecutionPolicy Bypass -File find_port.ps1') do set PORT=%%i
del find_port.ps1

:: Create container directory structure
if not exist "%CONTAINER_PATH%" mkdir "%CONTAINER_PATH%"
if not exist "%CONTAINER_PATH%\input" mkdir "%CONTAINER_PATH%\input"
if not exist "%CONTAINER_PATH%\output" mkdir "%CONTAINER_PATH%\output"
if not exist "%CONTAINER_PATH%\custom_nodes" mkdir "%CONTAINER_PATH%\custom_nodes"
if not exist "%CONTAINER_PATH%\scripts" mkdir "%CONTAINER_PATH%\scripts"

:: Create PowerShell script for template processing
echo $templates = @{ >> process_templates.ps1
echo     'dockerfile' = @{ >> process_templates.ps1
echo         'source' = '%TEMPLATES_DIR%\dockerfile.template'; >> process_templates.ps1
echo         'target' = '%CONTAINER_PATH%\Dockerfile' >> process_templates.ps1
echo     }; >> process_templates.ps1
echo     'setup' = @{ >> process_templates.ps1
echo         'source' = '%TEMPLATES_DIR%\setup.template'; >> process_templates.ps1
echo         'target' = '%CONTAINER_PATH%\scripts\example_setup.sh' >> process_templates.ps1
echo     }; >> process_templates.ps1
echo     'service' = @{ >> process_templates.ps1
echo         'source' = '%TEMPLATES_DIR%\service.template'; >> process_templates.ps1
echo         'target' = 'temp_service.yml' >> process_templates.ps1
echo     } >> process_templates.ps1
echo } >> process_templates.ps1
echo. >> process_templates.ps1
echo $replacements = @{ >> process_templates.ps1
echo     '{{container_name}}' = '%CONTAINER_NAME%'; >> process_templates.ps1
echo     '{{port}}' = '%PORT%'; >> process_templates.ps1
echo     '{{shared_models_dir}}' = '%SHARED_MODELS_DIR%'; >> process_templates.ps1
echo     '{{network}}' = '%DOCKER_NETWORK%' >> process_templates.ps1
echo } >> process_templates.ps1
echo. >> process_templates.ps1
echo foreach ($template in $templates.Keys) { >> process_templates.ps1
echo     $content = Get-Content $templates[$template].source -Raw >> process_templates.ps1
echo     foreach ($key in $replacements.Keys) { >> process_templates.ps1
echo         $content = $content -replace [regex]::Escape($key), $replacements[$key] >> process_templates.ps1
echo     } >> process_templates.ps1
echo     $content ^| Set-Content $templates[$template].target -NoNewline >> process_templates.ps1
echo } >> process_templates.ps1

powershell -ExecutionPolicy Bypass -File process_templates.ps1
del process_templates.ps1

powershell -ExecutionPolicy Bypass -File add_service.ps1
del temp_service.yml

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

endlocal

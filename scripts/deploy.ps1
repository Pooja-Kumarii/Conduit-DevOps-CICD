$ErrorActionPreference = "Stop"

$SourcePath = Split-Path -Parent $PSScriptRoot
$DeployPath = "C:\Conduit-Deployment"
$TaskName = "Conduit-Production"
$Port = 3002

Write-Host "Starting Conduit deployment..."

# Verify production build
if (!(Test-Path "$SourcePath\frontend\dist\index.html")) {
    throw "Production build not found."
}

# Verify production configuration
$RequiredVariables = @(
    "PROD_DB_USERNAME",
    "PROD_DB_PASSWORD",
    "PROD_DB_NAME",
    "PROD_DB_HOSTNAME",
    "PROD_DB_DIALECT",
    "JWT_KEY"
)

foreach ($Variable in $RequiredVariables) {
    if (![Environment]::GetEnvironmentVariable($Variable)) {
        throw "Missing environment variable: $Variable"
    }
}

if ($env:PROD_DB_NAME -ne "conduit_production") {
    throw "Incorrect production database."
}

# Stop previous scheduled deployment
$ExistingTask = Get-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

if ($ExistingTask) {
    Write-Host "Stopping previous deployment..."

    Stop-ScheduledTask -TaskName $TaskName

    Start-Sleep -Seconds 3
}

# Make sure the port is available
# Safely remove leftover deployed server
$Connections = Get-NetTCPConnection `
    -LocalPort $Port `
    -State Listen `
    -ErrorAction SilentlyContinue

foreach ($ProcessId in @($Connections |
    Select-Object -ExpandProperty OwningProcess -Unique)) {

    $Process = Get-CimInstance Win32_Process `
        -Filter "ProcessId=$ProcessId"

    if (
        $Process -and
        $Process.Name -eq "node.exe" -and
        $Process.CommandLine -match '(?i)\s"?C:\\Conduit-Deployment\\backend\\index\.js"?\s*$'
    ) {
        Write-Host "Stopping previous Conduit server: $ProcessId"

        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
    }
    else {
        throw "Port 3002 is occupied by an unknown process."
    }
}

Start-Sleep -Seconds 3

if (Get-NetTCPConnection -LocalPort $Port `
    -State Listen -ErrorAction SilentlyContinue) {
    throw "Deployment port is still occupied."
}

Write-Host "Deployment port is available."
# Verify deployment folder
if (!(Test-Path $DeployPath)) {
    throw "Protected deployment folder is missing."
}

# Copy application files
Write-Host "Copying application files..."

Copy-Item "$SourcePath\package.json" `
    $DeployPath -Force

Copy-Item "$SourcePath\package-lock.json" `
    $DeployPath -Force

foreach ($Folder in @("backend", "frontend")) {
    robocopy "$SourcePath\$Folder" "$DeployPath\$Folder" `
        /E /XD node_modules /XF .env ".env.*" `
        /NFL /NDL /NJH /NJS /NP

    if ($LASTEXITCODE -ge 8) {
        throw "Failed to copy $Folder."
    }
}

Copy-Item "$SourcePath\scripts\start-server.ps1" `
    "$DeployPath\start-server.ps1" -Force

# Install production dependencies
Set-Location $DeployPath

Write-Host "Installing production dependencies..."

npm.cmd ci --omit=dev

if ($LASTEXITCODE -ne 0) {
    throw "Dependency installation failed."
}

# Encrypt sensitive credentials
$EncryptedPassword = ConvertTo-SecureString `
    $env:PROD_DB_PASSWORD -AsPlainText -Force |
    ConvertFrom-SecureString

$EncryptedJWT = ConvertTo-SecureString `
    $env:JWT_KEY -AsPlainText -Force |
    ConvertFrom-SecureString

# Store protected production configuration
$Config = @{
    nodePath = (Get-Command node.exe).Source

    environment = @{
        PROD_DB_USERNAME = $env:PROD_DB_USERNAME
        PROD_DB_NAME = $env:PROD_DB_NAME
        PROD_DB_HOSTNAME = $env:PROD_DB_HOSTNAME
        PROD_DB_DIALECT = $env:PROD_DB_DIALECT
        PROD_DB_LOGGING = "false"
    }

    secrets = @{
        PROD_DB_PASSWORD = $EncryptedPassword
        JWT_KEY = $EncryptedJWT
    }
}

$Config | ConvertTo-Json -Depth 5 |
    Set-Content "$DeployPath\server-config.json" -Encoding UTF8

# Configure independent scheduled task
Write-Host "Registering production scheduled task..."

$Action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Conduit-Deployment\start-server.ps1"' `
    -WorkingDirectory $DeployPath

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Principal $Principal `
    -Settings $Settings `
    -Force | Out-Null

# Start production server independently
Write-Host "Starting independent production server..."

Start-ScheduledTask -TaskName $TaskName

# Verify deployment
$Ready = $false

for ($Attempt = 1; $Attempt -le 30; $Attempt++) {
    try {
        $Response = Invoke-WebRequest `
            -Uri "http://127.0.0.1:3002/api/articles" `
            -UseBasicParsing `
            -TimeoutSec 3

        if ($Response.StatusCode -eq 200) {
            $Ready = $true
            break
        }
    }
    catch {
        Start-Sleep -Seconds 2
    }
}

if (!$Ready) {
    Stop-ScheduledTask -TaskName $TaskName
    throw "Deployment verification failed. Check server logs."
}

Write-Host "Deployment completed successfully!"
Write-Host "Application URL: http://127.0.0.1:3002"

exit 0
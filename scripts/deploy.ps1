$ErrorActionPreference = "Stop"

$SourcePath = Split-Path -Parent $PSScriptRoot
$DeployPath = "C:\Conduit-Deployment"
$Port = 3002

Write-Host "Starting Conduit deployment..."

# Verify production build
if (!(Test-Path "$SourcePath\frontend\dist\index.html")) {
    throw "Production build not found."
}

# Verify required environment variables
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

# Check deployment port
$ExistingServer = Get-NetTCPConnection `
    -LocalPort $Port `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($ExistingServer) {
    $PidFile = "$DeployPath\server.pid"

    if (!(Test-Path $PidFile)) {
        throw "Port 3002 is occupied by an unknown application."
    }

    $SavedPid = [int](Get-Content $PidFile)

    $RunningServer = Get-CimInstance Win32_Process `
        -Filter "ProcessId=$SavedPid"

    if (
        @($ExistingServer.OwningProcess | Select-Object -Unique).Count -ne 1 -or
        $ExistingServer.OwningProcess -ne $SavedPid -or
        !$RunningServer -or
        $RunningServer.Name -ne "node.exe" -or
        $RunningServer.CommandLine -notlike "*C:\Conduit-Deployment\backend\index.js*"
    ) {
        throw "Cannot safely identify the deployed server."
    }

    Write-Host "Stopping previous Conduit deployment..."

    Stop-Process -Id $SavedPid -ErrorAction Stop

    Start-Sleep -Seconds 3

    if (Get-NetTCPConnection -LocalPort $Port `
        -State Listen -ErrorAction SilentlyContinue) {
        throw "Deployment port is still occupied."
    }
}

# Create deployment directory
New-Item -ItemType Directory `
    -Path $DeployPath -Force | Out-Null

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

# Install production dependencies
Set-Location $DeployPath

Write-Host "Installing production dependencies..."

npm.cmd ci --omit=dev

if ($LASTEXITCODE -ne 0) {
    throw "Dependency installation failed."
}

# Configure production environment
$env:NODE_ENV = "production"
$env:PORT = "$Port"
$env:HOST = "127.0.0.1"

# Prevent Jenkins from terminating the deployed process
$env:JENKINS_NODE_COOKIE = "conduit-deployed-server"

# Start production server
Write-Host "Starting production server..."

$NodePath = (Get-Command node.exe).Source

$Server = Start-Process `
    -FilePath $NodePath `
    -ArgumentList "$DeployPath\backend\index.js" `
    -WorkingDirectory "$DeployPath\backend" `
    -RedirectStandardOutput "$DeployPath\server.log" `
    -RedirectStandardError "$DeployPath\server-error.log" `
    -WindowStyle Hidden `
    -PassThru

$Server.Id | Set-Content "$DeployPath\server.pid"

Write-Host "Server process ID: $($Server.Id)"

# Verify deployed application
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
    throw "Deployment verification failed. Check server logs."
}

Write-Host "Deployment completed successfully!"
Write-Host "Application URL: http://127.0.0.1:3002"

exit 0
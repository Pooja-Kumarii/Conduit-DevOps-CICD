$ErrorActionPreference = "Stop"

$DeployPath = "C:\Conduit-Deployment"

# Load protected production configuration
$Config = Get-Content "$DeployPath\server-config.json" -Raw |
    ConvertFrom-Json

foreach ($Property in $Config.environment.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable(
        $Property.Name,
        [string]$Property.Value,
        "Process"
    )
}

# Decrypt credentials
foreach ($Name in @("PROD_DB_PASSWORD", "JWT_KEY")) {
    $Encrypted = $Config.secrets.$Name
    $Secure = ConvertTo-SecureString $Encrypted

    $Credential = New-Object System.Net.NetworkCredential(
        "",
        $Secure
    )

    [Environment]::SetEnvironmentVariable(
        $Name,
        $Credential.Password,
        "Process"
    )
}

$env:NODE_ENV = "production"
$env:PORT = "3002"
$env:HOST = "127.0.0.1"

Set-Location "$DeployPath\backend"

& $Config.nodePath "$DeployPath\backend\index.js" `
    >> "$DeployPath\server.log" `
    2>> "$DeployPath\server-error.log"

exit $LASTEXITCODE
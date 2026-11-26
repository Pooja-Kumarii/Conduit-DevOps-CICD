$ErrorActionPreference = "Stop"

$DeployPath = "C:\Conduit-Deployment"

try {
    $Config = Get-Content "$DeployPath\server-config.json" -Raw |
        ConvertFrom-Json

    foreach ($Property in $Config.environment.PSObject.Properties) {
        [Environment]::SetEnvironmentVariable(
            $Property.Name,
            [string]$Property.Value,
            "Process"
        )
    }

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

    Add-Content "$DeployPath\startup.log" `
        "$(Get-Date -Format s) Starting Node.js server"

    $Server = Start-Process `
        -FilePath $Config.nodePath `
        -ArgumentList "$DeployPath\backend\index.js" `
        -WorkingDirectory "$DeployPath\backend" `
        -RedirectStandardOutput "$DeployPath\server.log" `
        -RedirectStandardError "$DeployPath\server-error.log" `
        -PassThru -Wait

    Add-Content "$DeployPath\startup.log" `
        "$(Get-Date -Format s) Node exit code: $($Server.ExitCode)"

    exit $Server.ExitCode
}
catch {
    Add-Content "$DeployPath\startup.log" `
        "$(Get-Date -Format s) Startup failed: $($_.Exception.GetType().FullName)"

    exit 1
}
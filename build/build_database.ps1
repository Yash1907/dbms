param(
    [Parameter(Mandatory = $true)] [string] $Owner,
    [Parameter(Mandatory = $true)] [string] $Repository,
    [Parameter(Mandatory = $true)] [string] $VersionTag,
    [string] $TargetDatabase = "koha_lite"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($TargetDatabase -ne "koha_lite") {
    throw "This release grants privileges on the documented database name 'koha_lite'. Use -TargetDatabase koha_lite."
}

foreach ($variableName in @("DB_HOST", "DB_ADMIN_USER", "DB_ADMIN_PASSWORD")) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variableName))) {
        throw "Required environment variable is missing: $variableName"
    }
}

foreach ($commandName in @("git", "mysql")) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $commandName"
    }
}

$dbHostName = $env:DB_HOST
$dbPortNumber = if ($env:DB_PORT) { $env:DB_PORT } else { "3306" }
$dbAdminUser = $env:DB_ADMIN_USER
$dbAdminPassword = $env:DB_ADMIN_PASSWORD
$runId = "$(Get-Date -AsUTC -Format 'yyyyMMddTHHmmssZ')-$VersionTag"
$workDirectory = Join-Path (Get-Location) ".build-work\$Repository-$runId"
$repositoryDirectory = Join-Path $workDirectory "repo"
$logDirectory = Join-Path $workDirectory "logs"
$buildLog = Join-Path $logDirectory "build.log"
$errorLog = Join-Path $logDirectory "error.log"
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

function Write-BuildLog([string] $Message) {
    $line = "$(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') | $Message"
    $line | Tee-Object -FilePath $buildLog -Append
}

function Invoke-MySqlCommand([string] $Sql, [string] $Database = "") {
    $arguments = @(
        "--protocol=TCP", "--host=$dbHostName", "--port=$dbPortNumber",
        "--user=$dbAdminUser", "--show-warnings", "--execute=$Sql"
    )
    if ($Database) { $arguments += "--database=$Database" }
    $env:MYSQL_PWD = $dbAdminPassword
    & mysql @arguments 2>> $errorLog
    if ($LASTEXITCODE -ne 0) { throw "MySQL command failed." }
}

function Invoke-MySqlFile([string] $ScriptPath, [string] $Database) {
    $env:MYSQL_PWD = $dbAdminPassword
    $arguments = @(
        "--protocol=TCP", "--host=$dbHostName", "--port=$dbPortNumber",
        "--user=$dbAdminUser", "--database=$Database", "--show-warnings",
        "--binary-mode", "--execute=source $($ScriptPath.Replace('\', '/'))"
    )
    & mysql @arguments 2>> $errorLog | Tee-Object -FilePath $buildLog -Append
    if ($LASTEXITCODE -ne 0) { throw "SQL script failed: $ScriptPath" }
}

try {
    Write-BuildLog "Starting KOHA-Lite build for tag=$VersionTag database=$TargetDatabase"
    Invoke-MySqlCommand "SELECT VERSION();"

    $repositoryUrl = "https://github.com/$Owner/$Repository.git"
    if ($env:GITHUB_TOKEN) {
        $repositoryUrl = "https://x-access-token:$($env:GITHUB_TOKEN)@github.com/$Owner/$Repository.git"
    }

    & git clone --quiet --no-checkout $repositoryUrl $repositoryDirectory 2>> $errorLog
    if ($LASTEXITCODE -ne 0) { throw "Git clone failed." }
    & git -C $repositoryDirectory fetch --quiet --depth 1 origin "refs/tags/$VersionTag`:refs/tags/$VersionTag" 2>> $errorLog
    if ($LASTEXITCODE -ne 0) { throw "Requested tag could not be fetched: $VersionTag" }
    & git -C $repositoryDirectory checkout --quiet --detach "refs/tags/$VersionTag" 2>> $errorLog
    if ($LASTEXITCODE -ne 0) { throw "Requested tag could not be checked out: $VersionTag" }

    $resolvedTag = (& git -C $repositoryDirectory describe --exact-match --tags HEAD).Trim()
    $commitSha = (& git -C $repositoryDirectory rev-parse HEAD).Trim()
    if ($resolvedTag -ne $VersionTag) { throw "Resolved source is not exactly tag $VersionTag." }
    Write-BuildLog "Verified tag=$resolvedTag commit=$commitSha"

    $manifest = Join-Path $repositoryDirectory "database\manifest.txt"
    if (-not (Test-Path -LiteralPath $manifest)) { throw "Missing database manifest." }
    $sqlFiles = Get-Content -LiteralPath $manifest | Where-Object {
        $_.Trim() -and -not $_.Trim().StartsWith("#")
    }
    if ($sqlFiles.Count -eq 0) { throw "Build manifest is empty." }
    foreach ($relativePath in $sqlFiles) {
        $scriptPath = Join-Path $repositoryDirectory $relativePath.Trim()
        if (-not (Test-Path -LiteralPath $scriptPath)) {
            throw "Manifest references a missing script: $relativePath"
        }
    }

    $existenceSql = "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$TargetDatabase';"
    $env:MYSQL_PWD = $dbAdminPassword
    $databaseExists = (& mysql --protocol=TCP "--host=$dbHostName" "--port=$dbPortNumber" "--user=$dbAdminUser" --batch --skip-column-names "--execute=$existenceSql").Trim()
    if ($databaseExists -eq "1") {
        if ($env:ALLOW_DATABASE_RECREATE -ne "YES") {
            throw "Database '$TargetDatabase' exists. Set ALLOW_DATABASE_RECREATE=YES only for intentional replacement."
        }
        Write-BuildLog "Dropping existing target database after explicit opt-in."
        Invoke-MySqlCommand "DROP DATABASE ``$TargetDatabase``;"
    }

    Invoke-MySqlCommand "CREATE DATABASE ``$TargetDatabase`` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
    foreach ($relativePath in $sqlFiles) {
        $scriptPath = Join-Path $repositoryDirectory $relativePath.Trim()
        Write-BuildLog "Executing $relativePath"
        Invoke-MySqlFile -ScriptPath $scriptPath -Database $TargetDatabase
        Write-BuildLog "Succeeded: $relativePath"
    }

    $verificationSql = "SELECT CONCAT('tables=', COUNT(*)) FROM information_schema.tables WHERE table_schema='$TargetDatabase' AND table_type='BASE TABLE';"
    Invoke-MySqlCommand $verificationSql $TargetDatabase
    Write-BuildLog "BUILD SUCCEEDED tag=$resolvedTag commit=$commitSha database=$TargetDatabase"
}
catch {
    Write-BuildLog "BUILD FAILED: $($_.Exception.Message)"
    Add-Content -LiteralPath $errorLog -Value "$(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') | $($_.Exception.Message)"
    exit 1
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}


Set-Location $PSScriptRoot

$originalFilePath = "errshowcloner.lua"

$versionLine = Get-Content -Path $originalFilePath | Select-String -Pattern '^local VERSION'
$version = $versionLine -replace '.*"(.*)".*', '$1'

$username = Read-Host "Enter your username"

if (-not $version) {
    Write-Error "Version not found in errshowcloner.lua"
    exit 1
}

if (-not $username) {
    Write-Error "Username is not set"
    exit 1
}

(Get-Content -Path $originalFilePath) -replace 'local name = ".*"', "local name = '$username'" | Set-Content -Path $originalFilePath

$currentDate = Get-Date -Format "yyyyMMdd"
$outputDir = "./deliver/$version/${username}_$currentDate"

if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$outputFileName = "${username}_errshowcloner_${version}.lua"
$outputFilePath = Join-Path -Path $outputDir -ChildPath $outputFileName

Write-Host "Running Lua script to generate output..."

& lua ".\obfuscation_stuff\src\cli.lua" --preset Minify $originalFilePath --o $outputFilePath

if (Test-Path -Path $outputFilePath) {
    Write-Host "Output file created: $outputFilePath"
} else {
    Write-Error "Failed to create output file."
}
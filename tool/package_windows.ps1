param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$versionMatch = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$'
if ($null -eq $versionMatch) {
    throw 'Could not read the application version from pubspec.yaml.'
}
$version = $versionMatch.Matches[0].Groups[1].Value

Push-Location $projectRoot
try {
    if (-not $SkipBuild) {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter Windows build failed with exit code $LASTEXITCODE."
        }
    }

    $releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath (Join-Path $releaseDirectory 'lapse.exe'))) {
        throw "Release build not found at $releaseDirectory."
    }

    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $stagingDirectory = Join-Path $temporaryRoot ("lapse-package-{0}" -f [guid]::NewGuid())
    New-Item -ItemType Directory -Path $stagingDirectory | Out-Null

    try {
        Copy-Item -Path (Join-Path $releaseDirectory '*') -Destination $stagingDirectory -Recurse

        $runtimeNames = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
        $runtimeDirectories = [System.Collections.Generic.List[string]]::new()
        if ($env:VCToolsRedistDir) {
            $runtimeDirectories.Add((Join-Path $env:VCToolsRedistDir 'x64\Microsoft.VC143.CRT'))
        }

        $vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path -LiteralPath $vswherePath) {
            $visualStudioRoot = & $vswherePath -latest -products '*' -property installationPath
            if ($visualStudioRoot) {
                $redistRoot = Join-Path $visualStudioRoot 'VC\Redist\MSVC'
                if (Test-Path -LiteralPath $redistRoot) {
                    Get-ChildItem -LiteralPath $redistRoot -Directory |
                        Sort-Object Name -Descending |
                        ForEach-Object {
                            $runtimeDirectories.Add((Join-Path $_.FullName 'x64\Microsoft.VC143.CRT'))
                        }
                }
            }
        }

        $runtimeDirectory = $runtimeDirectories | Where-Object {
            $candidate = $_
            @($runtimeNames | Where-Object {
                -not (Test-Path -LiteralPath (Join-Path $candidate $_))
            }).Count -eq 0
        } | Select-Object -First 1

        if (-not $runtimeDirectory) {
            throw 'Visual C++ x64 runtime DLLs were not found in the Visual Studio installation.'
        }
        foreach ($runtimeName in $runtimeNames) {
            Copy-Item -LiteralPath (Join-Path $runtimeDirectory $runtimeName) -Destination $stagingDirectory
        }

        $distDirectory = Join-Path $projectRoot 'dist'
        New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
        $archiveName = "lapse-windows-x64-v$version.zip"
        $archivePath = Join-Path $distDirectory $archiveName
        Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal -Force

        $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $checksumPath = "$archivePath.sha256"
        [System.IO.File]::WriteAllText($checksumPath, "$hash  $archiveName`n")

        Write-Host "Created $archivePath"
        Write-Host "Created $checksumPath"
    }
    finally {
        $resolvedStaging = [System.IO.Path]::GetFullPath($stagingDirectory)
        if ($resolvedStaging.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedStaging -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Pop-Location
}

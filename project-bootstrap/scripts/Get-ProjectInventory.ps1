param(
    [string]$ProjectRoot = ".",
    [int]$MaxFiles = 2000
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path $ProjectRoot

$ExcludeDirNames = @(
    ".git",
    ".gradle",
    ".idea",
    ".vscode",
    "target",
    "build",
    "out",
    "node_modules",
    "dist",
    "coverage"
)

$SensitivePatterns = @(
    ".env",
    "*.jks",
    "*.p12",
    "*.key",
    "*.pem",
    "*.cer",
    "*.crt",
    "*.der",
    "*.keystore",
    "*password*",
    "*passwd*",
    "*secret*",
    "*token*",
    "*credential*",
    "application-prod*",
    "application-real*",
    "application-prd*",
    "application-live*"
)

$AllowedExtensions = @(
    ".java",
    ".xml",
    ".yml",
    ".yaml",
    ".properties",
    ".gradle",
    ".md",
    ".sql",
    ".json"
)

function Test-IsExcludedPath {
    param([string]$Path)

    $parts = $Path -split "[\\/]"
    foreach ($part in $parts) {
        if ($ExcludeDirNames -contains $part) {
            return $true
        }
    }

    foreach ($pattern in $SensitivePatterns) {
        if ([System.IO.Path]::GetFileName($Path) -like $pattern) {
            return $true
        }
    }

    return $false
}

$BuildFiles = @()
foreach ($name in @("pom.xml", "build.gradle", "settings.gradle", "gradle.properties", "README.md", "QWEN.md", ".gitignore", ".qwenignore")) {
    $p = Join-Path $Root $name
    if (Test-Path $p) {
        $BuildFiles += $name
    }
}

$AllFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        -not (Test-IsExcludedPath $_.FullName) -and
        ($AllowedExtensions -contains $_.Extension -or $_.Name -in @("pom.xml", "build.gradle", "settings.gradle", "README.md", "QWEN.md"))
    } |
    Select-Object -First $MaxFiles

$JavaFiles = $AllFiles | Where-Object { $_.Extension -eq ".java" }
$XmlFiles = $AllFiles | Where-Object { $_.Extension -eq ".xml" }
$ConfigFiles = $AllFiles | Where-Object { $_.Extension -in @(".yml", ".yaml", ".properties") }

$Controllers = $JavaFiles | Where-Object { $_.Name -match "Controller\.java$|RestController\.java$" }
$Services = $JavaFiles | Where-Object { $_.Name -match "Service\.java$|ServiceImpl\.java$|Biz\.java$|Manager\.java$" }
$Mappers = $JavaFiles | Where-Object { $_.Name -match "Mapper\.java$|Repository\.java$|Dao\.java$|DAO\.java$" }
$Tests = $JavaFiles | Where-Object { $_.FullName -match "[\\/]test[\\/]" }

$TopDirs = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $ExcludeDirNames -notcontains $_.Name } |
    Select-Object -ExpandProperty Name

$PackageSamples = $JavaFiles |
    Select-Object -First 200 |
    ForEach-Object {
        try {
            $line = Get-Content $_.FullName -TotalCount 20 -ErrorAction SilentlyContinue |
                Where-Object { $_ -match "^\s*package\s+" } |
                Select-Object -First 1
            if ($line) {
                ($line -replace "^\s*package\s+", "" -replace ";\s*$", "").Trim()
            }
        } catch {
        }
    } |
    Where-Object { $_ } |
    Sort-Object -Unique |
    Select-Object -First 50

$result = [ordered]@{
    projectRoot = $Root.Path
    checkedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    buildFiles = $BuildFiles
    topDirectories = $TopDirs
    counts = [ordered]@{
        totalScannedFiles = @($AllFiles).Count
        javaFiles = @($JavaFiles).Count
        xmlFiles = @($XmlFiles).Count
        configFiles = @($ConfigFiles).Count
        controllers = @($Controllers).Count
        services = @($Services).Count
        mappers = @($Mappers).Count
        tests = @($Tests).Count
    }
    packageSamples = $PackageSamples
    controllerSamples = @($Controllers | Select-Object -First 30 | ForEach-Object { Resolve-Path $_.FullName -Relative })
    serviceSamples = @($Services | Select-Object -First 30 | ForEach-Object { Resolve-Path $_.FullName -Relative })
    mapperSamples = @($Mappers | Select-Object -First 30 | ForEach-Object { Resolve-Path $_.FullName -Relative })
    xmlSamples = @($XmlFiles | Select-Object -First 30 | ForEach-Object { Resolve-Path $_.FullName -Relative })
    configSamples = @($ConfigFiles | Select-Object -First 30 | ForEach-Object { Resolve-Path $_.FullName -Relative })
}

$result | ConvertTo-Json -Depth 20

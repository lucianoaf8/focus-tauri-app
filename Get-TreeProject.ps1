# Get-ProjectTree.ps1
# Auto-detects project root (current working directory), excludes .gitignore patterns,
# flags empty files/folders, and reproduces original console + markdown output format.

param(
    [string]$OutputFile = "project_structure.md",
    [switch]$OpenFile = $false
)

# ----------------------------------------------------------------------------
# 1. Determine project root ---------------------------------------------------
# ----------------------------------------------------------------------------
$ProjectPath = (Get-Location).ProviderPath
if (-not $ProjectPath -or -not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Write-Error "Project path does not exist or is not accessible: $ProjectPath"
    exit 1
}

# ----------------------------------------------------------------------------
# 2. Exclusion patterns (mirrors .gitignore + custom) -------------------------
# ----------------------------------------------------------------------------
$ExclusionPatterns = @(
    # Python artefacts
    '__pycache__','*.pyc','*.pyo','*.pyd','*.so','.Python',
    'build','develop-eggs','dist','downloads','eggs','.eggs','lib','lib64','parts','sdist','var','wheels','share',
    '*.egg-info','.installed.cfg','*.egg','MANIFEST',
    # PyInstaller
    '*.manifest','*.spec',
    # Testing
    'htmlcov','.tox','.nox','.coverage','.coverage.*','.cache','nosetests.xml','coverage.xml','*.cover','*.py,cover',
    '.hypothesis','.pytest_cache','cover',
    # Virtual envs
    '.env','.venv','env','venv','ENV','env.bak','venv.bak','.conda','conda-meta',
    # IDE/editor configs
    '.vscode','.idea','*.swp','*.swo','*~','.project','.pydevproject','.settings','*.sublime-project','*.sublime-workspace',
    '.spyderproject','.spyproject','.ropeproject',
    # OS‑generated junk
    '.DS_Store','.DS_Store?','._*','.Spotlight-V100','.Trashes','ehthumbs.db','Thumbs.db','desktop.ini','Desktop.ini',
    # Data / DB
    'data','*.db','*.sqlite','*.sqlite3','orchestrator.db',
    # Logs
    'logs','*.log','*.log.*','log',
    # Spreadsheets / CSV
    '*.xlsx','*.xls','*.csv','*_data_*.xlsx','totango_*.xlsx','citus_*.xlsx','monthly_report_*.xlsx',
    # Configs with secrets
    '.env.local','.env.*.local','config.ini','config.yaml','config.yml','secrets.json','credentials.json',
    # Back‑ups / temps
    '*.bak','*.backup','*.tmp','*.temp',
    # Temp folders
    'downloads','temp','tmp',
    # Mail configs
    'email_config.json','smtp_config.ini',
    # Certificates
    '*.pem','*.key','*.crt','*.cert','*.p12','*.pfx',
    # Jupyter
    '.ipynb_checkpoints',
    # Flask instance cache
    'instance','.webassets-cache',
    # Sphinx & MkDocs builds
    'docs/_build','/site',
    # Type‑checker caches
    '.mypy_cache','.dmypy.json','dmypy.json','.pyre','.pytype','cython_debug',
    # Node / JS
    'node_modules','npm-debug.log*','yarn-debug.log*','yarn-error.log*',
    # Lock files
    'Pipfile.lock','poetry.lock',
    # .env variants
    '.env.production','.env.development','.env.test',
    # PID & state
    '*.pid','pids','*.seed','*.pid.lock',
    # Local‑only configs
    'local_config.py','local_settings.py','dev_config.py',
    # Task outputs
    'reports','output','exports',
    # macOS
    '.AppleDouble','.LSOverride','Icon','.DocumentRevisions-V100','.fseventsd','.TemporaryItems','.VolumeIcon.icns','.com.apple.timemachine.donotpresent',
    # Linux
    '.fuse_hidden*','.directory','.Trash-*','.nfs*',
    # Archives
    '*.zip','*.tar.gz','*.rar','*.7z',
    # Workspace & caches
    '*.code-workspace','.history','.npm','.eslintcache','.rpt2_cache','.rts2_cache_cjs','.rts2_cache_es','.rts2_cache_umd',
    '.node_repl_history','*.tgz','.yarn-integrity','.vscode-test',
    # Project‑specific extras
    'encrypted_credentials','*.encrypted','task_outputs','execution_logs','vpn_status.cache','email_queue','email_temp',
    '*.db.backup','database_backups','test_data','sample_data','perf_logs','*.perf','*.lock','task_locks',
    '*_simulator.py','*_demo.py','demo_*','simulation_*',
    # Misc
    '.claude','claude.md','docs','linven','.git','.windsurf'
)

# ----------------------------------------------------------------------------
# 3. Helper: Should this path be excluded? ------------------------------------
# ----------------------------------------------------------------------------
function Test-ShouldExclude {
    param(
        [string]$Path,
        [string]$Name
    )
    
    foreach ($pattern in $ExclusionPatterns) {
        # exact filename/dir match
        if ($Name -eq $pattern) { return $true }
        
        # wildcard pattern match
        if ($pattern.Contains('*') -or $pattern.Contains('?')) {
            if ($Name -like $pattern) { return $true }
        }
        
        # directory substring match
        $pathSeparator = [System.IO.Path]::DirectorySeparatorChar
        if ($Path -match [regex]::Escape("$pathSeparator$pattern$pathSeparator") -or 
            $Path -match [regex]::Escape("$pathSeparator$pattern") + '$') { 
            return $true 
        }
        
        # patterns that start with '/' (e.g. '/site')
        if ($pattern.StartsWith('/')) {
            $sub = $pattern.Substring(1)
            if ($Path -match [regex]::Escape("$pathSeparator$sub$pathSeparator") -or
                $Path -match [regex]::Escape("$pathSeparator$sub") + '$') { 
                return $true 
            }
        }
    }
    return $false
}

# ----------------------------------------------------------------------------
# 4. Helper: Icon per file type ----------------------------------------------
# ----------------------------------------------------------------------------
function Get-FileIcon {
    param(
        [string]$Extension,
        [bool]$IsContainer
    )
    
    if ($IsContainer) { return "[DIR] " }
    
    switch -Regex ($Extension) {
        '\.py$'        { return "[PY]  " }
        '\.md$'        { return "[MD]  " }
        '\.json$'      { return "[JSON]" }
        '\.ya?ml$'     { return "[YAML]" }
        '\.txt$'       { return "[TXT] " }
        '\.html?$'     { return "[HTML]" }
        '\.jsx?$'      { return "[JS]  " }
        '\.css$'       { return "[CSS] " }
        '\.(bat|ps1)$' { return "[SCRIPT]" }
        '\.toml$'      { return "[TOML]" }
        '\.ini$'       { return "[INI] " }
        '\.cfg$'       { return "[CFG] " }
        '\.sql$'       { return "[SQL] " }
        default        { return "[FILE]" }
    }
}

# ----------------------------------------------------------------------------
# 5. Recursive tree builder ---------------------------------------------------
# ----------------------------------------------------------------------------
function Get-TreeStructure {
    param(
        [string]$Path,
        [string]$Prefix = "",
        [int]$Level = 0
    )
    
    $items = @()
    
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $items }

        $all = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
               Where-Object { -not (Test-ShouldExclude -Path $_.FullName -Name $_.Name) } |
               Sort-Object @{Expression={$_.PSIsContainer};Descending=$true}, Name

        foreach ($item in $all) {
            $connector = "|-- "
            $newPrefix = "$Prefix|   "

            # Detect emptiness
            $isEmpty = $false
            if ($item.PSIsContainer) {
                $kids = @(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue |
                         Where-Object { -not (Test-ShouldExclude -Path $_.FullName -Name $_.Name) })
                if ($kids.Count -eq 0) { $isEmpty = $true }
            } else {
                try {
                    if ($null -ne $item.Length -and $item.Length -eq 0) { $isEmpty = $true }
                } catch {
                    # Some items might not have a Length property
                }
            }

            $name = if ($isEmpty) { "(empty) $($item.Name)" } else { $item.Name }
            $icon = Get-FileIcon -Extension $item.Extension -IsContainer $item.PSIsContainer
            $items += "$Prefix$connector$icon$name"

            if ($item.PSIsContainer -and $Level -lt 10) {
                $subItems = Get-TreeStructure -Path $item.FullName -Prefix $newPrefix -Level ($Level + 1)
                if ($subItems) {
                    $items += $subItems
                }
            }
        }
    } catch {
        Write-Warning "Error processing $Path : $($_.Exception.Message)"
    }
    
    return $items
}

# ----------------------------------------------------------------------------
# 6. Generate tree ------------------------------------------------------------
# ----------------------------------------------------------------------------
$projectName = Split-Path $ProjectPath -Leaf
$rootLine = "[ROOT] $projectName"
$treeLines = @(Get-TreeStructure -Path $ProjectPath)

# Build markdown with 6‑backtick fences (matches original)
$md = @()
$md += "# Project Structure: $projectName"
$md += ""
$md += '``````'
$md += $rootLine
$md += $treeLines
$md += '``````'
$md += ""
$md += "## Summary"
$md += ""
$md += "- **Total Items Displayed**: $($treeLines.Count)"
$md += "- **Project Root**: ``$ProjectPath``"
$markdownContent = $md -join "`n"

# ----------------------------------------------------------------------------
# 7. Console output -----------------------------------------------------------
# ----------------------------------------------------------------------------
Write-Host "`nPROJECT STRUCTURE" -ForegroundColor Green
Write-Host ('=' * 50) -ForegroundColor Gray
Write-Host $rootLine
$treeLines | ForEach-Object { Write-Host $_ }
Write-Host ('=' * 50) -ForegroundColor Gray
Write-Host "Total items: $($treeLines.Count)" -ForegroundColor Yellow

# ----------------------------------------------------------------------------
# 8. Save markdown ------------------------------------------------------------
# ----------------------------------------------------------------------------
$outputPath = Join-Path -Path $ProjectPath -ChildPath $OutputFile
try {
    # Use UTF8 encoding without BOM if supported
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $markdownContent | Out-File -FilePath $outputPath -Encoding UTF8NoBOM
    } else {
        $markdownContent | Out-File -FilePath $outputPath -Encoding UTF8
    }
    Write-Host "Structure saved to: $outputPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to save file: $($_.Exception.Message)"
    exit 1
}

# ----------------------------------------------------------------------------
# 9. Optional: open file ------------------------------------------------------
# ----------------------------------------------------------------------------
if ($OpenFile) {
    try {
        Invoke-Item $outputPath
    } catch {
        Write-Warning "Could not open file: $($_.Exception.Message)"
    }
} else {
    $resp = Read-Host "Open the generated file? (y/N)"
    if ($resp -match '^[Yy]$') {
        try {
            Invoke-Item $outputPath
        } catch {
            Write-Warning "Could not open file: $($_.Exception.Message)"
        }
    }
}

Write-Host "`nTree generation complete!" -ForegroundColor Green
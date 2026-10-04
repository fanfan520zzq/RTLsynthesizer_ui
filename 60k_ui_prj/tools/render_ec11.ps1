param(
    [string]$ModelsimHome = 'D:\altera\14.1\modelsim_ase\win32aloem',
    [string]$Python = ''
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if (-not $Python) { $Python=Join-Path (Split-Path -Parent $projectRoot) 'verilogQT/.venv/Scripts/python.exe' }
$simDir=Join-Path $projectRoot 'sim'
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
Push-Location $simDir
try {
    & "$ModelsimHome\vlib.exe" work
    & "$ModelsimHome\vlog.exe" -sv -work work "$projectRoot\rtl\ui_ec11_scene.v" "$projectRoot\tests\tb_ec11_render.v"
    if ($LASTEXITCODE -ne 0) { throw 'render compile failed' }
    & "$ModelsimHome\vsim.exe" -c work.tb_ec11_render -do 'run -all; quit -f' 2>&1 | Tee-Object -FilePath render.log
    $renderResult=Get-Content render.log -Raw
    if ($LASTEXITCODE -ne 0 -or $renderResult -notmatch 'PASS tb_ec11_render' -or $renderResult -match '\*\* (Error|Fatal)') { throw 'RTL render failed' }
    & $Python "$projectRoot\tools\preview_to_png.py"
    if ($LASTEXITCODE -ne 0) { throw 'preview conversion failed' }
} finally { Pop-Location }

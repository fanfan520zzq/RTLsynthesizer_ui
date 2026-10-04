param(
    [string]$ModelsimHome = 'D:\altera\14.1\modelsim_ase\win32aloem',
    [string]$GowinHome = 'D:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$simDir = Join-Path $projectRoot 'sim'
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
Push-Location $simDir
try {
    & "$ModelsimHome\vlib.exe" work
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    $sources = @(
        "$GowinHome\simlib\gw5a\prim_sim.v",
        "$projectRoot\rtl\TMDS_PLL.v",
        "$projectRoot\rtl\video_timing_ctrl.v",
        "$projectRoot\rtl\ec11_decoder.v",
        "$projectRoot\rtl\ui_ec11_controller.v",
        "$projectRoot\rtl\ui_ec11_scene.v",
        "$projectRoot\tests\tb_panel_pll.v",
        "$projectRoot\tests\tb_panel_timing.v",
        "$projectRoot\tests\tb_ec11_controls.v",
        "$projectRoot\tests\tb_ec11_input.v",
        "$projectRoot\tests\tb_ec11_font.v",
        "$projectRoot\tests\tb_ec11_scene.v"
    )
    & "$ModelsimHome\vlog.exe" -sv -work work @sources 2>&1 | Tee-Object -FilePath compile.log
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    foreach ($test in @('tb_panel_pll','tb_panel_timing','tb_ec11_controls','tb_ec11_input','tb_ec11_font','tb_ec11_scene')) {
        $log = Join-Path $simDir "$test.log"
        & "$ModelsimHome\vsim.exe" -c "work.$test" -do 'run -all; quit -f' 2>&1 | Tee-Object -FilePath $log
        if ($LASTEXITCODE -ne 0) { throw "$test failed" }
        $result = Get-Content -LiteralPath $log -Raw
        if ($result -notmatch "PASS $test" -or $result -match '\*\* (Error|Fatal)') {
            throw "$test did not pass; see $log"
        }
    }
    Write-Host 'EC11_UI_RTL_PASS tests=6'
} finally { Pop-Location }

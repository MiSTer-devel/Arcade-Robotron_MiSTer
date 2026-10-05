param(
    [string]$RomDirectory,
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'robotron-blaster-tests'),
    [string]$Python = 'python',
    [switch]$Boot,
    [int]$Frames = 2200
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
if ($output.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $output -eq $repo) {
    throw 'Keep simulation output outside the checkout'
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
if ($RomDirectory) {
    & $Python (Join-Path $PSScriptRoot 'prepare_roms.py') $RomDirectory $output
    if ($LASTEXITCODE -ne 0) { throw 'ROM preparation failed' }
}

Push-Location $output
try {
    if (-not (Test-Path 'work')) {
        & vlib work
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    }
    & vmap work work
    if ($LASTEXITCODE -ne 0) { throw 'vmap failed' }
    $speech = Get-Content (Join-Path $repo 'rtl/hc55564.vhd') -Raw
    $speech = [regex]::Replace($speech, 'unsigned\(std_logic_vector\(\s*resize\(v_intfilter xor to_signed\(16#200#,\s*10\),\s*10\)\s*\)\)\(9 downto 4\)', 'unsigned(v_intfilter(9 downto 4)) xor "100000"')
    Set-Content 'hc55564.vhd' $speech
    $files = @(
        'rtl/dpram.vhd', 'tests/dpram_model.vhd',
        'rtl/gen_ram.vhd', 'tests/gen_ram_model.vhd',
        'rtl/CEGen.vhd', 'rtl/cpu68.vhd', 'rtl/pia6821.vhd',
        'rtl/sc1.vhd', 'rtl/williams_rom.vhd', 'rtl/williams_ram.vhd',
        'rtl/williams_audio.vhd'
    )
    foreach ($file in $files) {
        & vcom -2008 -work work (Join-Path $repo $file)
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $file" }
    }
    & vcom -2008 -work work 'hc55564.vhd'
    if ($LASTEXITCODE -ne 0) { throw 'Speech model compilation failed' }
    foreach ($file in @('rtl/williams_sound_board.vhd', 'rtl/williams_cpu.vhd')) {
        & vcom -2008 -work work (Join-Path $repo $file)
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $file" }
    }
    & vlog -sv -work work (Join-Path $repo 'rtl/mc6809is.v')
    if ($LASTEXITCODE -ne 0) { throw 'CPU compilation failed' }
    $tests = @('blaster_rom_tb', 'blaster_sc1_tb', 'blaster_audio_tb', 'blaster_sound_tb')
    Set-Content 'run.do' @'
onerror {quit -code 1}
onbreak {quit -code 1}
set NumericStdNoWarnings 1
set StdArithNoWarnings 1
run -all
quit -code 1
'@
    if (Test-Path 'blasterkit.hex') { $tests += @('blaster_board_tb', 'blaster_sound_rom_tb') }
    if ($Boot) {
        if (-not (Test-Path 'blasterkit.hex')) { throw 'Boot tests require ROMs' }
        $tests += 'blaster_boot_tb'
    }
    foreach ($test in $tests) {
        & vcom -2008 -work work (Join-Path $PSScriptRoot ($test + '.vhd'))
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $test" }
        $arguments = @('-c', "work.$test", '-l', ($test + '.log'))
        if ($test -eq 'blaster_boot_tb') { $arguments += "-gframe_limit=$Frames" }
        $arguments += @('-do', 'do run.do')
        & vsim @arguments
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test" }
    }
} finally {
    Pop-Location
}

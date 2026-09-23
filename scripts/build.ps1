param([string]$ArduinoCli = 'arduino-cli')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$index = 'https://raw.githubusercontent.com/DeqingSun/ch55xduino/ch55xduino/package_ch55xduino_mcs51_index.json'
$cli = (Get-Command $ArduinoCli -ErrorAction Stop).Source

if (-not ((& $cli core list) -match 'CH55xDuino:mcs51')) {
    & $cli core update-index --additional-urls $index
    if ($LASTEXITCODE -ne 0) { throw 'Arduino core index update failed' }
    & $cli core install 'CH55xDuino:mcs51@0.0.26' --additional-urls $index
    if ($LASTEXITCODE -ne 0) { throw 'CH55xDuino install failed' }
}

$wrapper = Join-Path $env:LOCALAPPDATA 'Arduino15\packages\CH55xDuino\tools\MCS51Tools\2026.07.10\wrapper\sdcc.sh'
if (-not (Test-Path $wrapper)) { throw "CH55xDuino 0.0.26 wrapper not found: $wrapper" }
$source = [IO.File]::ReadAllText($wrapper)
if ($source.Contains('FILTERED_ARGS=()')) {
    Copy-Item $wrapper "$wrapper.original" -Force
    $source = $source.Replace('FILTERED_ARGS=()', 'first=1')
    $source = $source.Replace('for arg in "$@"; do', 'for arg in "$@"; do' + "`n`t" + 'if [ $first -eq 1 ]; then set --; first=0; fi')
    $source = $source.Replace('FILTERED_ARGS+=("$arg")', 'set -- "$@" "$arg"')
    $source = $source.Replace('"${FILTERED_ARGS[@]}"', '"$@"')
    [IO.File]::WriteAllText($wrapper, $source, [Text.UTF8Encoding]::new($false))
}

$output = Join-Path $root 'output\firmware'
New-Item -ItemType Directory -Force $output | Out-Null
& $cli compile --fqbn 'CH55xDuino:mcs51:ch552:clock=16internal,usb_settings=user148,upload_method=usb' --output-dir $output (Join-Path $root 'firmware\SerialHidBridge')
if ($LASTEXITCODE -ne 0) { throw 'Firmware compile failed' }

$objcopy = Join-Path $env:LOCALAPPDATA 'Arduino15\packages\CH55xDuino\tools\sdcc\build.13407_4\bin\avr-objcopy_7_3_0.exe'
& $objcopy -I ihex -O binary (Join-Path $output 'SerialHidBridge.ino.hex') (Join-Path $output 'SerialHidBridge.bin')
if ($LASTEXITCODE -ne 0) { throw 'HEX to BIN conversion failed' }
Get-FileHash (Join-Path $output 'SerialHidBridge.bin') -Algorithm SHA256

param(
    [ValidateSet('ping','key','keydown','keyup','combo','text','move','click','mousedown','mouseup','scroll','release','capture','uac-yes')]
    [string]$Action = 'ping',
    [string]$Port = 'COM5',
    [string]$CaptureDevice = 'Cam Link 4K',
    [string]$Key,
    [string]$Keys,
    [string]$Text,
    [int]$X = 0,
    [int]$Y = 0,
    [ValidateSet('left','right','middle')][string]$Button = 'left',
    [int]$Amount = 0,
    [string]$Output = 'output\capture.png'
)

$ErrorActionPreference = 'Stop'

if ($Action -eq 'capture') {
    $ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
    $path = [IO.Path]::GetFullPath($Output)
    New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($path)) | Out-Null
    & $ffmpeg -hide_banner -loglevel error -rtbufsize 256M -f dshow -i "video=$CaptureDevice" -frames:v 1 -y $path
    if ($LASTEXITCODE -ne 0) { throw "Capture failed for $CaptureDevice" }
    Write-Output $path
    exit
}

$usage = @{}
for ($n = 0; $n -lt 26; $n++) { $usage[[string][char](65 + $n)] = 4 + $n }
for ($n = 1; $n -le 9; $n++) { $usage[[string]$n] = 29 + $n }
$usage['0'] = 39
$usage['ENTER'] = 40; $usage['ESC'] = 41; $usage['BACKSPACE'] = 42
$usage['TAB'] = 43; $usage['SPACE'] = 44; $usage['DELETE'] = 76
$usage['RIGHT'] = 79; $usage['LEFT'] = 80; $usage['DOWN'] = 81; $usage['UP'] = 82
$usage['HOME'] = 74; $usage['END'] = 77; $usage['PAGEUP'] = 75; $usage['PAGEDOWN'] = 78
$usage['CTRL'] = 224; $usage['SHIFT'] = 225; $usage['ALT'] = 226; $usage['WIN'] = 227
$usage['RCTRL'] = 228; $usage['RSHIFT'] = 229; $usage['RALT'] = 230; $usage['RWIN'] = 231
for ($n = 1; $n -le 12; $n++) { $usage["F$n"] = 57 + $n }

function Resolve-Key([string]$name) {
    $name = $name.Trim().ToUpperInvariant()
    if ($usage.ContainsKey($name)) { return [int]$usage[$name] }
    if ($name -match '^0X[0-9A-F]{1,2}$') { return [Convert]::ToInt32($name.Substring(2), 16) }
    if ($name -match '^\d{1,3}$' -and [int]$name -le 255) { return [int]$name }
    throw "Unknown HID key: $name"
}

$script:serial = [IO.Ports.SerialPort]::new($Port, 9600, [IO.Ports.Parity]::None, 8, [IO.Ports.StopBits]::One)
$serial.ReadTimeout = 1500
$serial.WriteTimeout = 1500
$serial.Open()
$script:sequence = 0
try {
    Start-Sleep -Milliseconds 150
    $serial.DiscardInBuffer()
    function Send-Command([byte]$command, [byte]$a = 0, [byte]$b = 0, [byte]$c = 0) {
        $script:sequence = ($script:sequence + 1) -band 255
        $seq = [byte]$script:sequence
        [byte[]]$frame = @(0xA5, $seq, $command, $a, $b, $c, ($seq -bxor $command -bxor $a -bxor $b -bxor $c))
        $serial.Write($frame, 0, $frame.Length)
        $start = $serial.ReadByte()
        if ($start -ne 0x5A) { throw "Bad reply header: $start" }
        $replySeq = $serial.ReadByte(); $status = $serial.ReadByte(); $checksum = $serial.ReadByte()
        if ($replySeq -ne $seq -or $checksum -ne ($replySeq -bxor $status)) { throw 'Reply checksum/sequence error' }
        if ($status -ne 0) { throw "Device rejected command with status $status" }
    }
    switch ($Action) {
        'ping' { Send-Command 0 }
        'key' {
            if (-not $Key) { throw 'Specify -Key' }
            $code = [byte](Resolve-Key $Key)
            Send-Command 1 $code
            Start-Sleep -Milliseconds 50
            Send-Command 2 $code
        }
        'uac-yes' {
            try {
                Send-Command 1 ([byte]$usage['LEFT'])
                Start-Sleep -Milliseconds 50
                Send-Command 2 ([byte]$usage['LEFT'])
                Start-Sleep -Milliseconds 50
                Send-Command 1 ([byte]$usage['ENTER'])
                Start-Sleep -Milliseconds 50
                Send-Command 2 ([byte]$usage['ENTER'])
            } finally {
                Send-Command 7
            }
        }
        'keydown' {
            if (-not $Key) { throw 'Specify -Key' }
            Send-Command 1 ([byte](Resolve-Key $Key))
        }
        'keyup' {
            if (-not $Key) { throw 'Specify -Key' }
            Send-Command 2 ([byte](Resolve-Key $Key))
        }
        'combo' {
            if (-not $Keys) { throw 'Specify -Keys, for example CTRL+SHIFT+ESC' }
            $codes = @($Keys.Split('+') | ForEach-Object { [byte](Resolve-Key $_) })
            try {
                foreach ($code in $codes) { Send-Command 1 $code }
                Start-Sleep -Milliseconds 60
            } finally {
                [array]::Reverse($codes)
                foreach ($code in $codes) { Send-Command 2 $code }
            }
        }
        'text' {
            if ($null -eq $Text) { throw 'Specify -Text' }
            foreach ($char in $Text.ToCharArray()) {
                $letter = [string]$char
                $shift = $false
                if ($letter -cmatch '^[A-Z]$') { $shift = $true }
                elseif ($letter -cmatch '^[a-z]$') { $letter = $letter.ToUpperInvariant() }
                elseif ($letter -eq ' ') { $letter = 'SPACE' }
                elseif ($letter -eq "`n") { $letter = 'ENTER' }
                elseif ($letter -eq "`r") { continue }
                if (-not $usage.ContainsKey($letter)) { throw "Unsupported text character: $char" }
                $code = [byte]$usage[$letter]
                if ($shift) { Send-Command 1 225 }
                Send-Command 1 $code
                Start-Sleep -Milliseconds 20
                Send-Command 2 $code
                if ($shift) { Send-Command 2 225 }
            }
        }
        'move' {
            while ($X -ne 0 -or $Y -ne 0) {
                $dx = [Math]::Max(-127, [Math]::Min(127, $X))
                $dy = [Math]::Max(-127, [Math]::Min(127, $Y))
                Send-Command 3 ([byte]($dx -band 255)) ([byte]($dy -band 255))
                $X -= $dx; $Y -= $dy
            }
        }
        'click' {
            $mask = switch ($Button) { 'left' { 1 } 'right' { 2 } 'middle' { 4 } }
            Send-Command 4 ([byte]$mask)
            Start-Sleep -Milliseconds 60
            Send-Command 5 ([byte]$mask)
        }
        'mousedown' {
            $mask = switch ($Button) { 'left' { 1 } 'right' { 2 } 'middle' { 4 } }
            Send-Command 4 ([byte]$mask)
        }
        'mouseup' {
            $mask = switch ($Button) { 'left' { 1 } 'right' { 2 } 'middle' { 4 } }
            Send-Command 5 ([byte]$mask)
        }
        'scroll' {
            while ($Amount -ne 0) {
                $step = [Math]::Max(-127, [Math]::Min(127, $Amount))
                Send-Command 6 ([byte]($step -band 255))
                $Amount -= $step
            }
        }
        'release' { Send-Command 7 }
    }
    Write-Output "OK: $Action via $Port"
} finally {
    $serial.Close()
    $serial.Dispose()
}

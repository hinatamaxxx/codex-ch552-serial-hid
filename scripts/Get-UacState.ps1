$ErrorActionPreference = 'Stop'

if (-not ('InputDesktopQuery' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class InputDesktopQuery {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool GetUserObjectInformation(IntPtr handle, int index,
        StringBuilder buffer, uint length, out uint needed);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr handle);
}
'@
}

$desktopName = $null
$desktopError = $null
$handle = [InputDesktopQuery]::OpenInputDesktop(0, $false, 1)
if ($handle -eq [IntPtr]::Zero) {
    $desktopError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
} else {
    try {
        $buffer = [Text.StringBuilder]::new(256)
        [uint32]$needed = 0
        if ([InputDesktopQuery]::GetUserObjectInformation($handle, 2, $buffer, [uint32]($buffer.Capacity * 2), [ref]$needed)) {
            $desktopName = $buffer.ToString()
        } else {
            $desktopError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        }
    } finally {
        [void][InputDesktopQuery]::CloseDesktop($handle)
    }
}

$sessionId = (Get-Process -Id $PID).SessionId
$requests = @(Get-Process consent -ErrorAction SilentlyContinue |
    Where-Object { $_.SessionId -eq $sessionId } |
    ForEach-Object {
        [pscustomobject]@{
            pid = $_.Id
            title = $_.MainWindowTitle
        }
    })

[pscustomobject]@{
    sessionId = $sessionId
    inputDesktop = $desktopName
    desktopError = $desktopError
    consentRequests = $requests
} | ConvertTo-Json -Depth 4 -Compress

param([string]$Port = 'COM5')

$ErrorActionPreference = 'Stop'
$control = Join-Path (Split-Path -Parent $PSScriptRoot) 'control.ps1'
Add-Type -AssemblyName System.Windows.Forms
if (-not ('HidTestFocus' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HidTestFocus {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr p);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    public static void ActivateTestWindow(IntPtr h) {
        uint current = GetCurrentThreadId();
        uint foreground = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        bool attached = foreground != 0 && foreground != current && AttachThreadInput(current, foreground, true);
        try { SetForegroundWindow(h); }
        finally { if (attached) AttachThreadInput(current, foreground, false); }
    }
}
'@
}
$form = New-Object Windows.Forms.Form
$form.Text = 'CH552 keyboard verification'
$form.Width = 420
$form.Height = 130
$form.KeyPreview = $true
$label = New-Object Windows.Forms.Label
$label.Text = 'Checking CH552 F24 key input. This window closes automatically.'
$label.Dock = 'Fill'
$form.Controls.Add($label)
$events = New-Object 'System.Collections.Generic.List[string]'
$form.Add_KeyDown({ if ($_.KeyCode -eq [Windows.Forms.Keys]::F24) { $events.Add('down:F24') } })
$form.Add_KeyUp({ if ($_.KeyCode -eq [Windows.Forms.Keys]::F24) { $events.Add('up:F24') } })
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 600
$script:phase = 0
$script:failure = $null
$timer.Add_Tick({
    if ($script:phase -eq 0) {
        $script:phase = 1
        try {
            if ([HidTestFocus]::GetForegroundWindow() -ne $form.Handle) {
                throw 'Test window not foreground; no key sent. Run the test again and leave its window focused.'
            }
            # F24 avoids confusing ordinary user typing with the test report.
            & $control -Action key -Key 0x73 -Port $Port | Out-Null
        } catch { $script:failure = $_.Exception.Message }
        $timer.Interval = 1500
    } else { $timer.Stop(); $form.Close() }
})
$form.Add_Shown({
    $form.Activate()
    [HidTestFocus]::ActivateTestWindow($form.Handle)
    $timer.Start()
})
try { [Windows.Forms.Application]::Run($form) }
finally { $timer.Dispose(); $form.Dispose() }
$passed = -not $script:failure -and $events.Contains('down:F24') -and $events.Contains('up:F24')
[pscustomobject]@{port=$Port;events=@($events.ToArray());error=$script:failure;passed=$passed} | ConvertTo-Json -Compress
if (-not $passed) { exit 1 }

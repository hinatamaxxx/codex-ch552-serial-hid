param([string]$Port = 'COM5')

$ErrorActionPreference = 'Stop'
$stateScript = Join-Path $PSScriptRoot 'Get-UacState.ps1'
$control = Join-Path (Split-Path -Parent $PSScriptRoot) 'control.ps1'
$state = & $stateScript | ConvertFrom-Json
$requests = @($state.consentRequests)

if ($state.desktopError -eq 5 -and $requests.Count -eq 1) {
    Write-Output 'UAC is already foreground.'
    exit 0
}
if ($state.inputDesktop -ne 'Default' -or $requests.Count -ne 1) {
    throw 'Expected exactly one background UAC request on the ordinary desktop. No keys were sent.'
}

$title = [string]$requests[0].title
if ([string]::IsNullOrWhiteSpace($title)) {
    throw 'The pending consent request has no readable title. No keys were sent.'
}
$appName = ($title -replace '\s+がアクセス許可を要求しています.*$', '').Trim()

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$root = [Windows.Automation.AutomationElement]::RootElement
$taskbarCondition = [Windows.Automation.OrCondition]::new(
    [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty, 'Shell_TrayWnd'),
    [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty, 'Shell_SecondaryTrayWnd'))
$taskbars = $root.FindAll([Windows.Automation.TreeScope]::Children, $taskbarCondition)
$buttonCondition = [Windows.Automation.PropertyCondition]::new(
    [Windows.Automation.AutomationElement]::ClassNameProperty, 'Taskbar.TaskListButtonAutomationPeer')
$matches = @(
    for ($t = 0; $t -lt $taskbars.Count; $t++) {
    $elements = $taskbars.Item($t).FindAll([Windows.Automation.TreeScope]::Descendants, $buttonCondition)
    for ($i = 0; $i -lt $elements.Count; $i++) {
        $item = $elements.Item($i)
        if ($item.Current.ClassName -ne 'Taskbar.TaskListButtonAutomationPeer') { continue }
        $name = [string]$item.Current.Name
        if ($name.Contains($title) -or
            ($appName.Length -ge 3 -and $name.Contains($appName)) -or
            $name.Contains('ユーザー アカウント制御') -or
            $name.Contains('User Account Control')) {
            $item
        }
    }
    }
)

if ($matches.Count -ne 1) {
    throw "Could not uniquely identify the UAC taskbar button (matches=$($matches.Count)). No keys were sent."
}
$button = $matches[0]
$before = & $stateScript | ConvertFrom-Json
$beforeRequests = @($before.consentRequests)
if ($before.inputDesktop -ne 'Default' -or $beforeRequests.Count -ne 1 -or
    $beforeRequests[0].pid -ne $requests[0].pid) {
    throw 'The pending UAC request changed while locating its taskbar button. No keys were sent.'
}
if (-not $button.Current.IsKeyboardFocusable) {
    throw 'The UAC taskbar button is not keyboard focusable. No keys were sent.'
}
$button.SetFocus()
$focused = [Windows.Automation.AutomationElement]::FocusedElement
if ($focused.Current.ClassName -ne 'Taskbar.TaskListButtonAutomationPeer' -or
    $focused.Current.Name -ne $button.Current.Name) {
    throw 'The UAC taskbar button did not receive keyboard focus. No keys were sent.'
}

& $control -Action key -Key ENTER -Port $Port | Out-Null
for ($attempt = 0; $attempt -lt 15; $attempt++) {
    Start-Sleep -Milliseconds 100
    $after = & $stateScript | ConvertFrom-Json
    $afterRequests = @($after.consentRequests)
    if ($after.desktopError -eq 5 -and $afterRequests.Count -eq 1 -and
        $afterRequests[0].pid -eq $requests[0].pid) {
        Write-Output "UAC is foreground for pending request PID $($requests[0].pid)."
        exit 0
    }
}
throw 'Taskbar button was activated, but UAC did not become foreground. No consent keys were sent.'

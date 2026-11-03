$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$dest = Join-Path $env:LOCALAPPDATA 'GlassKeys'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $root 'index.html') $dest -Force
Copy-Item (Join-Path $root 'build\icon.ico') $dest -Force

$candidates = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$engine = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $engine) {
  Write-Host 'Microsoft Edge or Google Chrome was not found on this computer.'
  exit 1
}

$url = ([System.Uri](Join-Path $dest 'index.html')).AbsoluteUri
$shell = New-Object -ComObject WScript.Shell
$places = @(
  [Environment]::GetFolderPath('Desktop'),
  (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
)
foreach ($folder in $places) {
  $lnk = $shell.CreateShortcut((Join-Path $folder 'Glass Keys.lnk'))
  $lnk.TargetPath = $engine
  $lnk.Arguments = "--app=`"$url`" --user-data-dir=`"$dest\profile`" --window-size=1200,800"
  $lnk.IconLocation = (Join-Path $dest 'icon.ico')
  $lnk.Save()
}
Write-Host ''
Write-Host 'Done! Glass Keys is on your Desktop and in the Start menu.'

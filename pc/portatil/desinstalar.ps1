# Desinstala o Ping: fecha ele, tira atalhos, a tarefa do logon e o registro em Configuracoes > Apps.
#   -ApagarPasta  apaga tambem a pasta do Ping (o Windows chama assim pelo "Desinstalar" da lista de apps)
param([switch]$ApagarPasta, [string]$Pasta = '')
if (-not $Pasta) { $Pasta = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $env:TEMP  # pasta atual dentro da do Ping nao deixaria apagar

Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*ping.pyw*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

foreach ($d in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))) {
    $p = Join-Path $d 'Ping.lnk'
    if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
}
Unregister-ScheduledTask -TaskName 'Ping' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Classes\AppUserModelId\Ping.Bandeja' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Ping' -Recurse -Force -ErrorAction SilentlyContinue

$apagou = $false
# so apaga pasta que e mesmo do Ping, e nunca uma com Git (a copia de quem desenvolve)
$ehPing = (Test-Path (Join-Path $Pasta 'ping.pyw')) -and (Test-Path (Join-Path $Pasta 'ponte.py'))
$git = (Test-Path (Join-Path $Pasta '.git')) -or (Test-Path (Join-Path (Split-Path -Parent $Pasta) '.git'))
if ($ApagarPasta -and $ehPing -and -not $git) {
    for ($i = 0; $i -lt 10 -and (Test-Path $Pasta); $i++) {
        Remove-Item $Pasta -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $Pasta) { Start-Sleep -Milliseconds 700 }  # arquivo ainda preso pelo Python que fechou
    }
    $apagou = -not (Test-Path $Pasta)
}

Write-Host ''
Write-Host '  Ping desinstalado.' -ForegroundColor Green
if ($apagou) { Write-Host '  A pasta do Ping foi apagada.' }
else { Write-Host "  Atalhos removidos. Se quiser, apague a pasta: $Pasta" }
Write-Host ''
Read-Host '  Enter pra sair'

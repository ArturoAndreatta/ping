# Instala o Ping portatil: cria os atalhos, registra em Configuracoes > Apps e abre.
# Nao instala nada no Windows (o Python vem na pasta).
$ErrorActionPreference = 'Stop'
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyw = Join-Path $pasta 'python\pythonw.exe'
$app = Join-Path $pasta 'ping.pyw'
$ico = Join-Path $pasta 'ping.ico'

Write-Host ''
Write-Host '  PING - instalando...' -ForegroundColor Yellow
Write-Host ''

if (($pasta -like '*\AppData\Local\Temp\*') -or -not (Test-Path $pyw)) {
    Write-Host '  Parece que voce abriu direto de dentro do zip.' -ForegroundColor Red
    Write-Host '  Clique com o botao direito no zip > Extrair tudo, e rode o instalador da pasta extraida.'
    Write-Host ''
    Read-Host '  Enter pra sair'
    exit 1
}

# arquivo baixado da internet vem "bloqueado" pelo Windows: libera so os desta pasta
Get-ChildItem -Path $pasta -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

# fecha um Ping que ja esteja aberto (reinstalacao)
Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*ping.pyw*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

function Novo-Atalho($caminho, $extra = '') {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($caminho)
    $sc.TargetPath = $pyw
    $sc.Arguments = ('"' + $app + '" ' + $extra).Trim()
    $sc.WorkingDirectory = $pasta
    $sc.IconLocation = $ico + ',0'
    $sc.Description = 'Ping'
    $sc.Save()
}

# com a tarefa "Ping" (o Ping cria ao abrir: sai na hora do logon) o atalho da Inicializacao nao volta
$tarefa = $null -ne (Get-ScheduledTask -TaskName 'Ping' -ErrorAction SilentlyContinue)
foreach ($d in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup'))) {
    $p = Join-Path $d 'Ping.lnk'
    if (Test-Path $p) { Remove-Item $p -Force }
    if ($tarefa -and $d -eq [Environment]::GetFolderPath('Startup')) { continue }
    Novo-Atalho $p
}
Write-Host '  Atalho criado na Area de Trabalho e pra abrir junto com o Windows.'

# Configuracoes > Apps do Windows, com Desinstalar (HKCU: sem administrador)
try {
    $chave = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Ping'
    New-Item -Path $chave -Force | Out-Null
    $versao = ''
    $arqVersao = Join-Path $pasta 'versao.txt'
    if (Test-Path $arqVersao) { $versao = (Get-Content $arqVersao -Raw).Trim() }
    $desinst = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $pasta 'desinstalar.ps1') + '" -ApagarPasta'
    Set-ItemProperty -Path $chave -Name DisplayName -Value 'Ping'
    Set-ItemProperty -Path $chave -Name DisplayIcon -Value $ico
    Set-ItemProperty -Path $chave -Name DisplayVersion -Value $versao
    Set-ItemProperty -Path $chave -Name Publisher -Value 'Ping (codigo aberto)'
    Set-ItemProperty -Path $chave -Name InstallLocation -Value $pasta
    Set-ItemProperty -Path $chave -Name UninstallString -Value $desinst
    Set-ItemProperty -Path $chave -Name NoModify -Value 1 -Type DWord
    Set-ItemProperty -Path $chave -Name NoRepair -Value 1 -Type DWord
} catch { }

# rodando como administrador, abre pelo Explorer pra o Ping nao ficar como admin
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$abrir = Join-Path $pasta 'abrir.lnk'
if ($admin -and (Get-Process explorer -ErrorAction SilentlyContinue)) {
    Novo-Atalho $abrir '--painel'
    Start-Process explorer.exe -ArgumentList ('"' + $abrir + '"')
} else {
    Start-Process -FilePath $pyw -ArgumentList ('"' + $app + '" --painel') -WorkingDirectory $pasta
}
Write-Host ''
Write-Host '  Pronto! O Ping esta perto do relogio e a janela dele vai abrir.' -ForegroundColor Green
Write-Host '  Entre na sua conta e escaneie o QR code com o celular.'
Write-Host ''
Start-Sleep -Seconds 6
if (Test-Path $abrir) { Remove-Item $abrir -Force -ErrorAction SilentlyContinue }

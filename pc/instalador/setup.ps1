# Roda de dentro do "Ping vX.Y.Z.exe" (IExpress): copia o Ping pra pasta do usuario e chama o instalador.
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA 'Ping'

Write-Host ''
Write-Host '  PING - copiando os arquivos...' -ForegroundColor Yellow

# fecha o Ping aberto: com ele rodando o Python da pasta fica preso e nao da pra trocar
Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*ping.pyw*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 800
[IO.Directory]::CreateDirectory($dest) | Out-Null

# o zip de dentro tem tudo na pasta Ping/
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $aqui 'Ping.zip'))
try {
    foreach ($e in $zip.Entries) {
        if ($e.FullName.EndsWith('/')) { continue }
        $alvo = [IO.Path]::Combine($env:LOCALAPPDATA, $e.FullName.Replace('/', '\'))
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($alvo)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $alvo, $true)
    }
} finally { $zip.Dispose() }

& (Join-Path $dest 'instalar.ps1')

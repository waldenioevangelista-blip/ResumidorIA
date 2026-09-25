$arquivoLinks = ".\links.txt"
$arquivoProcessados = ".\processados.txt"

if (-not (Test-Path $arquivoLinks)) {
    Write-Host "Erro: arquivo links.txt nao encontrado."
    exit
}

if (-not (Test-Path $arquivoProcessados)) {
    New-Item $arquivoProcessados -ItemType File | Out-Null
}

$links = Get-Content $arquivoLinks | Where-Object { $_.Trim() -ne "" }
$processados = Get-Content $arquivoProcessados

if (-not $links) {
    Write-Host "Nenhum link encontrado."
    exit
}

foreach ($link in $links) {

    if ($link -in $processados) {
        Write-Host "Ja processado: $link"
    }
    else {
        Write-Host "NOVO LINK: $link"

        Add-Content $arquivoProcessados $link
    }
}
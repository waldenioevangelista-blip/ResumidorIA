$ytDlp = "C:\Users\Suporte\Downloads\yt-dlp.exe"
$ffmpeg = "C:\Users\Suporte\Downloads\ffmpeg-9.0.2\bin\ffmpeg.exe"

$arquivoLinks = ".\links.txt"
$arquivoProcessados = ".\processados.txt"

$pastaVideos = ".\downloads"
$pastaAudios = ".\audios"

New-Item $pastaVideos -ItemType Directory -Force | Out-Null
New-Item $pastaAudios -ItemType Directory -Force | Out-Null

$links = Get-Content $arquivoLinks |
Where-Object { $_.Trim() -ne "" }

$processados = Get-Content $arquivoProcessados -ErrorAction SilentlyContinue

foreach ($link in $links) {

    if ($link -in $processados) {
        Write-Host "JA PROCESSADO: $link"
        continue
    }

    Write-Host ""
    Write-Host "BAIXANDO: $link"

    & $ytDlp `
        --ffmpeg-location "C:\Users\Suporte\Downloads\ffmpeg-9.0.2\bin" `
        --no-playlist `
        -o "$pastaVideos\%(id)s.%(ext)s" `
        "$link"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO NO DOWNLOAD."
        continue
    }

    $video = Get-ChildItem $pastaVideos |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $audio = Join-Path $pastaAudios ($video.BaseName + ".mp3")

    Write-Host "EXTRAINDO AUDIO..."

    & $ffmpeg `
        -y `
        -i $video.FullName `
        -vn `
        -acodec libmp3lame `
        $audio

    if ($LASTEXITCODE -eq 0) {
        Write-Host "PROCESSAMENTO CONCLUIDO."
        Add-Content $arquivoProcessados $link
    }
    else {
        Write-Host "ERRO AO EXTRAIR AUDIO."
    }
}
# ============================================================
# RESUMIDOR IA V6.2
# - Usa a pasta real do projeto em $HOME\ResumidorIA quando existir
# - Se transcrever.py nao existir, cria automaticamente a versao otimizada
# - Procura yt-dlp, ffmpeg e Python/faster-whisper de forma robusta
# - Monitora o clipboard a cada 5 segundos
# ============================================================

$ErrorActionPreference = "Continue"

# ------------------------------------------------------------
# LOCALIZAR PASTA DO PROJETO
# ------------------------------------------------------------

$projetoPreferencial = Join-Path $HOME "ResumidorIA"

if (Test-Path $projetoPreferencial) {
    $projeto = $projetoPreferencial
}
else {
    $projeto = $PSScriptRoot
}

$pastaProjetos = Join-Path $projeto "Projetos"
$arquivoProcessados = Join-Path $projeto "processados.txt"
$scriptTranscricao = Join-Path $projeto "transcrever.py"
$intervaloClipboard = 5

function Limpar-Nome {
    param([string]$Nome)

    $nome = $Nome.Trim()
    $nome = $nome -replace '[<>:"/\\|?*]', '-'
    $nome = $nome.TrimEnd('.', ' ')
    return $nome
}

function Localizar-Programa {
    param([string]$Nome)

    try {
        $cmd = Get-Command $Nome -ErrorAction Stop
        if ($cmd.Source) {
            return $cmd.Source
        }
    } catch {}

    try {
        $where = & where.exe $Nome 2>$null | Select-Object -First 1
        if ($where -and (Test-Path $where)) {
            return $where
        }
    } catch {}

    foreach ($raiz in @(
        $projeto,
        (Join-Path $HOME "Downloads"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages")
    )) {
        if ($raiz -and (Test-Path $raiz)) {
            try {
                $resultado = Get-ChildItem `
                    $raiz `
                    -Recurse `
                    -File `
                    -Filter $Nome `
                    -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if ($resultado) {
                    return $resultado.FullName
                }
            } catch {}
        }
    }

    return $null
}

function Localizar-Python {

    $candidatos = @()

    try {
        $cmd = Get-Command python -ErrorAction Stop
        if ($cmd.Source) {
            $candidatos += $cmd.Source
        }
    } catch {}

    $candidatos += "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
    $candidatos += "$env:LOCALAPPDATA\Python\pythoncore-3.13-64\python.exe"
    $candidatos += "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
    $candidatos += "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\python.exe"

    foreach ($pythonTeste in ($candidatos | Select-Object -Unique)) {

        if ($pythonTeste -and (Test-Path $pythonTeste)) {

            & $pythonTeste -c "import faster_whisper" 2>$null

            if ($LASTEXITCODE -eq 0) {
                return $pythonTeste
            }
        }
    }

    return $null
}

function Obter-LinksProcessados {

    if (-not (Test-Path $arquivoProcessados)) {
        return @()
    }

    $resultado = @()

    foreach ($linha in Get-Content $arquivoProcessados -ErrorAction SilentlyContinue) {

        if (-not [string]::IsNullOrWhiteSpace($linha)) {

            $url = ($linha -split '\s+\|\s+', 2)[0]

            if ($url) {
                $resultado += $url.Trim()
            }
        }
    }

    return $resultado
}

function Criar-Transcritor-SeNecessario {

    if (Test-Path $scriptTranscricao) {
        return
    }

    $codigoPython = @'
from faster_whisper import WhisperModel
from pathlib import Path
import sys
import time

if len(sys.argv) < 3:
    print("Uso: python transcrever.py <audio> <saida.txt>")
    sys.exit(1)

audio = Path(sys.argv[1])
saida = Path(sys.argv[2])

if not audio.exists():
    print(f"ERRO: arquivo de audio nao encontrado: {audio}")
    sys.exit(2)

saida.parent.mkdir(parents=True, exist_ok=True)

print("")
print("==============================================")
print("TRANSCRICAO RAPIDA - FASTER-WHISPER")
print("==============================================")
print(f"Audio: {audio.name}")
print("Modelo: base")
print("Dispositivo: CPU")
print("Beam size: 1")
print("VAD: ativado")
print("")

inicio = time.time()

try:
    model = WhisperModel(
        "base",
        device="cpu",
        compute_type="int8"
    )

    segments, info = model.transcribe(
        str(audio),
        beam_size=1,
        vad_filter=True,
        condition_on_previous_text=False
    )

    duracao = float(info.duration or 0.0)

    print(f"Idioma detectado: {info.language}")

    if duracao > 0:
        minutos = int(duracao // 60)
        segundos = int(duracao % 60)
        print(f"Duracao aproximada: {minutos:02d}:{segundos:02d}")

    print("")

    partes = []
    ultimo_percentual_impresso = -1

    for segmento in segments:

        trecho = segmento.text.strip()

        if trecho:
            partes.append(trecho)

        if duracao > 0:

            percentual = int(min(100, (segmento.end / duracao) * 100))

            if percentual >= ultimo_percentual_impresso + 2:

                atual_min = int(segmento.end // 60)
                atual_seg = int(segmento.end % 60)
                total_min = int(duracao // 60)
                total_seg = int(duracao % 60)

                print(
                    f"Progresso: {percentual:3d}% "
                    f"({atual_min:02d}:{atual_seg:02d} / "
                    f"{total_min:02d}:{total_seg:02d})"
                )

                ultimo_percentual_impresso = percentual

    texto_final = " ".join(partes).strip()

    saida.write_text(
        texto_final,
        encoding="utf-8"
    )

    tempo_total = time.time() - inicio
    min_exec = int(tempo_total // 60)
    seg_exec = int(tempo_total % 60)

    print("")
    print("==============================================")
    print("TRANSCRICAO CONCLUIDA")
    print("==============================================")
    print(f"Arquivo: {saida}")
    print(f"Tempo de processamento: {min_exec:02d}:{seg_exec:02d}")
    print(f"Caracteres gerados: {len(texto_final)}")

    sys.exit(0)

except KeyboardInterrupt:
    print("")
    print("Transcricao interrompida pelo usuario.")
    sys.exit(130)

except Exception as erro:
    print("")
    print("ERRO DURANTE A TRANSCRICAO:")
    print(str(erro))
    sys.exit(3)
'@

    $codigoPython | Set-Content `
        -Path $scriptTranscricao `
        -Encoding UTF8
}

# ============================================================
# INICIALIZACAO
# ============================================================

Clear-Host

Write-Host "===================================================="
Write-Host "              RESUMIDOR IA V6.2"
Write-Host "===================================================="
Write-Host ""
Write-Host "Projeto:"
Write-Host $projeto
Write-Host ""
Write-Host "Localizando ferramentas..."
Write-Host ""

$ytDlp = Localizar-Programa "yt-dlp.exe"
$ffmpeg = Localizar-Programa "ffmpeg.exe"
$ffprobe = Localizar-Programa "ffprobe.exe"
$python = Localizar-Python

if (-not $ytDlp) {
    Write-Host "ERRO: yt-dlp nao encontrado."
    Read-Host "Pressione ENTER para sair"
    exit 1
}

if (-not $ffmpeg) {
    Write-Host "ERRO: FFmpeg nao encontrado."
    Write-Host "Instale com: winget install Gyan.FFmpeg"
    Read-Host "Pressione ENTER para sair"
    exit 2
}

if (-not $python) {
    Write-Host "ERRO: Python com faster-whisper nao encontrado."
    Write-Host 'Instale com: python -m pip install faster-whisper'
    Read-Host "Pressione ENTER para sair"
    exit 3
}

Set-Location $projeto

New-Item $pastaProjetos -ItemType Directory -Force | Out-Null

if (-not (Test-Path $arquivoProcessados)) {
    New-Item $arquivoProcessados -ItemType File | Out-Null
}

Criar-Transcritor-SeNecessario

if (-not (Test-Path $scriptTranscricao)) {
    Write-Host "ERRO: nao foi possivel criar/localizar transcrever.py."
    Write-Host $scriptTranscricao
    Read-Host "Pressione ENTER para sair"
    exit 4
}

$ffmpegPasta = Split-Path $ffmpeg

Write-Host "yt-dlp:"
Write-Host $ytDlp
Write-Host ""

Write-Host "FFmpeg:"
Write-Host $ffmpeg
Write-Host ""

Write-Host "Python:"
Write-Host $python
Write-Host ""

Write-Host "Transcritor:"
Write-Host $scriptTranscricao
Write-Host ""

Write-Host "Ambiente OK."
Write-Host ""

function Processar-Link {

    param([string]$Link)

    if ([string]::IsNullOrWhiteSpace($Link)) {
        return $false
    }

    $Link = $Link.Trim()

    if (-not ($Link.StartsWith("http://") -or $Link.StartsWith("https://"))) {
        return $false
    }

    $jaProcessados = Obter-LinksProcessados

    if ($Link -in $jaProcessados) {

        Write-Host ""
        Write-Host "LINK JA PROCESSADO:"
        Write-Host $Link

        return $false
    }

    Write-Host ""
    Write-Host "===================================================="
    Write-Host "NOVO LINK ENCONTRADO"
    Write-Host "===================================================="
    Write-Host ""
    Write-Host $Link
    Write-Host ""

    do {
        $nomeProjeto = Read-Host "Digite o nome deste projeto"
        $nomeProjeto = Limpar-Nome $nomeProjeto
    }
    while ([string]::IsNullOrWhiteSpace($nomeProjeto))

    $pastaItem = Join-Path $pastaProjetos $nomeProjeto

    if (Test-Path $pastaItem) {
        $sufixo = Get-Date -Format "yyyyMMdd-HHmmss"
        $pastaItem = Join-Path $pastaProjetos "$nomeProjeto-$sufixo"
    }

    New-Item $pastaItem -ItemType Directory -Force | Out-Null

    Write-Host ""
    Write-Host "[1/3] BAIXANDO VIDEO..."
    Write-Host ""

    & $ytDlp `
        --ffmpeg-location $ffmpegPasta `
        --no-playlist `
        --merge-output-format mp4 `
        -o "$pastaItem\$nomeProjeto.%(ext)s" `
        "$Link"

    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "ERRO NO DOWNLOAD."

        return $false
    }

    $video = Get-ChildItem $pastaItem -File |
        Where-Object { $_.Extension -notin @(".txt", ".mp3") } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $video) {

        Write-Host ""
        Write-Host "ERRO: video nao localizado."

        return $false
    }

    $audio = Join-Path $pastaItem "$nomeProjeto.mp3"

    Write-Host ""
    Write-Host "[2/3] EXTRAINDO AUDIO..."
    Write-Host ""

    & $ffmpeg `
        -y `
        -i $video.FullName `
        -vn `
        -codec:a libmp3lame `
        $audio

    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "ERRO AO EXTRAIR AUDIO."

        return $false
    }

    $transcricao = Join-Path $pastaItem "$nomeProjeto.txt"

    Write-Host ""
    Write-Host "[3/3] TRANSCREVENDO..."
    Write-Host ""

    & $python `
        $scriptTranscricao `
        $audio `
        $transcricao

    if ($LASTEXITCODE -ne 0) {

        Write-Host ""
        Write-Host "ERRO NA TRANSCRICAO."

        return $false
    }

    $registro = "$Link | $nomeProjeto | $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"

    Add-Content $arquivoProcessados $registro

    Write-Host ""
    Write-Host "===================================================="
    Write-Host "PROCESSAMENTO CONCLUIDO"
    Write-Host "===================================================="
    Write-Host ""
    Write-Host "Pasta:"
    Write-Host $pastaItem
    Write-Host ""

    return $true
}

# ============================================================
# MONITOR DO CLIPBOARD
# ============================================================

try {
    $ultimoClipboard = Get-Clipboard -Raw -ErrorAction SilentlyContinue
}
catch {
    $ultimoClipboard = ""
}

Write-Host "===================================================="
Write-Host "Monitorando area de transferencia."
Write-Host "Copie um link para iniciar."
Write-Host "Verificacao a cada 5 segundos."
Write-Host "CTRL + C para encerrar."
Write-Host "===================================================="

while ($true) {

    Start-Sleep -Seconds $intervaloClipboard

    try {
        $clipboardAtual = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    }
    catch {
        $clipboardAtual = ""
    }

    if ([string]::IsNullOrWhiteSpace($clipboardAtual)) {
        continue
    }

    $clipboardAtual = $clipboardAtual.Trim()

    if ($clipboardAtual -eq $ultimoClipboard) {
        continue
    }

    $ultimoClipboard = $clipboardAtual

    if (-not ($clipboardAtual.StartsWith("https://") -or $clipboardAtual.StartsWith("http://"))) {
        continue
    }

    Write-Host ""
    Write-Host "LINK DETECTADO:"
    Write-Host $clipboardAtual
    Write-Host ""

    $resultado = Processar-Link $clipboardAtual

    Write-Host ""
    Write-Host "Ultima verificacao:"
    Write-Host ((Get-Date).ToString("dd/MM/yyyy HH:mm:ss"))
    Write-Host ""

    if ($resultado) {
        Write-Host "Status: processado com sucesso."
    }
    else {
        Write-Host "Status: nao processado."
    }

    Write-Host ""
    Write-Host "Voltando a monitorar..."
    Write-Host "Nova verificacao em 5 segundos."
    Write-Host ""
}

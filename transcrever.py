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

    saida.write_text(texto_final, encoding="utf-8")

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

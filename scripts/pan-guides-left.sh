#!/bin/bash
SRC="/home/gaspar/musica/canciones-secuencias/guias-clicks/Click_and_Guide_Samples/Click and Guide Samples/Spanish Guides/Song Sections"
OUT="$SRC/panned"

mkdir -p "$OUT"

for f in "$SRC"/*.wav; do
  name="$(basename "$f")"
  ffmpeg -y -i "$f" -af "pan=stereo|c0=c0|c1=0*c0" -ar 44100 "$OUT/$name"
  echo "✓ $name"
done

echo "Listo — $(ls "$OUT"/*.wav | wc -l) archivos en $OUT"

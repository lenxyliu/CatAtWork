#!/bin/sh
set -eu

SOURCE=${1:-Sources/CatAtWork/Resources/DefaultPet.catpet}
OUTPUT=${2:-Build/CatAtWork.catpet}
mkdir -p "$(dirname "$OUTPUT")"
ditto -c -k --norsrc "$SOURCE" "$OUTPUT"
unzip -Z1 "$OUTPUT" | awk '
  /(^\/|(^|\/)\.\.($|\/)|\\)/ { print "unsafe archive path: " $0 > "/dev/stderr"; bad=1 }
  END { exit bad }
'
echo "Packaged $OUTPUT"

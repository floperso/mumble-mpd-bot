#!/bin/bash
pushd ./download/
youtube-dl -x --audio-format vorbis --default-search auto --max-filesize 125m -o "[$1] - %(title)s - %(id)s.%(ext)s" $2
popd

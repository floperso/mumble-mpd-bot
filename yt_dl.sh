#!/bin/bash
#pushd /var/lib/mpd/ftp/youtube
#pushd /var/lib/mpd/music_temp/ftp/youtube/
pushd ./download/
youtube-dl -x --audio-format vorbis --max-filesize 20m $1
popd

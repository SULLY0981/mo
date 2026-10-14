#!/bin/bash
# Records gameplay clips with Godot Movie Maker and cuts a ~50s trailer with ffmpeg.
# Usage: tools/store/make_trailer.sh <fonts_dir_with_ttf> [xvfb]
set -e
FD=$1; T=/tmp/trailer; mkdir -p $T store
GODOT="godot"
[ "$2" == "xvfb" ] && GODOT="xvfb-run -a -s '-screen 0 1280x720x24' godot"
clip() { # name start_time char frames
  eval $GODOT --path . --resolution 1280x720 --write-movie $T/$1.avi --fixed-fps 30 --quit-after $4 -- --trailer=$2 --char=$3 > $T/$1.log 2>&1
  ffmpeg -y -loglevel error -i $T/$1.avi -an -vf "fade=in:0:8,fade=out:st=$(echo "$4/30-0.3" | bc -l):d=0.3" -c:v libx264 -pix_fmt yuv420p -r 30 $T/$1.mp4
}
clip c1 20 keeper 180
clip c2 92 keeper 180
clip c3 181 warden 210
clip c4 440 reaper 180
clip c5 600 seer 180
clip c6 724 alchemist 240
card() { # name text sub seconds
  convert store/page_background_1438x810.png -resize 1280x720^ -gravity center -extent 1280x720 -modulate 55 \
    \( store/logo.png -resize 760x \) -gravity center -geometry +0-60 -composite \
    -font $FD/Alegreya.ttf -pointsize 34 -fill '#e9dcff' -annotate +0+150 "$2" $T/$1.png
  ffmpeg -y -loglevel error -loop 1 -i $T/$1.png -t $3 -vf "fade=in:0:15,fade=out:st=$(echo "$3-0.5" | bc -l):d=0.5" -c:v libx264 -pix_fmt yuv420p -r 30 $T/$1.mp4
}
card t0 "The night is endless. Your light is not." 4
card t1 "Survive until dawn." 2.5
card t9 "Wishlist now on Steam" 5
printf "file '%s'\n" t0.mp4 c1.mp4 c2.mp4 t1.mp4 c3.mp4 c4.mp4 c5.mp4 c6.mp4 t9.mp4 > $T/list.txt
ffmpeg -y -loglevel error -f concat -safe 0 -i $T/list.txt -c copy $T/video.mp4
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $T/video.mp4)
ffmpeg -y -loglevel error -i $T/video.mp4 -stream_loop -1 -i assets/audio/music_boss.ogg -t $DUR \
  -af "afade=in:0:d=1.5,afade=out:st=$(echo "$DUR-2.5" | bc -l):d=2.5" -c:v copy -c:a aac -b:a 192k -shortest store/trailer.mp4
ls -la store/trailer.mp4

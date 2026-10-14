#!/bin/bash
# Builds all Steam store images from the Blender key-art renders.
# Usage: tools/store/make_store_art.sh <wide.png> <tall.png> <hero.png> <fonts_dir_with_ttf>
set -e
WIDE=$1; TALL=$2; HERO=$3; FD=$4
OUT=store; T=$(mktemp -d)
mkdir -p $OUT
# ---- logo (transparent)
convert -size 1600x800 xc:none -gravity center -fill white \
  -font $FD/CinzelDeco.ttf -pointsize 170 -annotate +0+55 "LAST LANTERN" \
  -font $FD/Cinzel.ttf -pointsize 70 -annotate +0-105 "T H E" $T/mask.png
convert -size 1600x800 gradient:'#fff4c8'-'#ff5a22' $T/grad.png
convert $T/grad.png $T/mask.png -compose CopyOpacity -composite $T/text.png
convert $T/mask.png -fill '#ff7a20' -colorize 100 -channel A -evaluate multiply 0.8 +channel -blur 0x22 $T/glow.png
convert $T/mask.png -morphology Dilate Disk:6 -fill '#170804' -colorize 100 $T/outline.png
convert $T/glow.png $T/outline.png -composite $T/text.png -composite -trim +repage -bordercolor none -border 40 $OUT/logo.png
convert $OUT/logo.png -resize 1200x660 -background none -gravity center -extent 1280x720 $OUT/library_logo_1280x720.png
# ---- wide capsules (character left, logo right)
convert $WIDE -resize 1232x706^ -gravity center -extent 1232x706 $T/main.png
convert $T/main.png \( $OUT/logo.png -resize 640x \) -gravity northeast -geometry +40+70 -composite $OUT/capsule_main_1232x706.png
convert $WIDE -resize 920x -gravity center -extent 920x430 $T/head.png
convert $T/head.png \( $OUT/logo.png -resize 470x \) -gravity east -geometry +24-10 -composite $OUT/capsule_header_920x430.png
convert $WIDE -resize 462x -gravity center -extent 462x174 $T/small.png
convert $T/small.png \( $OUT/logo.png -resize 270x \) -gravity east -geometry +8+0 -composite $OUT/capsule_small_462x174.png
convert $WIDE -resize 1438x810^ -gravity center -extent 1438x810 -modulate 70 $OUT/page_background_1438x810.png
# ---- tall capsules (logo top)
convert $TALL -resize 748x896^ -gravity center -extent 748x896 $T/vert.png
convert $T/vert.png \( $OUT/logo.png -resize 660x \) -gravity north -geometry +0+30 -composite $OUT/capsule_vertical_748x896.png
convert $TALL -resize 600x900^ -gravity center -extent 600x900 $T/lib.png
convert $T/lib.png \( $OUT/logo.png -resize 540x \) -gravity north -geometry +0+30 -composite $OUT/library_capsule_600x900.png
# ---- hero (no text) + icons
convert $HERO -resize 3840x1240^ -gravity center -extent 3840x1240 $OUT/library_hero_3840x1240.png
rm -rf $T
ls -la $OUT

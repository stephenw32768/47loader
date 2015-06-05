#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2015
# See LICENSE for distribution terms

prefix="countdown-demo"
speed="STANDARD"

pasmo -E LOADER_SPEED_${speed}=1 $prefix.asm $prefix.bin

# construct the BASIC loader with assembled binary embedded
mono >$prefix.tzx ../../tools/47loader-bootstrap.exe \
  -border 0 -paper 0 -ink 7 \
  <$prefix.bin -clear 32767 -pause 0 -name 'countdown'

# add the demo screen.  Pixmap will load in 24 blocks, with a
# countdown started at 27.  Then attrs will make up the final
# three blocks.  Each block is 256 bytes long
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -pause 0 \
  -speed $speed -countdown 24:27 ../../assets/penrose_pixmap.bin
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -pilot resume \
  -speed $speed -countdown 3  ../../assets/penrose_attrs.bin

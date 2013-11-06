#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013
# See LICENSE for distribution terms

prefix="simple-demo"
speed="CAUTIOUS"

pasmo -E LOADER_SPEED_${speed}=1 $prefix.asm $prefix.bin

# construct the BASIC loader with assembled binary embedded
mono >$prefix.tzx ../../tools/47loader-bootstrap.exe \
  <$prefix.bin -clear 32767 -pause 0 -name '47loader'

# add the demo screen
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -speed $speed \
  =(cat ../../assets/penrose_pixmap.bin ../../assets/penrose_attrs.bin)

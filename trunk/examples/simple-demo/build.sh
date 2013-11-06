#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013
# See LICENSE for distribution terms

prefix="bidi-demo"
speed="FAST"

pasmo -E LOADER_SPEED_${speed}=1 $prefix.asm $prefix.bin

# construct the BASIC loader with assembled binary embedded
mono >$prefix.tzx ../../tools/47loader-bootstrap.exe \
  <$prefix.bin -clear 32767 -pause 0 -name '47bidi'

# add the demo screen using bidirectional loading
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -speed $speed -fancyscreen bidi_pac \
  ../../assets/penrose_colour.scr

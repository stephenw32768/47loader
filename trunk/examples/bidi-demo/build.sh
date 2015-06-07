#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013-2015
# See LICENSE for distribution terms

prefix="bidi-demo"
speed="STANDARD"

pasmo -E LOADER_SPEED_${speed}=1 $prefix.asm $prefix.bin

# construct the BASIC loader with assembled binary embedded
mono >$prefix.tzx ../../tools/47loader-bootstrap.exe \
  <$prefix.bin -clear 32767 -pause 0 -name '47bidi' \
  -border 0 -paper 0 -ink 7   

# add the demo screen using bidirectional loading
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -speed $speed -fancyscreen bidi_pas4 \
  ../../assets/penrose_colour.scr

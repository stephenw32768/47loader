#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013
# See LICENSE for distribution terms

prefix="linear-demo"
speed="FAST"

pasmo -E LOADER_SPEED_${speed}=1 $prefix.asm $prefix.bin

# construct the BASIC loader with assembled binary embedded
mono >$prefix.tzx ../../tools/47loader-bootstrap.exe \
  -border 0 -paper 0 -ink 7 \
  <$prefix.bin -clear 32767 -pause 0 -name '47linear'

# add the demo screen using bidirectional loading
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  -speed $speed -fancyscreen linear_btt \
  ../../assets/penrose_colour.scr

#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013
# See LICENSE for distribution terms

prefix="rle-demo"

pasmo $prefix.asm $prefix.bin
pasmo rldecode.asm rldecode.bin

# embed the loader in a REM statement, formatted so that bas2tap
# can deal with it, then append the rest of the BASIC loader
embedded=$prefix.tmp
/usr/bin/hexdump -ve '/1 "{%02X}"' $prefix.bin | \
  sed -e 's/$/\n/' -e 's/^/0 rem /' >$embedded
cat >>$embedded $prefix.bas

# bas2tap is available from World of Spectrum:
# http://www.worldofspectrum.org/utilities.html#other
bas2tap -n -a1 -srle-demo -c $embedded $prefix.tap

# tapeconv is part of the Fuse distribution:
# http://fuse-emulator.sf.net/
tapeconv $prefix.tap $prefix.tzx

# add the run-length decoder and screen as a single block
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  =(cat rldecode.bin ../../assets/penrose_rle.bin)

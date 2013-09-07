#!/usr/bin/zsh -fe

# 47loader (c) Stephen Williams 2013
# See LICENSE for distribution terms

prefix="simple-demo"

pasmo $prefix.asm $prefix.bin

# embed the loader in a REM statement, formatted so that bas2tap
# can deal with it, then append the rest of the BASIC loader.
# Embedding at line 6147 because assembles to a JR instruction
# skipping the next three bytes (the line length and REM statement)
embedded=$prefix.tmp
/usr/bin/hexdump -ve '/1 "{%02X}"' $prefix.bin | \
  sed -e 's/$/\n/' -e 's/^/6147rem /' >$embedded
cat >>$embedded $prefix.bas

# bas2tap is available from World of Spectrum:
# http://www.worldofspectrum.org/utilities.html#other
bas2tzx -a9000 -s47loader -c $embedded $prefix.tzx

# tapeconv is part of the Fuse distribution:
# http://fuse-emulator.sf.net/
#tapeconv $prefix.tap $prefix.tzx

# add the demo screen
mono >>$prefix.tzx ../../tools/47loader-tzx.exe \
  =(cat ../../assets/penrose_pixmap.bin ../../assets/penrose_attrs.bin)

// 47loader (c) Stephen Williams 2013-2015

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using FortySevenLoader.Tzx;

namespace FortySevenLoader
{
  /// <summary>
  /// The dynamic tables defining fancy screen loads.
  /// </summary>
  static class FancyScreen
  {
    #region Tables

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first.
    /// </summary>
    internal static readonly DynamicTable Bidi_PA = new DynamicTable
    (MakeBidiPixmap()
      // change direction and do the odd-numbered attribute rows
      // forwards
      .Concat(from row in Enumerable.Range(0, 24)
              where row % 2 == 0
              select MakeBidiEntry((byte)row, false, row == 0))
      // change direction and do the even-numbered attribute rows
      // backwards
     .Concat((from row in Enumerable.Range(0, 24)
              where row % 2 == 1
              select MakeBidiEntry((byte)row, true, row == 23)).Reverse()));

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first,
    /// with converging attributes.
    /// </summary>
    internal static readonly DynamicTable Bidi_PAC = new DynamicTable
    (MakeBidiPixmap().Concat(ConvergingAttrs(true)));

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first,
    /// with diverging attributes.
    /// </summary>
    internal static readonly DynamicTable Bidi_PAD = new DynamicTable
    (MakeBidiPixmap().Concat(ConvergingAttrs(true, true)));

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first, with
    /// square attributes (size 8).
    /// </summary>
    internal static readonly DynamicTable Bidi_PAS8 = new DynamicTable
      (MakeBidiPixmap().Concat(AttrSquares(8, initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first, with
    /// square attributes (size 4).
    /// </summary>
    internal static readonly DynamicTable Bidi_PAS4 = new DynamicTable
      (MakeBidiPixmap().Concat(AttrSquares(4, initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, pixmap first, with
    /// square attributes (size 2).
    /// </summary>
    internal static readonly DynamicTable Bidi_PAS2 = new DynamicTable
      (MakeBidiPixmap().Concat(AttrSquares(2, initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, attributes first.
    /// </summary>
    internal static readonly DynamicTable Bidi_AP = new DynamicTable
    (// do the odd-numbered attribute rows forwards
     (from row in Enumerable.Range(0, 24)
      where row % 2 == 0
      select MakeBidiEntry((byte)row, false))
     // change direction and do the even-numbered attribute rows
     // backwards
     .Concat((from row in Enumerable.Range(0, 24)
              where row % 2 == 1
              select MakeBidiEntry((byte)row, true, row == 23)).Reverse())
     .Concat(MakeBidiPixmap(initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, converging attributes
    /// first.
    /// </summary>
    internal static readonly DynamicTable Bidi_ACP = new DynamicTable
    (ConvergingAttrs().Concat(MakeBidiPixmap(initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, diverging attributes
    /// first.
    /// </summary>
    internal static readonly DynamicTable Bidi_ADP = new DynamicTable
    (ConvergingAttrs(diverge: true)
       .Concat(MakeBidiPixmap(initiallyBackwards: true)));

    /// <summary>
    /// Table defining a bidirectional screen load, square attributes
    /// (size 8) first.
    /// </summary>
    internal static readonly DynamicTable Bidi_AS8P = new DynamicTable
      (AttrSquares(8).Concat(MakeBidiPixmap(initiallyBackwards: false)));
    
    /// <summary>
    /// Table defining a bidirectional screen load, square attributes
    /// (size 4) first.
    /// </summary>
    internal static readonly DynamicTable Bidi_AS4P = new DynamicTable
      (AttrSquares(4).Concat(MakeBidiPixmap(initiallyBackwards: false)));
    
    /// <summary>
    /// Table defining a bidirectional screen load, square attributes
    /// (size 2) first.
    /// </summary>
    internal static readonly DynamicTable Bidi_AS2P = new DynamicTable
      (AttrSquares(2).Concat(MakeBidiPixmap(initiallyBackwards: false)));

    /// <summary>
    /// Table defining a screen load with forwards attributes
    /// followed by a backwards pixmap.
    /// </summary>
    internal static readonly DynamicTable FA_RP = new DynamicTable
    {
      // load the attributes
      new DynamicTable.Entry(0x5800, 768),
      // change direction and load the pixmap
      new DynamicTable.Entry(0x57ff, 6144, true)
    };

    /// <summary>
    /// Table defining a screen load with backwards attributes
    /// followed by a forwards pixmap.
    /// </summary>
    internal static readonly DynamicTable RA_FP = new DynamicTable
    {
      // change direction and load the attributes
      new DynamicTable.Entry(23295, 768, true),
      // change direction and load the pixmap
      new DynamicTable.Entry(16384, 6144, true)
    };

    /// <summary>
    /// Table defining a screen load with a backwards pixmap followed by
    /// forwards attributes.
    /// </summary>
    internal static readonly DynamicTable RP_FA = new DynamicTable
    {
      // change direction and load the pixmap
      new DynamicTable.Entry(0x57ff, 6144, true),
      // change direction and load the attributes
      new DynamicTable.Entry(0x5800, 768, true)
    };

    /// <summary>
    /// Table defining a screen load with a forwards pixmap
    /// followed by backwards attributes.
    /// </summary>
    internal static readonly DynamicTable FP_RA = new DynamicTable
    {
      // load the pixmap
      new DynamicTable.Entry(16384, 6144),
      // change direction and load the attributes
      new DynamicTable.Entry(23295, 768, true)
    };

    /// <summary>
    /// Table defining a screen load with a forwards pixmap
    /// followed by attribute squares (size 8).
    /// </summary>
    internal static readonly DynamicTable FP_AS8 = new DynamicTable(
      new[] { new DynamicTable.Entry(16384, 6144) }.Concat(AttrSquares(8))
    );

    /// <summary>
    /// Table defining a screen load with a forwards pixmap
    /// followed by attribute squares (size 4).
    /// </summary>
    internal static readonly DynamicTable FP_AS4 = new DynamicTable(
      new[] { new DynamicTable.Entry(16384, 6144) }.Concat(AttrSquares(4))
    );

    /// <summary>
    /// Table defining a screen load with a forwards pixmap
    /// followed by attribute squares (size 2).
    /// </summary>
    internal static readonly DynamicTable FP_AS2 = new DynamicTable(
      new[] { new DynamicTable.Entry(16384, 6144) }.Concat(AttrSquares(2))
    );

    /// <summary>
    /// Table defining a screen load with a forwards pixmap
    /// followed by bidirectional attributes.
    /// </summary>
    internal static readonly DynamicTable FP_ABIDI = new DynamicTable(
      new[] { new DynamicTable.Entry(16384, 6144) }
    // do the odd-numbered attribute rows
    .Concat(from row in Enumerable.Range(0, 24)
            where row % 2 == 0
            select MakeBidiEntry((byte)row))
    // do the even-numbered attribute rows
    .Concat((from row in Enumerable.Range(0, 24)
             where row % 2 == 1
             select MakeBidiEntry((byte)row)).Reverse()));

    /// <summary>
    /// Table defining a top-to-bottom pixmap load followed by forwards
    /// attributes.
    /// </summary>
    internal static readonly DynamicTable TTB_FA = new DynamicTable(
      MakeTtbPixmap().Concat(new[] { new DynamicTable.Entry(0x5800, 768) })
    );

    /// <summary>
    /// Table defining a top-to-bottom pixmap load followed by backwards
    /// attributes.
    /// </summary>
    internal static readonly DynamicTable TTB_RA = new DynamicTable(
      MakeTtbPixmap().Concat(new[] { new DynamicTable.Entry(23295, 768, true) })
    );

    /// <summary>
    /// Table defining forwards attributes followed by a top-to-bottom pixmap
    /// load.
    /// </summary>
    internal static readonly DynamicTable FA_TTB = new DynamicTable(
      new[] { new DynamicTable.Entry(0x5800, 768) }.Concat(MakeTtbPixmap())
    );

    /// <summary>
    /// Table defining backwards attributes followed by a top-to-bottom pixmap
    /// load.
    /// </summary>
    internal static readonly DynamicTable RA_TTB = new DynamicTable(
      new[] { new DynamicTable.Entry(23295, 768, true) }
     .Concat(MakeTtbPixmap(initiallyBackwards: true))
    );

    /// <summary>
    /// Table defining a bottom-to-top pixmap load followed by forwards
    /// attributes.
    /// </summary>
    internal static readonly DynamicTable BTT_FA = new DynamicTable(
      MakeTtbPixmap(false)
      .Concat(new[] { new DynamicTable.Entry(0x5800, 768, true) })
    );

    /// <summary>
    /// Table defining a bottom-to-top pixmap load followed by backwards
    /// attributes.
    /// </summary>
    internal static readonly DynamicTable BTT_RA = new DynamicTable(
      MakeTtbPixmap(false)
      .Concat(new[] { new DynamicTable.Entry(23295, 768) })
    );

    /// <summary>
    /// Table defining forwards attributes followed by a bottom-to-top pixmap
    /// load.
    /// </summary>
    internal static readonly DynamicTable FA_BTT = new DynamicTable(
      new[] { new DynamicTable.Entry(0x5800, 768) }
      .Concat(MakeTtbPixmap(false))
    );

    /// <summary>
    /// Table defining backwards attributes followed by a bottom-to-top pixmap
    /// load.
    /// </summary>
    internal static readonly DynamicTable RA_BTT = new DynamicTable(
      new[] { new DynamicTable.Entry(23295, 768, true) }
     .Concat(MakeTtbPixmap(false, true))
    );

    /// <summary>
    /// Table defining a linear screen load from top to bottom.
    /// </summary>
    internal static readonly DynamicTable Linear_TTB =
      new DynamicTable(MakeLinear());

    /// <summary>
    /// Table defining a linear screen load from bottom to top.
    /// </summary>
    internal static readonly DynamicTable Linear_BTT =
      new DynamicTable(MakeLinear(LinearMode.BottomToTop));

    /// <summary>
    /// Table defining a linear screen load starting at the top and
    /// bottom, meeting in the middle.
    /// </summary>
    internal static readonly DynamicTable Linear_C =
      new DynamicTable(MakeLinear(LinearMode.Converge));

    /// <summary>
    /// Table defining a linear screen load starting at the middle of
    /// the screen, spreading to the top and bottom.
    /// </summary>
    internal static readonly DynamicTable Linear_D =
      new DynamicTable(MakeLinear(LinearMode.Diverge));

    /// <summary>
    /// Table defining a linear screen load starting at the top and
    /// bottom, meeting in the middle, in blocks of 4x4 squares.
    /// </summary>
    internal static readonly DynamicTable Linear_S4 =
      new DynamicTable(MakeLinear(LinearMode.S4));
    
    /// <summary>
    /// Table defining a linear screen load starting at the top and
    /// bottom, meeting in the middle, in blocks of 8x8 squares.
    /// </summary>
    internal static readonly DynamicTable Linear_S8 =
      new DynamicTable(MakeLinear(LinearMode.S8));

    #endregion

    #region Private methods

    private static IEnumerable<DynamicTable.Entry>
      AttrSquares(byte size, bool initiallyBackwards = false)
    {
      // squares can have 1, 2, 4 or 8 character cells per side
      switch (size)
      {
        case 1:
        case 2:
        case 4:
        case 8:
          break;
        default:
          throw new ArgumentOutOfRangeException("size");
      }

      int squaresPerRow = 32 / size;
      // divvy the attribute memory up into strips of length size
      var chunks = new List<DynamicTable.Entry>();
      for (HighLow16 start = 16384 + 6144, addr = start; addr < 23296; addr += size)
      {
        chunks.Add(new DynamicTable.Entry
                   (addr, size, (addr == start) && initiallyBackwards));
      }

      var firstHalf = new List<DynamicTable.Entry>();
      var secondHalf = new List<DynamicTable.Entry>();

      // imagine a chessboard, black-white-black-white etc.
      // we draw all the black squares top-to-bottom, as firstHalf;
      // we draw all the white squares bottom-to-top, as secondHalf
      bool stagger = false;
      do
      {
        for (int i = 0; i < (squaresPerRow / 2) * size; i++)
        {
          firstHalf.Add(chunks[stagger ? 1 : 0]);
          secondHalf.Insert(0, chunks[stagger ? 0 : 1]);
          chunks.RemoveRange(0, 2);
        }

        stagger = !stagger;
      }
      while (chunks.Count > 0);

      return firstHalf.Concat(secondHalf);
    }

    /// <summary>
    /// Constructs a
    /// <see cref="DynamicTable.Entry"/> for the pixmap phase of a
    /// bidirectional screen load.
    /// </summary>
    /// <param name='third'>
    /// The third of the screen, numbered from zero.
    /// </param>
    /// <param name='line'>
    /// The pixel line within the third, numbered from zero.
    /// </param>
    /// <param name='backwards'>
    /// Set if the block is to be loaded backwards.
    /// </param>
    /// <param name='change'>
    /// Set if the load direction is to be changed before loading the block.
    /// </param>
    private static DynamicTable.Entry MakeBidiEntry
      (byte third, byte line, bool backwards = false, bool change = false)
    {
      int address = 16384 + (third * 2048);
      address += (line * 256);
      if (backwards) address += 255;

      var entry = new DynamicTable.Entry((ushort)address, 256, change);
      return entry;
    }

    /// <summary>
    /// Constructs a
    /// <see cref="DynamicTable.Entry"/> for the atrribute phase of a
    /// bidirectional screen load.
    /// </summary>
    /// <param name='attrLine'>
    /// The attribute line, numbered from zero.
    /// </param>
    /// <param name='backwards'>
    /// Set if the block is to be loaded backwards.
    /// </param>
    /// <param name='change'>
    /// Set if the load direction is to be changed before loading the block.
    /// </param>
    /// <returns>
    /// The <see cref="DynamicTable.Entry"/> instance.
    /// </returns>
    private static DynamicTable.Entry MakeBidiEntry
      (byte attrLine, bool backwards = false, bool change = false)
    {
      int address = 0x5800 + (attrLine * 32);
      if (backwards) address += 31;

      var entry = new DynamicTable.Entry((ushort)address, 32, change);
      return entry;
    }

    /// <summary>
    /// Constructs a sequence of
    /// <see cref="DynamicTable.Entry"/> instances for loading a pixmap
    /// bidirectionally.
    /// </summary>
    /// <param name='topToBottom'>
    /// Set if the pixmap should load top to bottom, clear if bottom to top.
    /// </param>
    /// <param name='initiallyBackwards'>
    /// Set if the loader is going backwards at the point of entry.
    /// </param>
    /// <returns>
    /// The sequence of dynamic table entries.
    /// </returns>
    private static IEnumerable<DynamicTable.Entry> MakeBidiPixmap
      (bool topToBottom = true, bool initiallyBackwards = false)
    {
      // this ordering gives us a bidirectional load with a combing
      // effect, top to bottom
      var order = new[]
      {
        new { Line = (byte)0, Backwards = false },
        new { Line = (byte)4, Backwards = true },
        new { Line = (byte)2, Backwards = false },
        new { Line = (byte)6, Backwards = true },
        new { Line = (byte)1, Backwards = false },
        new { Line = (byte)5, Backwards = true },
        new { Line = (byte)3, Backwards = false },
        new { Line = (byte)7, Backwards = true },
      };

      if (!topToBottom)
        Array.Reverse(order);

      for (int pass = 0; pass < order.Length; pass++)
      {
        // these are the thirds of the screen into which to load pixels
        var thirds = new byte[] { 0, 1, 2 };
        if (order[pass].Backwards) Array.Reverse(thirds);

        for (int thirdIndex = 0; thirdIndex < thirds.Length; thirdIndex++)
        {
          // at the beginning of each pass, we need to change direction
          // when loading the first third _unless_ this is the first pass
          // and the loader was already set in the correct direction
          bool changeDirection = (thirdIndex == 0) &&
            ((pass > 0) ||
             (topToBottom == initiallyBackwards));
          yield return MakeBidiEntry(thirds[thirdIndex],
                                     order[pass].Line,
                                     order[pass].Backwards,
                                     changeDirection);
        }
      }
    }

    /// <summary>
    /// Constructs a sequence of
    /// <see cref="DynamicTable.Entry"/> instances for loading a pixmap
    /// in a semi-contiguous fashion.
    /// </summary>
    /// <param name='topToBottom'>
    /// Set if the pixmap should load top to bottom, clear if bottom to top.
    /// </param>
    /// <param name='initiallyBackwards'>
    /// Set if the loader is going backwards at the point of entry.
    /// </param>
    /// <returns>
    /// The sequence of dynamic table entries.
    /// </returns>
    private static IEnumerable<DynamicTable.Entry> MakeTtbPixmap
      (bool topToBottom = true, bool initiallyBackwards = false)
    {
      // load the pixmap lines in this order
      var lines = new byte[] { 0, 1, 2, 3, 4, 5, 6, 7 };
      var thirds = new byte[] { 0, 1, 2 };
      if (!topToBottom)
      {
        Array.Reverse(lines);
        Array.Reverse(thirds);
      }

      foreach (var line in lines)
      {
        foreach (var third in thirds)
        {
          // change direction if this is the very first block and the
          // loader direction is initially wrong
          bool changeDirection = (lines[0] == line) &&
                                 (thirds[0] == third) && 
                                 (topToBottom == initiallyBackwards);
          yield return
            MakeBidiEntry(third, line, !topToBottom, changeDirection);
        }
      }
    }

    private enum LinearMode
      { TopToBottom, BottomToTop, Converge, Diverge, S4, S8 }

    /// <summary>
    /// Constructs a sequence of
    /// <see cref="DynamicTable.Entry"/> instances for loading a screen
    /// in a linear fashion.
    /// </summary>
    /// <param name='topToBottom'>
    /// Set if the screen should load top to bottom, clear if bottom to top.
    /// </param>
    /// <returns>
    /// The sequence of dynamic table entries.
    /// </returns>
    private static IEnumerable<DynamicTable.Entry>
      MakeLinear(LinearMode mode = LinearMode.TopToBottom)
    {
      var pixmap = new List<DynamicTable.Entry>();
      var attrs = new List<DynamicTable.Entry>();

      // take each third of the screen in turn
      for (int third = 0; third < 3; third++)
      {
        int baseAddress = 16384 + (third * 2048);
        // we have eight rows of characters per third
        for (int row = 0; row < 8; row++)
        {
          // each row begins 32 bytes after the previous row
          int rowAddress = baseAddress + (row * 32);

          // we have eight lines of pixels per row
          for (int line = 0; line < 8; line++)
          {
            // each line begins 256 bytes after the previous line
            var lineAddress = (ushort)(rowAddress + (line * 256));
            pixmap.Add(new DynamicTable.Entry(lineAddress, 32));
          }
        }
      }

      // attributes are a lot easier
      attrs.AddRange(from row in Enumerable.Range(0, 24)
                     let rowAddress = 0x5800 + (row * 32)
                     select new DynamicTable.Entry((ushort)rowAddress, 32)
      );

      switch (mode)
      {
        case LinearMode.BottomToTop:
          pixmap.Reverse();
          attrs.Reverse();
          goto case LinearMode.TopToBottom; // fall through
        case LinearMode.TopToBottom:
          // for each row, write one lot of attributes and eight lines
          int lineIndex = 0;
          foreach (var row in attrs)
          {
            yield return row;
            for (int i = 0; i < 8; i++)
              yield return pixmap[lineIndex++];
          }
          break;

        case LinearMode.Diverge:
          // reverse the top and bottom halves of the screen
          pixmap = (pixmap.Take(pixmap.Count / 2).Reverse()
                    .Concat(pixmap.Skip(pixmap.Count / 2).Reverse())).ToList();
          attrs = (attrs.Take(attrs.Count / 2).Reverse()
                    .Concat(attrs.Skip(attrs.Count / 2).Reverse())).ToList();
          goto case LinearMode.Converge; // fall through
        case LinearMode.Converge:
          // write a pair of rows together: two lots of attributes
          // and lines
          while (attrs.Count > 0)
          {
            yield return attrs[0];
            yield return attrs[attrs.Count - 1];
            attrs.RemoveAt(attrs.Count - 1);
            attrs.RemoveAt(0);
            for (int i = 0; i < 8; i++)
            {
              yield return pixmap[0];
              yield return pixmap[pixmap.Count - 1];
              pixmap.RemoveAt(pixmap.Count - 1);
              pixmap.RemoveAt(0);
            }
          }
          break;

        case LinearMode.S4:
        case LinearMode.S8:
          // we divide each row into n, depending on the size of the square.
          // We do the zeroth, second etc. chunks top-to-bottom and the first,
          // third etc. chunks bottom-to-top.  When we've done a square, we
          // do the first, third etc. chunks top-to-bottom and the zeroth,
          // second etc. chunks bottom-to-top.  The top-to-bottom and bottom-
          // to-top rows are interleaved, like with a Converge
          byte size = mode == LinearMode.S8 ? (byte)8 : (byte)4;
          List<DynamicTable.Entry>
          ttbPixmap = new List<DynamicTable.Entry>(),
          ttbAttrs = new List<DynamicTable.Entry>(),
          bttPixmap = new List<DynamicTable.Entry>(),
          bttAttrs = new List<DynamicTable.Entry>(),
          evenPixmap = ttbPixmap,
          oddPixmap = bttPixmap,
          evenAttrs = ttbAttrs,
          oddAttrs = bttAttrs;
          for (int attrIndex = 0; attrIndex < attrs.Count; attrIndex++)
          {
            var split = attrs[attrIndex].Split(size).ToArray();
            for (int splitIndex = 0; splitIndex < split.Length; splitIndex++)
            {
              if (splitIndex % 2 == 0)
                evenAttrs.Add(split[splitIndex]);
              else
                oddAttrs.Add(split[splitIndex]);
            }

            // now the corresponding pixmap rows, same deal
            for (int pixmapIndex = attrIndex * 8, x = 0;
                 x < 8;
                 pixmapIndex++, x++)
            {
              split = pixmap[pixmapIndex].Split(size).ToArray();
              for (int splitIndex = 0; splitIndex < split.Length; splitIndex++)
              {
                if (splitIndex % 2 == 0)
                  evenPixmap.Add(split[splitIndex]);
                else
                  oddPixmap.Add(split[splitIndex]);
              }
            }
            
            if ((attrIndex % size) == (size - 1))
            {
              // this was the last row of a square
              var tmp = evenAttrs;
              evenAttrs = oddAttrs;
              oddAttrs = tmp;
              tmp = evenPixmap;
              evenPixmap = oddPixmap;
              oddPixmap = tmp;
            }
          }

          // bottom-to-top entries have to be done in reverse, natch
          bttAttrs.Reverse();
          bttPixmap.Reverse();

          // now we send them interleaved.  For each attr entry, we send
          // eight pixmap entries, alternating between TTB and BTT
          while (ttbAttrs.Count > 0)
          {
            // send a row's worth of attrs
            for (int x = 0; x < 32 / 2 / size; x++)
            {
              yield return ttbAttrs[0];
              ttbAttrs.RemoveAt(0);
              yield return bttAttrs[0];
              bttAttrs.RemoveAt(0);
            }
            // now all the corresponding pixmap entries
            for (int x = 0; x < 32 / 2 / size; x++)
            {
              for (int y = 0; y < 8; y++)
              {
                yield return ttbPixmap[0];
                ttbPixmap.RemoveAt(0);
                yield return bttPixmap[0];
                bttPixmap.RemoveAt(0);
              }
            }
          }

          break;
      }
    }

    /// <summary>
    /// Constructs a sequence of
    /// <see cref="DynamicTable.Entry"/> instances for loading attributes
    /// that start at opposite ends of the screen and converge.
    /// </summary>
    /// <param name='initiallyBackwards'>
    /// Set if the loader is going backwards at the point of entry.
    /// </param>
    /// <param name='diverge'></para>
    /// Set if the attributes should diverge instead of converge.
    /// <returns>
    /// The sequence of dynamic table entries.
    /// </returns>
    private static IEnumerable<DynamicTable.Entry>
      ConvergingAttrs(bool initiallyBackwards = false, bool diverge = false)
    {
      const ushort blockSize = 16;
      ushort start = 0x5800, end = 23295;
      bool changeDirection = initiallyBackwards;

      if (diverge)
      {
        // start in the middle instead of at the edges
        start += (ushort)(768 / 2);
        end -= (ushort)(768 / 2);
      }

      // one block from the start, then one block from the end, and
      // continue until they converge
      for (int i = 0; i < 24; i++)
      {
        yield return new DynamicTable.Entry(start, blockSize, changeDirection);
        changeDirection = true;
        yield return new DynamicTable.Entry(end, blockSize, true);
        start += blockSize;
        end -= blockSize;
      }
    }

    /// <summary>
    /// Writes data blocks for a fancy screen load.
    /// </summary>
    /// <param name='output'>
    /// The stream to which to write the blocks.
    /// </param>
    /// <param name='table'>
    /// The dynamic table defining the blocks to load.
    /// </param>
    /// <param name='screenData'>
    /// 6912 bytes of screen data.
    /// </param>
    /// <param name='blockHeaderTemplate'>
    /// Template values to use when writing block headers.
    /// </param>
    internal static void WriteData(Stream output,
                                   DynamicTable table,
                                   IList<byte> screenData,
                                   TurboBlockHeader blockHeaderTemplate)
    {
      if (screenData.Count != 6912)
      {
        Console.Error.WriteLine("not a 6912 byte screen");
        Environment.Exit(1);
      }

      var fixedLength = table.IsFixedLength;
      var tableBytes = ((IEnumerable<byte>)table).ToArray();

      // first, write a block containg the length of the table
      var tableLengthBlockData =
        new HighLow16((ushort)tableBytes.Length).ToArray();
      var block = new Block
        (blockHeaderTemplate.DeepCopy(), tableLengthBlockData);
      // all the blocks comprising the screen must be glued
      block.BlockHeader.Pause = 0;
      block.WriteBlock(output);

      // next, write the table itself
      block = new Block(blockHeaderTemplate.DeepCopy(), tableBytes);
      block.BlockHeader.Pause = 0;
      block.BlockHeader.PilotPulseCount =
        FortySevenLoaderTzx.TinyPilotPulseCount; // for glued block
      block.WriteBlock(output);

      // now we write the blocks as specified by the table
      bool backwards = false;
      foreach (DynamicTable.Entry entry in table)
      {
        int offset = entry.Address - 16384;
        if (entry.ChangeDirection)
          backwards = !backwards;
        // for backwards loading, the address is the last byte
        if (backwards)
          offset -= (entry.Length - 1);
        var blockData = screenData.Skip(offset).Take(entry.Length);
        if (backwards)
          blockData = blockData.Reverse();
        block = new Block(blockHeaderTemplate.DeepCopy(), blockData);
        block.BlockHeader.PilotPulseCount =
          FortySevenLoaderTzx.TinyPilotPulseCount;
        // leave the pause length alone for the very last block
        if (!ReferenceEquals(entry, table.Last<DynamicTable.Entry>()))
          block.BlockHeader.Pause = 0;
        block.WriteBlock(output);
      }

      Console.Error.WriteLine
        ("Dynamic table length: {0} bytes", tableBytes.Length);
      if (fixedLength)
      {
        Console.Error.WriteLine("Define LOADER_DYNAMIC_FIXED_LENGTH EQU " +
                                (ushort)table[0].Length);
        return;
      }
      if (!table.Any<DynamicTable.Entry>(entry => entry.Length > 127))
        // compact table -- need to define this
        Console.Error.WriteLine("Define LOADER_DYNAMIC_ONE_BYTE_LENGTHS");
      if (!table.Any<DynamicTable.Entry>(entry => entry.ChangeDirection))
        // defining this saves us a few bytes
        Console.Error.WriteLine("Define LOADER_DYNAMIC_FORWARDS_ONLY");
      else
        // remind the user to define this because I forget otherwise
        Console.Error.WriteLine("Define LOADER_CHANGE_DIRECTION");
    }

    #endregion
  }
}
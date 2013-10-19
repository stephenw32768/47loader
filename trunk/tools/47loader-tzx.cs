// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

using BlockHeader = FortySevenLoader.Tzx.TurboBlockHeader;

namespace FortySevenLoader
{
  /// <summary>
/// Low-level "mastering" tool for 47loader.
/// </summary>
  public static class FortySevenLoaderTzx
  {
    // 47loader data block
    private sealed class Block
    {
      private readonly BlockHeader _blockHeader;
      private readonly List<byte> _data = new List<byte>();

      internal Block(BlockHeader header, IEnumerable<byte> rawData)
      {
        _blockHeader = header;
        _data.AddRange(rawData);
      }

    // Computes a Fletcher-16 checksum for _data.  H and L are
    // the starting values of the low byte (modular sum of each
    // data byte) and high byte (modular sum of each data byte
      // and the low byte of the checksum)
      void ComputeChecksum(ref byte h, ref byte l)
      {
        foreach (byte b in _data) {
          byte prev = l;
          l += b;
          if (prev > l)
            // overflowed; increment to simulate mod 255
            l++;
          prev = h;
          h += l;
          if (prev > h)
            h++;
        }
      }

      internal BlockHeader BlockHeader { get { return _blockHeader; } }

      internal void WriteBlock(Stream tapefile)
      {
        byte[] block;

        // toggle bits 4 and 7 of the entire block
        for (int i = 0; i < _data.Count; i++)
          _data[i] ^= 0x90;

        // calculate Fletcher16 checksum
        byte h = 0, l = 0, start_h, start_l;
        ComputeChecksum(ref h, ref l);
        start_l = l = (byte)(-l - 1);
          // rerun to determine correct starting value for H,
        // given the just-determined starting value for L
        h = 0;
        ComputeChecksum(ref h, ref l);
        start_h = h = (byte)(-h - 1);
        // so running the checksum with those starting values
        // should gives us 0xFFFF
        l = start_l;
        ComputeChecksum(ref h, ref l);
        Debug.Assert(l == 0xff, "expected l == 255 but got " + l);
        Debug.Assert(h == 0xff, "expected h == 255 but got " + h);

        // include checksum in data block.  LSB comes first
        _data.Insert(0, start_h);
        _data.Insert(0, start_l);

        // include sanity byte in block
        _data.Insert(0, _sanity);
      
        // write block header
        //if (includePilot)
        var blockHeader = _blockHeader.ToArray();
        tapefile.Write(blockHeader, 0, blockHeader.Length);
        //else
        //   _tapefile.Write(_pureDataBlockHeader, 0, _pureDataBlockHeader.Length);
        // write block length
        block = _data.ToArray();
        tapefile.WriteByte((byte)(block.Length & 255));
        tapefile.WriteByte((byte)((block.Length >> 8) & 255));
        tapefile.WriteByte((byte)((block.Length >> 16) & 255));
        // write block data
        tapefile.Write(block, 0, block.Length);
      }
    }

    private const int TStatesPerMillisecond = 3500;

    // pulse lengths, notionally constant
    private static readonly HighLow16 ZeroPulse =// new HighLow16(543);
      Pulse.Zero();
    private static readonly HighLow16 OnePulse = //new HighLow16(1086);
      Pulse.One();
    private static readonly HighLow16 PilotPulse = //new HighLow16(1710);
      Pulse.Pilot;

    private static readonly HighLow16 PilotPulseCount =
      (ushort)(1000 * TStatesPerMillisecond / PilotPulse);
    // this is used for embedding tiny pilots for instascreen and
    // progressive loading
    private static readonly HighLow16 TinyPilotPulseCount = new HighLow16(2);

    private static readonly byte _sanity =
      Convert.ToByte("10110010", 2);
    private static readonly List<byte> _data = new List<byte>();

    private static readonly BlockHeader _blockHeader = new BlockHeader {
      PilotPulse = FortySevenLoaderTzx.PilotPulse,
      PilotPulseCount = FortySevenLoaderTzx.PilotPulseCount,
      SyncPulse0 = FortySevenLoaderTzx.ZeroPulse,
      SyncPulse1 = FortySevenLoaderTzx.OnePulse,
      ZeroPulse = FortySevenLoaderTzx.ZeroPulse,
      OnePulse = FortySevenLoaderTzx.OnePulse,
      Pause = new HighLow16(250)
    };

    // mutable bits
    private static Stream _tapefile;
    private static bool _reverse;
    private static bool _noHeader;
    private static string _outputFileName;
    private static ushort _progressive;
    private static Action WriteData = WriteData_Simple;

    // parses string into integer
    static T ParseInteger<T>(string s)
    {
      try {
      T rv = (T)Convert.ChangeType(s, typeof(T));
      return rv;
    } catch {
        Console.Error.WriteLine("Bad integer: " + s);
        Die();
        return default(T);
      }
    }

    // parses options, returns array of file names
    static string[] ParseArguments(string[] args)
    {
      for (int i = 0; i < args.Length; i++)
      {
        if (args[i].FirstOrDefault() != '-')
        {
          // we've come to the end of the options, all the rest
          // are files
          return args.Skip(i).ToArray();
        }

        switch (args[i].TrimStart('-'))
        {
          case "noheader":
            _noHeader = true;
            break;

          case "reverse":
            _reverse = true;
            break;

          case "pilot":
          // next arg is pilot length in milliseconds
            checked
            {
              int ms = ParseInteger<int>(args[++i]);
              int tstates = ms * TStatesPerMillisecond;
              HighLow16 pilotPulses = (ushort)(tstates / PilotPulse);
              _blockHeader.PilotPulseCount = pilotPulses;
            }
            break;

          case "pause":
          // next arg is pause length in milliseconds
            checked
            {
              HighLow16 ms = ParseInteger<ushort>(args[++i]);
              _blockHeader.Pause = ms;
            }
            break;

          case "extracycles":
            sbyte cycles = ParseInteger<sbyte>(args[++i]);
            HighLow16 new0 = Pulse.Zero(cycles);
            HighLow16 new1 = Pulse.One(cycles);
            _blockHeader.SyncPulse0 = _blockHeader.ZeroPulse = new0;
            _blockHeader.SyncPulse1 = _blockHeader.OnePulse = new1;
            break;

          case "instascreen":
            WriteData = WriteData_Instascreen;
            break;

          case "progressive":
          // next arg is number of progressive chunks
            checked
            {
              _progressive = ParseInteger<ushort>(args[++i]);
            }
            WriteData = WriteData_Progressive;
            break;

          case "output":
            // next arg is name of file to which to write
            _outputFileName = args[++i];
            if (File.Exists(_outputFileName))
              _noHeader = true;
            break;

          default:
          // unknown option
            Console.Error.WriteLine("Unknown option \"{0}\"", args[i]);
            goto die;
        }
      }

      // still here?  Bad option or no files...
      die:
      Die();
      return null;
    }

    // prints usage and exists unsuccessfully
    static void Die()
    {
      Console.Error.WriteLine(@"Usage: 47loader-tzx [options] file [file ...]

Options:
-extracycles n: additional 34T cycles to add to timings.  May be negative
-instascreen  : create a screen block for use with 47loader_instascreen
-noheader     : omit the TZX file header (automatically selected if output
                file already exists)
-output       : name of file to write; if not specified, writes to standard
                output.  Appends to file if it already exists
-pause n      : pause n milliseconds after block
-pilot n      : length of pilot in milliseconds
-progressive n: create a progressively-loaded block with n chunks
-reverse      : reverse the block");
      Environment.Exit(1);
    }

    // opens the output file or stream
    private static Stream OpenOutput()
    {
      if (string.IsNullOrWhiteSpace(_outputFileName))
        return Console.OpenStandardOutput();

      var str = File.Open(_outputFileName, FileMode.OpenOrCreate);
      str.Seek(0, SeekOrigin.End);
      return str;
    }

    // normal implementation of WriteData for simple blocks
    private static void WriteData_Simple()
    {
      Block block = new Block(_blockHeader, _data);
      block.WriteBlock(_tapefile);
    }

  // WriteData implementation for progressive loads
    private static void WriteData_Progressive()
    {
      Block block;

      checked {
        // calculate lengths of chunks; should be as even as possible
        var lengths = (from i in Enumerable.Range(0, _progressive)
                       let l = (ushort)(_data.Count / _progressive)
                       select new HighLow16(l)).ToArray();
        int remainder = _data.Count % _progressive;
        for (int i = 0; i < remainder; i++)
          lengths[i] += 1;
        // each block apart from the last one contains the length of
      // the next at the end; these extra two bytes need including
      // in the lengths
        for (int i = 0; i < lengths.Length - 1; i++)
          lengths[i] += 2;

        // first "bootstrap" block is just the length of the first real
      // block
        block = new Block(_blockHeader.DeepCopy(), lengths[0]);
        block.BlockHeader.Pause = HighLow16.Zero;
        block.WriteBlock(_tapefile);

        // each chunk includes the length of the next block at the end
        int bytesDone = 0, byteCount;
        for (int i = 0; i < (_progressive - 1); i++) {
          // the last two bytes in the block are the length of the
        // next, so we don't include them in the number of bytes
        // to take from _data
          byteCount = (ushort)lengths[i] - 2;
          block = new Block(_blockHeader.DeepCopy(),
                            _data.Skip(bytesDone).Take(byteCount)
                            .Concat(lengths[i + 1]));
          block.BlockHeader.PilotPulseCount = TinyPilotPulseCount;
          block.BlockHeader.Pause = HighLow16.Zero;
          block.WriteBlock(_tapefile);
          bytesDone += byteCount;
        }
        // except the very last chunk, of course; that's just data
      // on its own, and doesn't have its pause forced to zero
        byteCount = (ushort)lengths.Last();
        block = new Block(_blockHeader.DeepCopy(),
                          _data.Skip(bytesDone).Take(byteCount));
        block.BlockHeader.PilotPulseCount = TinyPilotPulseCount;
        block.WriteBlock(_tapefile);
      }
    }

    // WriteData implementation for instascreens
    private static void WriteData_Instascreen()
    {
      if (_data.Count != 6912) {
        Console.Error.WriteLine("not a 6912 byte screen");
        Environment.Exit(1);
      }

      // one block for the pixmap with no pause
      var block = new Block(_blockHeader.DeepCopy(), _data.Take(6144));
      block.BlockHeader.Pause = 0;
      block.WriteBlock(_tapefile);
      // one block for the attrs with short pilot
      block = new Block(_blockHeader.DeepCopy(), _data.Skip(6144));
      block.BlockHeader.PilotPulseCount = TinyPilotPulseCount;
      block.BlockHeader.Pause = 0;
      block.WriteBlock(_tapefile);
      // pulses for the loader to read through while it blits
    // the attrs
      const int shortPulseCount = 17;
      const ushort shortPulseLength = 1280;
      const int pilotPulseCount = 12;
      //*
      var pulses = (from i in Enumerable.Range(0, shortPulseCount)
                    select new HighLow16(shortPulseLength))
        .Concat(from i in Enumerable.Range(0, pilotPulseCount)
                select _blockHeader.PilotPulse).ToArray();
      var count = (byte)pulses.Length;
      var bytes = new[] { (byte)0x13, // TZX block ID for pulse sequence
        count }.Concat(from pulse in pulses
                     from b in pulse
                     select b).ToArray();
      _tapefile.Write(bytes, 0, bytes.Length);
    //*/
    // one pulse per block, for test/debug:
    /*
    foreach (var pulse in (from i in Enumerable.Range(0, shortPulseCount)
                           select new HighLow16(shortPulseLength))
             .Concat(from i in Enumerable.Range(0, pilotPulseCount)
                     select _blockHeader.PilotPulse)) {
      var bytes = new byte[] { 0x13, 1, pulse.Low, pulse.High };
      _tapefile.Write(bytes, 0, bytes.Length);
    }
    //*/
  }

    public static int Main(string[] args)
    {
      if (args.Length < 1) {
        Die();
        return 1;
      }

      try {
        var files = ParseArguments(args);

        using (var data = new MemoryStream())
        using (_tapefile = OpenOutput()) {
          for (int i = 0; i < files.Length; i++) {
            if (!File.Exists(files[i])) {
              Console.Error.WriteLine("File not found: " + files[i]);
              Die();
            }
            using (var file = File.OpenRead(files[i])) {
              file.CopyTo(data);
            }
          }

          if (!_noHeader)
            Tzx.FileHeader.Standard.Write(_tapefile);
          _data.AddRange(data.ToArray());
          if (_reverse)
            _data.Reverse();
          WriteData();
        }
      }
      catch (Exception e) {
        Console.Error.WriteLine
          ("{0}: {1}", e.GetType().FullName, e.Message);
        Console.Error.WriteLine(e.StackTrace);
        Console.Error.WriteLine();
        Die();
        return 1;
      }

      return 0;
    }
  }
}

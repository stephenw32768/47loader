// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

// "mastering" tool for 47loader
public static class FortySevenLoaderTzx
{
  private const int TStatesPerMillisecond = 3500;

  // pulse lengths, notionally constant
  private static readonly HighLow16 ZeroPulse = new HighLow16(543);
  private static readonly HighLow16 OnePulse = new HighLow16(1086);
  private static readonly HighLow16 PilotPulse = new HighLow16(1710);

  private static readonly HighLow16 PilotPulseCount =
    (ushort)(1000 * TStatesPerMillisecond / PilotPulse);

  private static readonly byte _sanity =
    Convert.ToByte("01001101", 2);
  private static readonly List<byte> _data = new List<byte>();
  private static readonly byte[] _blockHeader = {
    0x11,       // turbo block ID
    PilotPulse.Low, PilotPulse.High, // pilot pulse length
    ZeroPulse.Low,  ZeroPulse.High,  // first sync pulse length
    OnePulse.Low, OnePulse.High,     // second sync pulse length
    ZeroPulse.Low,  ZeroPulse.High,  // zero bit pulse length
    OnePulse.Low, OnePulse.High,     // one bit pulse length
    PilotPulseCount.Low, PilotPulseCount.High, // pulses in pilot tone
    0x08,       // bits in the last byte
    250, 0      // 250ms pause after block
  };
  /*
  private static readonly byte[] _pureDataBlockHeader = {
    0x14,       // pure data block ID
    ZeroPulse.Low,  ZeroPulse.High,  // zero bit pulse length
    OnePulse.Low, OnePulse.High,     // one bit pulse length
    0x08,       // bits in the last byte
    0, 0        // no pause after block
  };
  //*/

  // mutable bits
  private static Stream _tapefile;
  private static bool _reverse;
  
  // Computes a Fletcher-16 checksum for _data.  H and L are
  // the starting values of the low byte (modular sum of each
  // data byte) and high byte (modular sum of each data byte
  // and the low byte of the checksum)
  static void ComputeChecksum(ref byte h, ref byte l)
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
    for (int i = 0; i < args.Length; i++) {
      if (args[i].FirstOrDefault() != '-') {
        // we've come to the end of the options, all the rest
        // are files
        return args.Skip(i).ToArray();
      }

      switch (args[i].TrimStart('-')) {
      case "reverse":
        _reverse = true;
        break;

      case "pilot":
        // next arg is pilot length in milliseconds
        checked {
          int ms = ParseInteger<int>(args[++i]);
          int tstates = ms * TStatesPerMillisecond;
          HighLow16 pilotPulses = (ushort)(tstates / PilotPulse);

          _blockHeader[11] = pilotPulses.Low;
          _blockHeader[12] = pilotPulses.High;
        }
        break;

      case "pause":
        // next arg is pause length in milliseconds
        checked {
          HighLow16 ms = ParseInteger<ushort>(args[++i]);

          _blockHeader[14] = ms.Low;
          _blockHeader[15] = ms.High;
        }
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
Writes tape files to standard output

Options:
-reverse: reverse the block
-pilot n: length of pilot in milliseconds
-pause n: pause n milliseconds after block");
    Environment.Exit(1);
  }

  private static void AppendBlock()
  {
    // checksum includes sanity byte
    byte[] block;

    // toggle bits 4 and 7 of the entire block
    for (int i = 0; i < _data.Count; i++)
      _data[i] ^= 0x90;

    if (_reverse)
      _data.Reverse();

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
    _tapefile.Write(_blockHeader, 0, _blockHeader.Length);
    //else
    //   _tapefile.Write(_pureDataBlockHeader, 0, _pureDataBlockHeader.Length);
    // write block length
    block = _data.ToArray();
    _tapefile.WriteByte((byte)(block.Length & 255));
    _tapefile.WriteByte((byte)((block.Length >> 8) & 255));
    _tapefile.WriteByte((byte)((block.Length >> 16) & 255));
    // write block data
    _tapefile.Write(block, 0, block.Length);
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
      using (_tapefile = Console.OpenStandardOutput()) {
        for (int i = 0; i < files.Length; i++) {
          if (!File.Exists(files[i])) {
            Console.Error.WriteLine("File not found: " + files[i]);
            Die();
          }
          using (var file = File.OpenRead(files[i])) {
            file.CopyTo(data);
          }
        }

        _tapefile.Write(Encoding.ASCII.GetBytes("ZXTape!\x1a\x01\x14"), 0, 10);
        _data.AddRange(data.ToArray());
        AppendBlock();
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

// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

// "mastering" tool for 47loader
public static class FortySevenLoaderTzx
{
  // representation of a pulse length in T-states
  private struct PulseLength
  {
    private readonly short _l;
    internal PulseLength(short l) { _l = l; }

    // high byte
    internal byte High { get { return (byte)(_l >> 8); } }
    // low byte
    internal byte Low { get { return (byte)(_l & 0xff); } }
  }

  // pulse lengths, notionally constant
  private static readonly PulseLength ZeroPulse = new PulseLength(543);
  private static readonly PulseLength OnePulse = new PulseLength(1086);
  private static readonly PulseLength PilotPulse = new PulseLength(2168);

  private static readonly byte _sanity =
    Convert.ToByte("01001101", 2);
  private static Stream _tapefile;
  private static byte _checksum = _sanity;
  private static readonly byte[] _blockHeader = {
    0x11,       // turbo block ID
    PilotPulse.Low, PilotPulse.High, // pilot pulse length
    ZeroPulse.Low,  ZeroPulse.High,  // first sync pulse length
    OnePulse.Low, OnePulse.High,     // second sync pulse length
    ZeroPulse.Low,  ZeroPulse.High,  // zero bit pulse length
    OnePulse.Low, OnePulse.High,     // one bit pulse length
    0xd0, 0x07, // pulses in pilot tone, 2000, 0x7d0
    0x08,       // bits in the last byte
    0, 0        // no pause after block
  };
  private static readonly byte[] _pureDataBlockHeader = {
    0x14,       // pure data block ID
    ZeroPulse.Low,  ZeroPulse.High,  // zero bit pulse length
    OnePulse.Low, OnePulse.High,     // one bit pulse length
    0x08,       // bits in the last byte
    0, 0        // no pause after block
  };
  

  private static void AppendBlock(string filename,
                                  bool includePilot,
                                  bool includeChecksum)
  {
    // checksum includes sanity byte
    byte[] block;

    // read block and calculate checksum
    using (var str = File.OpenRead(filename)) {
      var bytes = new List<byte>();
      int cur;

      if (includePilot)
        bytes.Add(_sanity);
      while ((cur = str.ReadByte()) >= 0) {
        byte curByte = (byte)(cur ^ 0x90); // toggle bits 4 and 7
        _checksum ^= curByte;
        bytes.Add(curByte);
      }
      if (includeChecksum)
        bytes.Add(_checksum);
      block = bytes.ToArray();
    }
      
    // write block header
    if (includePilot)
      _tapefile.Write(_blockHeader, 0, _blockHeader.Length);
    else
      _tapefile.Write(_pureDataBlockHeader, 0, _pureDataBlockHeader.Length);
    // write block length
    _tapefile.WriteByte((byte)(block.Length & 255));
    _tapefile.WriteByte((byte)((block.Length >> 8) & 255));
    _tapefile.WriteByte((byte)((block.Length >> 16) & 255));
    // write block data
    _tapefile.Write(block, 0, block.Length);
  }

  public static int Main(string[] args)
  {
    if (args.Length < 1) {
      Console.Error.WriteLine("Usage: 47loader-tzx file [file ...]");
      Console.Error.WriteLine("Writes tape files to standard output");
      return 1;
    }

    try {
      using (_tapefile = Console.OpenStandardOutput()) {
        _tapefile.Write(Encoding.ASCII.GetBytes("ZXTape!\x1a\x01\x14"), 0, 10);
        for (int i = 0, stop = args.Length - 1; i <= stop; i++)
          AppendBlock(args[i], i == 0, i == stop);
      }
    }
    catch (Exception e) {
      Console.Error.WriteLine
        ("{0}: {1}", e.GetType().FullName, e.Message);
      Console.Error.WriteLine(e.StackTrace);
      return 1;
    }

    return 0;
  }
}

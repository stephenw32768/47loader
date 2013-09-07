// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.Diagnostics;
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
  private static List<byte> _data = new List<byte>();
  private static Stream _tapefile;
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
  /*
  private static readonly byte[] _pureDataBlockHeader = {
    0x14,       // pure data block ID
    ZeroPulse.Low,  ZeroPulse.High,  // zero bit pulse length
    OnePulse.Low, OnePulse.High,     // one bit pulse length
    0x08,       // bits in the last byte
    0, 0        // no pause after block
  };
  //*/

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

  private static void AppendBlock()
  {
    // checksum includes sanity byte
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
      Console.Error.WriteLine("Usage: 47loader-tzx file [file ...]");
      Console.Error.WriteLine("Writes tape files to standard output");
      return 1;
    }

    try {
      using (var data = new MemoryStream())
      using (_tapefile = Console.OpenStandardOutput()) {
        _tapefile.Write(Encoding.ASCII.GetBytes("ZXTape!\x1a\x01\x14"), 0, 10);
        for (int i = 0, stop = args.Length - 1; i <= stop; i++) {
          using (var file = File.OpenRead(args[i])) {
            file.CopyTo(data);
          }
        }

        _data.AddRange(data.ToArray());
        AppendBlock();
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

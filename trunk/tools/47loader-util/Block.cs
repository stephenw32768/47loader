// 47loader (c) Stephen Williams 2013

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

using BlockHeader = FortySevenLoader.Tzx.TurboBlockHeader;

namespace FortySevenLoader
{
  /// <summary>
  /// Representation of a 47loader data block,
  /// </summary>
  public class Block
  {
    /// <summary>
    /// The value of the sanity-check byte at the beginning of a 47loader
    /// block.
    /// </summary>
    private static readonly byte _sanity = Convert.ToByte("10110010", 2);

    /// <summary>
    /// The block header.
    /// </summary>
    private readonly BlockHeader _blockHeader;

    /// <summary>
    /// The block data.
    /// </summary>
    private readonly List<byte> _data = new List<byte>();

    /// <summary>
    /// Initializes a new instance of the
    /// <see cref="FortySevenLoader.Block"/> class.
    /// </summary>
    /// <param name='header'>
    /// The block header.
    /// </param>
    /// <param name='rawData'>
    /// The block data.
    /// </param>
    public Block(BlockHeader header, IEnumerable<byte> rawData)
    {
      _blockHeader = header;
      _data.AddRange(rawData);
    }

    #region Private methods

    // Computes a Fletcher-16 checksum for _data.  H and L are
    // the starting values of the low byte (modular sum of each
    // data byte) and high byte (modular sum of each data byte
    // and the low byte of the checksum)
    void ComputeChecksum(ref byte h, ref byte l)
    {
      foreach (byte b in _data)
      {
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

    #endregion

    #region Public methods

    /// <summary>
    /// Gets the block header.
    /// </summary>
    /// <value>
    /// The block header.
    /// </value>
    public BlockHeader BlockHeader { get { return _blockHeader; } }

    /// <summary>
    /// Writes the block to a TZX tape file stream.
    /// </summary>
    /// <param name='tapefile'>
    /// The output tape file stream.
    /// </param>
    public void WriteBlock(Stream tapefile)
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

    #endregion
  }
}


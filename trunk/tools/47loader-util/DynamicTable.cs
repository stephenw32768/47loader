// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace FortySevenLoader
{
  /// <summary>
  /// A table of block addresses and lengths for dynamic loading.
  /// </summary>
  public class DynamicTable : Collection<DynamicTable.Entry>, IEnumerable<byte>
  {
    /// <summary>
    /// An individual entry in a <see cref="DynamicTable"/>.
    /// </summary>
    public sealed class Entry : IEnumerable<byte>
    {
      /// <summary>
      /// Initializes a new instance of the
      /// <see cref="FortySevenLoader.DynamicTable+Entry"/> class.
      /// </summary>
      /// <param name="address">
      /// The address at which to load the block.
      /// </param>
      /// <param name="length">
      /// The length of the block, at most 32767 bytes.
      /// </param>
      /// <param name="changeDirection">
      /// Set if the loader should change direction before loading the
      /// block.
      /// </param>
      public Entry(HighLow16 address,
                   HighLow16 length,
                   bool changeDirection = false)
      {
        // bit 15 of the length is used for the direction change flag
        if (length > 32767)
          throw new ArgumentOutOfRangeException("length");

        Address = address;
        Length = length;
        ChangeDirection = changeDirection;
      }

      /// <summary>
      /// The address at which to load the block.
      /// </summary>
      public readonly HighLow16 Address;

      /// <summary>
      /// The length of the block, at most 32767 bytes.
      /// </summary>
      public readonly HighLow16 Length;

      /// <summary>
      /// Set if the loader should change direction before loading the
      /// block.
      /// </summary>
      public readonly bool ChangeDirection;

      /// <summary>
      /// Gets an enumerator over the bytes comprising the table entry.
      /// </summary>
      /// <returns>
      /// The enumerator.
      /// </returns>
      public IEnumerator<byte> GetEnumerator()
      {
        // big-endian format is used because the high byte of the address
        // will never be zero, so we can use this as an end-of-table marker

        // address first, big-endian
        yield return Address.High;
        yield return Address.Low;

        // bit 15 of the length is set if ChangeDirection is set
        if (ChangeDirection)
          yield return (byte)(128 | Length.High);
        else
          yield return Length.High;
        yield return Length.Low;
      }

      IEnumerator IEnumerable.GetEnumerator()
      {
        return GetEnumerator();
      }
    }

    /// <summary>
    /// Initializes a new instance of the
    /// <see cref="FortySevenLoader.DynamicTable"/> class.
    /// </summary>
    public DynamicTable()
    {
    }

    /// <summary>
    /// Initializes a new instance of the
    /// <see cref="FortySevenLoader.DynamicTable"/> class.
    /// </summary>
    /// <param name='entries'>
    /// The entries with which to populate the table.
    /// </param>
    public DynamicTable(IEnumerable<DynamicTable.Entry> entries)
    {
      foreach (var entry in entries)
        Add(entry);
    }

    /// <summary>
    /// Gets an enumerator over the bytes comprising the table.
    /// </summary>
    /// <returns>
    /// The enumerator.
    /// </returns>
    IEnumerator<byte> IEnumerable<byte>.GetEnumerator()
    {
      foreach (var entry in this)
        foreach (var b in entry)
          yield return b;
      // end-of-table marker
      yield return (byte)0;
    }
  }
}
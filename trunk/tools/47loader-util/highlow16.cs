// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System.Collections;
using System.Collections.Generic;

/// <summary>
/// 16-bit unsigned integer wrapper with easy access to high/low bytes.
/// </summary>
public struct HighLow16 : IEnumerable<byte>
{
  #region Private fields

  private readonly ushort _us;

  #endregion

  #region Constructor

  /// <summary>
  /// Initializes a new instance of the <see cref="HighLow16"/> struct.
  /// </summary>
  /// <param name='us'>
  /// A 16-bit unsigned integer to represent as high and low bytes..
  /// </param>
  public HighLow16(ushort us) { _us = us; }

  #endregion

  #region Class properties

  /// <summary>
  /// A <see cref="HighLow16"/> value equal to zero.
  /// </summary>
  public static readonly HighLow16 Zero = new HighLow16(0);

  #endregion

  #region Properties

  /// <summary>
  /// The high byte.
  /// </summary>
  public byte High { get { return (byte)(_us >> 8); } }
  /// <summary>
  /// The low byte.
  /// </summary>
  public byte Low { get { return (byte)(_us & 0xff); } }

  #endregion

  #region Type conversion

  /// <summary>
  /// Converts a <see cref="HighLow16"/> into a 16-bit
  /// unsigned integer.
  /// </summary>
  /// <param name='hl16'>
  /// The <see cref="HighLow16"/> instance to convert.
  /// </param>
  public static implicit operator ushort(HighLow16 hl16)
  {
    return hl16._us;
  }

  /// <summary>
  /// Converts a 16-bit unsigned integer into a
  /// <see cref="HighLow16"/> instance.
  /// </summary>
  /// <param name='us'>
  /// The integer to convert.
  /// </param>
  public static implicit operator HighLow16(ushort us)
  {
    return new HighLow16(us);
  }

  #endregion

  #region IEnumerator<byte> implementation

  /// <summary>
  /// Gets an enumerator over the bytes, LSB first.
  /// </summary>
  /// <returns>
  /// The enumerator.
  /// </returns>
  public IEnumerator<byte> GetEnumerator()
  {
    yield return Low;
    yield return High;
  }

  IEnumerator IEnumerable.GetEnumerator()
  {
    return GetEnumerator();
  }

  #endregion
}

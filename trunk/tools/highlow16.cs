// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System.Collections;
using System.Collections.Generic;

// 16-bit int wrapper with easy access to high/low bytes
internal struct HighLow16 : IEnumerable<byte>
{
  private readonly ushort _us;
  internal HighLow16(ushort us) { _us = us; }

  // high byte
  internal byte High { get { return (byte)(_us >> 8); } }
  // low byte
  internal byte Low { get { return (byte)(_us & 0xff); } }

  internal static readonly HighLow16 Zero = new HighLow16(0);

  public static implicit operator ushort(HighLow16 hl16)
  {
    return hl16._us;
  }

  public static implicit operator HighLow16(ushort us)
  {
    return new HighLow16(us);
  }

  public IEnumerator<byte> GetEnumerator()
  {
    yield return Low;
    yield return High;
  }

  IEnumerator IEnumerable.GetEnumerator()
  {
    return GetEnumerator();
  }
}

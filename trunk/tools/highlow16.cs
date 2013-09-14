// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

// 16-bit int wrapper with easy access to high/low bytes
internal struct HighLow16
{
  private readonly ushort _us;
  internal HighLow16(ushort us) { _us = us; }

  // high byte
  internal byte High { get { return (byte)(_us >> 8); } }
  // low byte
  internal byte Low { get { return (byte)(_us & 0xff); } }

  public static implicit operator ushort(HighLow16 hl16)
  {
    return hl16._us;
  }

  public static implicit operator HighLow16(ushort us)
  {
    return new HighLow16(us);
  }
}

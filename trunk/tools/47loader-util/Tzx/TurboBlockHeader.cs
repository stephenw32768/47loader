// 47loader (c) Stephen Williams 2013-2015
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.Collections;

namespace FortySevenLoader.Tzx
{
  /// <summary>
  /// Representation of a TZX turbo block header.
  /// </summary>
  public sealed class TurboBlockHeader : IEnumerable<byte>
  {
    /// <summary>
    /// The length of the first sync pulse in T-states.
    /// </summary>
    public HighLow16 SyncPulse0 { get; set; }

    /// <summary>
    /// The length of the second sync pulse in T-states.
    /// </summary>
    public HighLow16 SyncPulse1 { get; set; }

    /// <summary>
    /// The length of a pilot pulse in T-states.
    /// </summary>
    public HighLow16 PilotPulse { get; set; }

    /// <summary>
    /// The number of pilot pulses.
    /// </summary>
    public HighLow16 PilotPulseCount { get; set; }

    /// <summary>
    /// For a clicking pilot, the length of the click pulse in T-states.
    /// </summary>
    /// <remarks>
    /// Not part of a TZX turbo block header; clicking pilots are implemented
    /// by prepending additional TZX blocks.
    /// </remarks>
    public HighLow16 PilotClickPulse { get; set; }

    /// <summary>
    /// For a clicking pilot, the number of clicks.  Implemented by
    /// writing this many pilot tones of length
    /// <see cref="PilotPulse"/> with two pulses of length
    /// <see cref="PilotClickPulse"/> in between.
    /// </summary>
    /// <remarks>
    /// Not part of a TZX turbo block header; clicking pilots are implemented
    /// by prepending additional TZX blocks.
    /// </remarks>
    public HighLow16 PilotClickCount { get; set; }

    /// <summary>
    /// The length of a zero pulse in T-states.
    /// </summary>
    public HighLow16 ZeroPulse { get; set; }

    /// <summary>
    /// The length of a one pulse in T-states.
    /// </summary>
    public HighLow16 OnePulse { get; set; }

    /// <summary>
    /// The number of milliseconds to pause at the end of the block.
    /// </summary>
    public HighLow16 Pause { get; set; }

    /// <summary>
    /// Clones the instance.
    /// </summary>
    /// <returns>
    /// A copy of the current <see cref="TurboBlockHeader"/> instance.
    /// </returns>
    public TurboBlockHeader DeepCopy()
    {
      return new TurboBlockHeader {
        SyncPulse0 = this.SyncPulse0,
        SyncPulse1 = this.SyncPulse1,
        PilotPulse = this.PilotPulse,
        PilotClickPulse = this.PilotClickPulse,
        ZeroPulse = this.ZeroPulse,
        OnePulse = this.OnePulse,
        PilotPulseCount = this.PilotPulseCount,
        PilotClickCount = this.PilotClickCount,
        Pause = this.Pause
      };
    }

    /// <summary>
    /// Converts the block header into a sequence of bytes for writing
    /// to a stream.  The bytes follow the specification at
    /// http://www.worldofspectrum.org/TZXformat.html#TURBOSPEED
    /// </summary>
    /// <returns>
    /// An enumerator over the byte sequence.
    /// The enumerator.
    /// </returns>
    public IEnumerator<byte> GetEnumerator()
    {
      yield return 0x11; // turbo block ID
      foreach (var field in new[] {
          PilotPulse, SyncPulse0, SyncPulse1, ZeroPulse, OnePulse,
          PilotPulseCount
        }) {
        yield return field.Low;
        yield return field.High;
      }
      yield return 8; // last byte has all eight bits
      yield return Pause.Low;
      yield return Pause.High;
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
      return GetEnumerator();
    }
  }
}

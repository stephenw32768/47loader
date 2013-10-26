// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;

namespace FortySevenLoader
{
  /// <summary>
  /// Constants and utility methods relating to pulse lengths.
  /// </summary>
  public static class Pulse
  {
    /// <summary>
    /// Constants relating to the pulse lengths used by the ROM loader.
    /// </summary>
    public static class Rom
    {
      /// <summary>
      /// The length of a pilot pulse in T-states.
      /// </summary>
      public const ushort Pilot = 2168;

      /// <summary>
      /// The length of the first sync pulse in T-states.
      /// </summary>
      public const ushort Sync0 = 667;

      /// <summary>
      /// The length of the second sync pulse in T-states.
      /// </summary>
      public const ushort Sync1 = 735;

      /// <summary>
      /// The length of a zero pulse in T-states.
      /// </summary>
      public const ushort Zero = 855;

      /// <summary>
      /// The length of a one sync pulse in T-states.
      /// </summary>
      public const ushort One = 1710;
    }

    /// <summary>
    /// The length of a 47loader pilot pulse in T-states.
    /// </summary>
    public const ushort Pilot = Rom.One;

    /// <summary>
    /// Gets the length of a zero pulse in T-states.  This length is also
    /// used for the first sync pulse.
    /// </summary>
    /// <param name='extraCycles'>
    /// The speed of the loader, expressed as the number of extra 34T cycles
    /// around the sampling loop.
    /// </param>
    /// <returns>
    /// The pulse length.
    /// </returns>
    public static ushort Zero(sbyte extraCycles = 0)
    {
      const ushort standard = 543;
      const ushort tPerCycle = 34;
      checked {
        var length = (ushort)(standard + (extraCycles * tPerCycle));

        return length;
      }
    }

    /// <summary>
    /// Gets the length of a one pulse in T-states.  This length is also
    /// used for the second sync pulse.
    /// </summary>
    /// <param name='extraCycles'>
    /// The speed of the loader, expressed as the number of extra 34T cycles
    /// around the sampling loop.
    /// </param>
    /// <returns>
    /// The pulse length.
    /// </returns>
    public static ushort One(sbyte extraCycles = 0)
    {
      checked {
        var length = (ushort)(2 * Zero(extraCycles));
        return length;
      }
    }
  }
}

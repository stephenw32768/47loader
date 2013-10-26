// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;

namespace FortySevenLoader
{
  /// <summary>
  /// The timing for the loader.  The numeric values of the constants
  /// are the extra sampling loop cycles to specify.
  /// </summary>
  [Serializable]
  public enum Timing
  {
    /// <summary>
    /// Standard 47loader timings, 543/1086T, ~160% of ROM loader speed.
    /// </summary>
    Standard = 0,

    /// <summary>
    /// 509/1018T, ~170% of ROM loader speed.
    /// </summary>
    Eager = -1,

    /// <summary>
    /// 475/950T, ~185% of ROM loader speed.
    /// </summary>
    Fast = -2,

    /// <summary>
    /// 611/1222T, ~145% of ROM loader speed.
    /// </summary>
    Cautious = 2,

    /// <summary>
    /// 679/1358T, ~130% of ROM loader speed.
    /// </summary>
    Conservative = 4,

    /// <summary>
    /// 713/1426T, ~125% of ROM loader speed.
    /// </summary>
    Speedlock7 = 5,

    /// <summary>
    /// ROM timings, 875T/1710T.
    /// </summary>
    Rom = 128
  }
}


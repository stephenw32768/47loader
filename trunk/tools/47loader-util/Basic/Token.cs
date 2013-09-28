// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;

namespace FortySevenLoader.Basic
{
  /// <summary>
  /// The bytes representing BASIC tokens.
  /// </summary>
  public enum Token : byte {

    /// <summary>
    /// The byte representing the BIN keyword.
    /// </summary>
    Bin = 0xc4,

    /// <summary>
    /// The byte representing the BORDER keyword.
    /// </summary>
    Border = 0xe7,

    /// <summary>
    /// The byte representing the BRIGHT keyword.
    /// </summary>
    Bright = 0xdc,

    /// <summary>
    /// The byte representing the CLEAR keyword.
    /// </summary>
    Clear = 0xfd,

    /// <summary>
    /// The byte representing the INK keyword.
    /// </summary>
    Ink = 0xd9,

    /// <summary>
    /// The byte representing the LPRINT keyword.
    /// </summary>
    Lprint = 0xe0,

    /// <summary>
    /// The byte representing the PAPER keyword.
    /// </summary>
    Paper = 0xda,

    /// <summary>
    /// The byte representing the PAUSE keyword.
    /// </summary>
    Pause = 0xf2,

    /// <summary>
    /// The byte representing the PRINT keyword.
    /// </summary>
    Print = 0xf5,

    /// <summary>
    /// The byte representing the PI keyword.
    /// </summary>
    Pi = 0xa7,

    /// <summary>
    /// The byte representing the RANDOMIZE keyword.
    /// </summary>
    Randomize = 0xf9,

    /// <summary>
    /// The byte representing the REM keyword.
    /// </summary>
    Rem = 0xea,

    /// <summary>
    /// The byte representing the SGN keyword.
    /// </summary>
    Sgn = 0xbc,

    //Sin = 0xb2,

    /// <summary>
    /// The byte representing the USR keyword.
    /// </summary>
    Usr = 0xc0,

    /// <summary>
    /// The byte representing the VAL keyword.
    /// </summary>
    Val = 0xb0,
  }
}

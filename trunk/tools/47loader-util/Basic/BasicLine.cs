// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

namespace FortySevenLoader.Basic
{
  // a single BASIC line

  /// <summary>
  /// Represents a single BASIC line.
  /// </summary>
  public sealed class BasicLine : IEnumerable<byte>
  {
    #region Constants

    /// <summary>
    /// The number of the first executable line in the program.
    /// </summary>
    public const ushort FirstLine = 9047; // OVER NINE THOUSAND!

    #endregion

    #region Class fields

    /// <summary>
    /// The line number to use in the next <see cref="BasicLine"/>
    /// instance to be created.
    /// </summary>
    static ushort _nextLineNumber = FirstLine;

    #endregion

    #region Instance fields

    /// <summary>
    /// The line number.
    /// </summary>
    readonly HighLow16 _lineNumber;

    /// <summary>
    /// The bytes making up the line.
    /// </summary>
    readonly List<byte> _lineData = new List<byte>();

    #endregion

    #region Constructor

    /// <summary>
    /// Initializes a new instance of the
    /// <see cref="FortySevenLoader.Basic.BasicLine"/> class.
    /// </summary>
    public BasicLine()
    {
      _lineNumber = _nextLineNumber++;
    }

    #endregion

    #region Public methods

    /// <summary>
    /// Adds a statement to the line.
    /// </summary>
    /// <param name='token'>
    /// The token representing the statement's keywords.
    /// Token.
    /// </param>
    /// <param name='args'>
    /// The arguments to pass to the keyword.
    /// </param>
    public void AddStatement(Token token, params object[] args)
    {
      if (_lineData.Count > 0)
        // close previous statement
        _lineData.Add((byte)':');
      _lineData.Add((byte)token);
      foreach (var arg in args) {
        if (arg is byte)
          _lineData.Add((byte)arg);
        else if (arg is Token)
          _lineData.Add((byte)(Token)arg);
        else if (arg is int || arg is ushort)
          AddInteger(Convert.ToInt32(arg));
        else if (arg is string)
          AddString((string)arg, token != Token.Rem);
        else if (arg is IEnumerable<string>)
          AddStrings((IEnumerable<string>)arg);
        else
          throw new NotSupportedException(arg.GetType().FullName);
      }
    }

    #endregion

    #region IEnumerable<byte> implementation

    /// <summary>
    /// Returns an enumerator over the bytes comprising the line of
    /// BASIC.
    /// </summary>
    /// <returns>
    /// The enumerator.
    /// </returns>
    public IEnumerator<byte> GetEnumerator()
    {
      // length includes trailing ENTER
      HighLow16 len = (ushort)(_lineData.Count + 1);

      // line number is big-endian
      yield return _lineNumber.High;
      yield return _lineNumber.Low;
      yield return len.Low;
      yield return len.High;
      foreach (var b in _lineData)
        yield return b;
      yield return (byte)13;
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
      return GetEnumerator();
    }

    #endregion

    #region Private methods

    /// <summary>
    /// Adds an efficient representation of an integer to the line.
    /// </summary>
    /// <param name='i'>
    /// The integer to add.
    /// </param>
    private void AddInteger(int i)
    {
      switch (i) {
      case 0:
        _lineData.Add((byte)Token.Sin);
        _lineData.Add((byte)Token.Pi);
        break;
      case 1:
        _lineData.Add((byte)Token.Sgn);
        _lineData.Add((byte)Token.Pi);
        break;
      case 16384:
        _lineData.Add((byte)Token.Val);
        AddString("2^14");
        break;
      case 32768:
        _lineData.Add((byte)Token.Val);
        AddString("2^15");
        break;
      default:
        // multiples of 1000 or 10000 can be represented as
        // powers of 10
        if ((i % 10000 == 0)) {
          _lineData.Add((byte)Token.Val);
          AddString((i / 10000).ToString() + "e4");
          return;
        }
        if ((i % 1000 == 0)) {
          _lineData.Add((byte)Token.Val);
          AddString((i / 1000).ToString() + "e3");
          return;
        }
        // VAL "i"
        _lineData.Add((byte)Token.Val);
        AddString(i.ToString());
        break;
      }
    }

    /// <summary>
    /// Adds an optionally delimited string to the line.
    /// </summary>
    /// <param name='s'>
    /// The string to add.
    /// </param>
    /// <param name='delimit'>
    /// Whether or not to delimit the string with quotation marks,
    /// defaults to true.
    /// </param>
    private void AddString(string s, bool delimit = true)
    {
      if (delimit)
        _lineData.Add((byte)'"');
      // use an 8-bit encoding rather than ASCII so we can
      // embed keywords in strings
      _lineData.AddRange(Encoding.GetEncoding(1252).GetBytes(s));
      if (delimit)
        _lineData.Add((byte)'"');
    }

    // adds strings, concatenating them with apostrophes

    /// <summary>
    /// Adds strings to the line, concatenating them with
    /// apostrophes.
    /// </summary>
    /// <param name='strings'>
    /// The strings to add.
    /// </param>
    private void AddStrings(IEnumerable<string> strings)
    {
      var s = string.Join("\"'\"", strings);
      AddString(s);
    }

    #endregion
  }
}

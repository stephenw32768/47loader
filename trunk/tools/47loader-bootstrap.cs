// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

// writes the BASIC for bootstrapping 47loader
public static class FortySevenLoaderBootstrap
{
  // BASIC tokens
  enum Token : byte {
    Border = 0xe7,
    Bright = 0xdc,
    Clear = 0xfd,
    Ink = 0xd9,
    Lprint = 0xe0,
    Paper = 0xda,
    Pause = 0xf2,
    Print = 0xf5,
    Pi = 0xa7,
    Randomize = 0xf9,
    Rem = 0xea,  
    Sgn = 0xbc,
    Sin = 0xb2,
    Usr = 0xc0,
    Val = 0xb0,
  }

  // a single BASIC line
  sealed class BasicLine : IEnumerable<byte>
  {
    static ushort _nextLineNumber = FirstLine;
    readonly HighLow16 _lineNumber;
    readonly List<byte> _lineData = new List<byte>();

    internal BasicLine()
    {
      _lineNumber = _nextLineNumber++;
    }

    internal void AddStatement(Token token, params object[] args)
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

    // adds an efficient representation of an integer to the line
    private void AddInteger(int i)
    {
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

      switch (i) {
      case 0:
        _lineData.Add((byte)Token.Sin);
        _lineData.Add((byte)Token.Pi);
        break;
      case 1:
        _lineData.Add((byte)Token.Sgn);
        _lineData.Add((byte)Token.Pi);
        break;
      default: // VAL "i"
        _lineData.Add((byte)Token.Val);
        AddString(i.ToString());
        break;
      }
    }

    // adds an optionally delimited string to the line
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
    private void AddStrings(IEnumerable<string> strings)
    {
      string s = string.Join("\"'\"", strings);
      AddString(s);
    }

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
  }

  const ushort FirstLine = 9047; // OVER NINE THOUSAND!

  static readonly List<byte> _data = new List<byte>();

  // options
  static string _progName = string.Empty;
  static int _border = -1, _paper = -1, _ink = -1, _bright = -1, _clear;
  static int _pause = -1;
  static List<string> _printTop = new List<string>();
  static List<string> _printBottom = new List<string>();
  static List<Tuple<ushort, ushort>> _usr = new List<Tuple<ushort, ushort>>();

  // parses string into integer
  static T ParseInteger<T>(string s)
  {
    try {
      T rv = (T)Convert.ChangeType(s, typeof(T));
      return rv;
    } catch {
      Console.Error.WriteLine("Bad integer: " + s);
      Die();
      return default(T);
    }
  }

  static void ParseArguments(string[] args) {
    for (int i = 0; i < args.Length; i++) {

      switch (args[i].TrimStart('-')) {
      case "border":
        _border = ParseInteger<int>(args[++i]);
        break;
      case "paper":
        _paper = ParseInteger<int>(args[++i]);
        break;
      case "ink":
        _ink = ParseInteger<int>(args[++i]);
        break;
      case "bright":
        _bright = ParseInteger<int>(args[++i]);
        break;
      case "clear":
        _clear = ParseInteger<int>(args[++i]);
        break;
      case "name":
        _progName = args[++i];
        if (_progName.Length > 10)
          _progName = _progName.Substring(0, 10);
        break;
      case "usr":
        var addresses = args[++i].Split(':');
        ushort clear = 0, usr = 0;
        switch (addresses.Length) {
        case 1:
          usr = ParseInteger<ushort>(addresses[0]);
          break;
        case 2:
          clear = ParseInteger<ushort>(addresses[0]);
          usr = ParseInteger<ushort>(addresses[1]);
          break;
        default:
          Die();
          break;
        }
        _usr.Add(Tuple.Create(clear, usr));
        break;
      case "pause":
        _pause = ParseInteger<int>(args[++i]);
        break;
      case "top":
        _printTop.Add(args[++i]);
        break;
      case "bottom":
        _printBottom.Add(args[++i]);
        break;
      default:
        // unknown option
        Console.Error.WriteLine("Unknown option \"{0}\"", args[i]);
        Die();
        break;
      }
    }
  }

  // prints usage and exists unsuccessfully
  static void Die()
  {
    Console.Error.WriteLine(@"Usage: 47loader-bootstrap [options]
Reads binary to embed from standard input
Writes tape files to standard output

Options:
-name s:   BASIC program name
-clear n:  CLEAR address
-border n: border colour
-paper n:  paper colour
-ink n:    ink colour
-bright n: bright attribute
-pause n:  PAUSE to perform after loading
-top s:    string to print at the top of the screen
-bottom s: string to print at the bottom of the screen
-usr [c:]n:address to jump to after loading, optionally CLEARing to
           address c first");
    Environment.Exit(1);
  }

  // writes the TZX file to standard output
  static void WriteTzx()
  {
    using (var output = Console.OpenStandardOutput()) {
      output.Write(Encoding.ASCII.GetBytes("ZXTape!\x1a\x01\x14"), 0, 10);
      output.WriteByte(0x10); // standard speed block
      output.WriteByte(0); // two-byte pause length, 0ms
      output.WriteByte(0);
      output.WriteByte(19); // two-byte length of following data
      output.WriteByte(0);

      // write program header
      var headerData = new byte[19];
      // space-padded ten-byte file name at offset 2
      Encoding.ASCII.GetBytes(_progName).CopyTo(headerData, 2);
      for (int i = 11; (i > 1) && (headerData[i] == 0); i--)
        headerData[i] = (byte)' ';
      // length of BASIC program + variables at offset 12
      HighLow16 basicLen = (ushort)_data.Count;
      headerData[12] = basicLen.Low;
      headerData[13] = basicLen.High;
      // autostart line at offsee 14
      var autostart = new HighLow16(FirstLine);
      headerData[14] = autostart.Low;
      headerData[15] = autostart.High;
      // length of BASIC program without variables at offset 16
      headerData[16] = basicLen.Low;
      headerData[17] = basicLen.High;
      // XOR checksum at offset 18
      headerData[18] = headerData.Aggregate((x, n) => (byte)(x ^ n));
      output.Write(headerData, 0, headerData.Length);

      // write data block
      output.WriteByte(0x10); // standard speed block
      output.WriteByte(250); // two-byte pause length, 250ms
      output.WriteByte(0);
      HighLow16 dataBlockLen = (ushort)(2 + _data.Count);
      output.WriteByte(dataBlockLen.Low);
      output.WriteByte(dataBlockLen.High);
      _data.Insert(0, 255); // flag byte
      output.Write(_data.ToArray(), 0, _data.Count);
      output.WriteByte(_data.Aggregate((x, n) => (byte)(x ^ n))); // checksum
    }
  }

  // constructs BASIC program based on supplied options
  static void BuildBasic()
  {
    var line = new BasicLine();

    // colours
    if (_border >= 0)
      line.AddStatement(Token.Border, _border);
    if (_paper >= 0)
      line.AddStatement(Token.Paper, _paper);
    if (_ink >= 0)
      line.AddStatement(Token.Ink, _ink);
    if (_bright >= 0)
      line.AddStatement(Token.Bright, _bright);

    // memory
    line.AddStatement(Token.Clear, _clear);

    // messages
    if (_printBottom.Count > 0)
      line.AddStatement(Token.Lprint, (byte)'#', 1, (byte)';', _printBottom);
    if (_printTop.Count > 0)
      line.AddStatement(Token.Print, _printTop);
    
    // jump address (start of BASIC)
    const string startOfBasic = "\x00be23635+256*\x00be23636";
    line.AddStatement(Token.Randomize, Token.Usr, Token.Val, startOfBasic);

    // optional pause
    if (_pause >= 0)
      line.AddStatement(Token.Pause, _pause);

    _data.AddRange(line);

    // if additional jump addresses specified, add them on their own
    // lines
    foreach (var tuple in _usr) {
      line = new BasicLine();
      if (tuple.Item1 > 0)
        line.AddStatement(Token.Clear, tuple.Item1);
      line.AddStatement(Token.Randomize, Token.Usr, tuple.Item2);
      _data.AddRange(line);
    }
  }

  public static int Main(string[] args)
  {
    try {
      ParseArguments(args);
      if (_clear < 1) {
        Console.Error.WriteLine("no CLEAR address specified");
        Die();
      }

      // read data to embed
      using (var input = Console.OpenStandardInput()) {
        int b;
        while ((b = input.ReadByte()) >= 0)
          _data.Add((byte)b);
      }

      // construct rest of program
      BuildBasic();
      
      WriteTzx();

      return 0;
    } catch (Exception e) {
      Console.Error.WriteLine
        ("{0}: {1}", e.GetType().FullName, e.Message);
      Console.Error.WriteLine(e.StackTrace);
      Console.Error.WriteLine();
      Die();
      return 1;
    }
  }
}
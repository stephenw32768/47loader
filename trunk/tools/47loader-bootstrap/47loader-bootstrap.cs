// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

using FortySevenLoader.Basic;

// writes the BASIC for bootstrapping 47loader
public static class FortySevenLoaderBootstrap
{
  static readonly List<byte> _data = new List<byte>();

  // options
  static string _progName = string.Empty;
  static bool _alkatraz;
  static int _border = -1, _paper = -1, _ink = -1, _bright = -1, _clear;
  static string _inputFileName, _outputFileName;
  static int _pause = -1;
  static List<string> _printTop = new List<string>();
  static List<string> _printBottom = new List<string>();
  static List<Tuple<ushort, ushort>> _usr = new List<Tuple<ushort, ushort>>();

  // opens the input file or stream
  static Stream OpenInput()
  {
    if (string.IsNullOrWhiteSpace(_inputFileName))
      return Console.OpenStandardInput();

    try
    {
      var str = File.Open(_inputFileName, FileMode.Open);
      return str;
    }
    catch (IOException e)
    {
      Console.Error.WriteLine(e.Message);
      Environment.Exit(1);
      return null;
    }
  }

  // opens the output file or stream
  static Stream OpenOutput()
  {
    if (string.IsNullOrWhiteSpace(_outputFileName))
      return Console.OpenStandardOutput();

    var str = File.Open(_outputFileName, FileMode.OpenOrCreate);
    str.Seek(0, SeekOrigin.End);
    return str;
  }

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

  static void ParseArguments(string[] args)
  {
    for (int i = 0; i < args.Length; i++)
    {
      if (args[i].FirstOrDefault() != '-')
      {
        // we've come to the end of the options
        if (i < (args.Length - 1))
        {
          // more than one remaining argument
          Die();
          return;
        }

        _inputFileName = args[i];
        return;
      }

      switch (args[i].TrimStart('-'))
      {
        case "output":
            // next arg is name of file to which to write
          _outputFileName = args[++i];
          break;
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
        case "alkatraz":
          _alkatraz = true;
          break;
        case "usr":
          var addresses = args[++i].Split(':');
          ushort clear = 0, usr = 0;
          switch (addresses.Length)
          {
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

      if (_alkatraz && _progName.Length > 6)
      {
        Console.Error.WriteLine
          ("alkatraz program names may be no longer than 6 characters");
        Die();
      }
    }
  }

  // prints usage and exists unsuccessfully
  static void Die()
  {
    Console.Error.WriteLine(@"Usage: 47loader-bootstrap [options] [binary]
Reads binary to embed from standard input if not specified

Options:
-alkatraz : format BASIC program name like the Alkatraz loader.  Program
            name must be no longer than 6 characters
-border n : border colour
-bottom s : string to print at the bottom of the screen
-bright n : bright attribute
-clear n  : CLEAR address
-ink n    : ink colour
-name s   : BASIC program name
-output   : name of file to write; if not specified, writes to standard
            output.  Appends to file if it already exists
-paper n  : paper colour
-pause n  : PAUSE to perform after loading
-top s    : string to print at the top of the screen
-usr [c:]n: address to jump to after loading, optionally CLEARing to
            address c first");
    Environment.Exit(1);
  }

  // writes the TZX file to standard output
  static void WriteTzx()
  {
    using (var output = OpenOutput()) {
      FortySevenLoader.Tzx.FileHeader.Standard.Write(output);
      output.WriteByte(0x10); // standard speed block
      output.WriteByte(0); // two-byte pause length, 0ms
      output.WriteByte(0);
      output.WriteByte(19); // two-byte length of following data
      output.WriteByte(0);

      // write program header
      var headerData = new byte[19];
      // space-padded ten-byte file name at offset 2
      var progName = _progName;
      if (_alkatraz)
        // AT 1,0;progName,
        // add a leading space if fewer than 6 chars
        progName = string.Format("{0}{1}{2}{3}{4}{5}",
                                 (char)0x16, // AT
                                 (char)1,
                                 (char)0,
                                 progName.Length < 6 ? " " : string.Empty,
                                 progName,
                                 (char)6); // COMMA
      Encoding.ASCII.GetBytes(progName).CopyTo(headerData, 2);
      for (int i = 11; (i > 1) && (headerData[i] == 0); i--)
        headerData[i] = (byte)' ';
      // length of BASIC program + variables at offset 12
      HighLow16 basicLen = (ushort)_data.Count;
      headerData[12] = basicLen.Low;
      headerData[13] = basicLen.High;
      // autostart line at offset 14
      var autostart = new HighLow16(BasicLine.FirstLine);
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
      line.AddStatement(Token.Lprint, (byte)'#', 0/*1*/,
                        (byte)';', _printBottom);
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
      using (var input = OpenInput()) {
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
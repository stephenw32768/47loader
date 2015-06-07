// 47loader (c) Stephen Williams 2013-2015
// See LICENSE for distribution terms
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using BlockHeader = FortySevenLoader.Tzx.TurboBlockHeader;

namespace FortySevenLoader
{
  /// <summary>
  /// Low-level "mastering" tool for 47loader.
  /// </summary>
  public static class FortySevenLoaderTzx
  {
    internal const int TStatesPerMillisecond = 3500;
    // pulse lengths, notionally constant
    internal static readonly HighLow16 ZeroPulse = Pulse.Zero();
    internal static readonly HighLow16 OnePulse = Pulse.One();
    internal static readonly HighLow16 PilotPulse = Pulse.Pilot;
    internal static readonly HighLow16 PilotPulseCount =
      (ushort)(1000 * TStatesPerMillisecond / PilotPulse);
    // this is used for embedding tiny pilots for instascreen and
    // progressive loading
    internal static readonly HighLow16 TinyPilotPulseCount = new HighLow16(2);
    // this is for audible pilots in progressive blocks
    internal static readonly HighLow16 BleepPilotPulseCount =
      new HighLow16(310);
    private static readonly List<byte> _data = new List<byte>();
    private static readonly BlockHeader _blockHeader = new BlockHeader
    {
      PilotClickPulse = Pulse.Rom.Pilot,
      PilotPulse = FortySevenLoaderTzx.PilotPulse,
      PilotPulseCount = FortySevenLoaderTzx.PilotPulseCount,
      SyncPulse0 = FortySevenLoaderTzx.ZeroPulse,
      SyncPulse1 = FortySevenLoaderTzx.OnePulse,
      ZeroPulse = FortySevenLoaderTzx.ZeroPulse,
      OnePulse = FortySevenLoaderTzx.OnePulse,
      Pause = new HighLow16(250)
    };
    // mutable bits
    private static Stream _tapefile;
    private static bool _reverse;
    private static bool _noHeader;
    private static string _outputFileName;
    private static ushort _progressive;
    private static byte? _countdownStart;
    private static bool _bleep;
    private static Action WriteData = WriteData_Simple;
    private static DynamicTable _dynamicTable;
    // parses string into integer
    static T ParseInteger<T>(string s)
    {
      try
      {
        T rv = (T)Convert.ChangeType(s, typeof(T));
        return rv;
      } catch
      {
        Console.Error.WriteLine("Bad integer: " + s);
        Die();
        return default(T);
      }
    }
    // parses options, returns array of file names
    static string[] ParseArguments(string[] args)
    {
      Action<sbyte> doExtraCycles = delegate(sbyte cycles)
      {
        HighLow16 new0 = Pulse.Zero(cycles);
        HighLow16 new1 = Pulse.One(cycles);
        _blockHeader.PilotPulse = Pulse.Pilot;
        _blockHeader.SyncPulse0 = _blockHeader.ZeroPulse = new0;
        _blockHeader.SyncPulse1 = _blockHeader.OnePulse = new1;
      };
      string pilot = null;
      bool noFixedLength = false;

      for (int i = 0; i < args.Length; i++)
      {
        if (args[i].FirstOrDefault() != '-')
        {
          // we've come to the end of the options, all the rest
          // are files

          if (noFixedLength && (_dynamicTable != null))
            _dynamicTable.DisableFixedLength();

          if (!string.IsNullOrWhiteSpace(pilot))
          {
            checked
            {
              HighLow16 pilotPulses, pilotClicks = 0;
              pilot = pilot.ToLower();
              switch (pilot)
              {
                case "resume":
                  pilotPulses = TinyPilotPulseCount;
                  break;
                case "short":
                  pilotPulses = 600;
                  break;
                case "standard":
                  pilot = "1000"; // one second
                  goto default; // fall through
                default:
                  if (pilot.StartsWith("click"))
                  {
                    if (_blockHeader.PilotPulse == Pulse.Rom.Pilot)
                    {
                      Console.Error.WriteLine
                        ("clicking pilots may not be used with ROM timings");
                      Die();
                    }

                    // see if a click count was appended, default to 8 if not
                    var clickStr = pilot.Substring(5).Trim();
                    if (clickStr.Length > 0)
                      pilotClicks = ParseInteger<ushort>(clickStr);
                    if (pilotClicks < 1)
                      pilotClicks = 8;
                    pilotPulses = 300;
                    break;
                  }

                  int ms = ParseInteger<int>(pilot);
                  int tstates = ms * TStatesPerMillisecond;
                  pilotPulses =
                    (ushort)(tstates / _blockHeader.PilotPulse);
                  if ((pilotPulses % 2) == 1)
                    pilotPulses += 1;
                  break;
              }
              _blockHeader.PilotPulseCount = pilotPulses;
              _blockHeader.PilotClickCount = pilotClicks;
            }
          }

          return args.Skip(i).ToArray();
        }

        switch (args[i].TrimStart('-'))
        {
          case "noheader":
            _noHeader = true;
            break;

          case "nofixedlength":
            noFixedLength = true;
            break;

          case "reverse":
            _reverse = true;
            break;

          case "pilot":
            // next arg is pilot length in milliseconds, or a string, or
            // click count
            pilot = args[++i];
            // defer calculation until end of option parsing in case
            // ROM timings are requested and we're going to change
            // the pilot pulse length
            break;

          case "pause":
            // next arg is pause length in milliseconds
            checked
            {
              HighLow16 ms = ParseInteger<ushort>(args[++i]);
              _blockHeader.Pause = ms;
            }
            break;

          case "extracycles":
            sbyte cycles = ParseInteger<sbyte>(args[++i]);
            doExtraCycles(cycles);
            break;

          case "instascreen":
            WriteData = WriteData_Instascreen;
            break;

          case "fancyscreen":
            // next arg is a fancy screen load type; one of the fields
            // in the FancyScreen class
            var loadTypeName = args[++i];
            _dynamicTable = (from field in typeof(FancyScreen).GetFields
                             (BindingFlags.Static | BindingFlags.NonPublic)
                             where field.FieldType == typeof(DynamicTable)
                             where field.Name.Equals(loadTypeName,
                                                     StringComparison.OrdinalIgnoreCase)
                             select (DynamicTable)field.GetValue(null))
              .FirstOrDefault();
            if (_dynamicTable == null)
            {
              Console.Error.WriteLine
                ("unknown fancy screen type \"{0}\"", loadTypeName);
              goto die;
            }
            WriteData = WriteData_FancyScreen;
            break;

          case "progressive":
            // next arg is number of progressive chunks
            checked
            {
              _progressive = ParseInteger<ushort>(args[++i]);
            }
            WriteData = WriteData_Progressive;
            break;

          case "countdown":
            // next arg is number of progressive chunks, optionally
            // followed by the number at which to start the countdown
            var split = args[++i].Split(':');
            if (split.Length < 1 || split.Length > 2)
              goto badCountdown;
            switch (split.Length)
            {
              case 1:
                // start countdown at the first specified block
                split = new[] { split[0], split[0] };
                break;
              case 2:
                break;
              default:
                goto badCountdown;
            }
            checked
            {
              int countdownBlocks = ParseInteger<int>(split[0]);
              int countdownStart = ParseInteger<int>(split[1]);

              if (countdownBlocks < 1 || countdownBlocks > 99)
                goto badCountdown;
              if (countdownStart < countdownBlocks || countdownStart > 99)
                goto badCountdown;
              _progressive = (byte)countdownBlocks;
              _countdownStart = (byte)countdownStart;
            }
            WriteData = WriteData_Progressive;
            break;
            badCountdown:
            Console.Error.WriteLine("bad countdown argument");
            goto die;

          case "bleep":
            _bleep = true;
            break;

          case "output":
            // next arg is name of file to which to write
            _outputFileName = args[++i];
            if (File.Exists(_outputFileName))
              _noHeader = true;
            break;

          case "speed":
            // next arg is a named timing
            var speedName = args[++i];
            Timing speed;
            if (!Enum.TryParse(speedName, true, out speed))
            {
              Console.Error.WriteLine("unknown speed \"{0}\"", speedName);
              goto die;
            }
            if (speed != Timing.Rom)
              doExtraCycles((sbyte)speed);
            else
            {
              // convert block to ROM timings
              _blockHeader.PilotPulse = Pulse.Rom.Pilot;
              _blockHeader.SyncPulse0 = Pulse.Rom.Sync0;
              _blockHeader.SyncPulse1 = Pulse.Rom.Sync1;
              _blockHeader.ZeroPulse = Pulse.Rom.Zero;
              _blockHeader.OnePulse = Pulse.Rom.One;
            }
            // recompute pilot pulse count
            if (pilot == null)
              pilot = "standard";
            break;

          default:
            // unknown option
            Console.Error.WriteLine("Unknown option \"{0}\"", args[i]);
            goto die;
        }
      }

      // still here?  Bad option or no files...
      die:
      Die();
      return null;
    }
    // prints usage and exists unsuccessfully
    static void Die()
    {
      Console.Error.WriteLine(@"Usage: 47loader-tzx [options] file [file ...]

Options:
-bleep          : join progressive/countdown blocks with audible pilots
-countdown n[:s]: create a progressively-loaded block with n chunks for use
                  with 47loader_countdown.  If s is specified, the countdown
                  begins at this number.  n and s must be 99 or smaller, and
                  s may not be larger than n
-fancyscreen s  : create a fancy screen load for use with 47loader_dynamic
                  See: https://code.google.com/p/47loader/wiki/FancyScreen
-extracycles n  : additional 34T cycles to add to timings.  May be negative
-instascreen    : create a screen block for use with 47loader_instascreen
-noheader       : omit the TZX file header (automatically selected if output
                  file already exists)
-output         : name of file to write; if not specified, writes to standard
                  output.  Appends to file if it already exists
-pause n        : pause n milliseconds after block
-pilot n        : length of pilot in milliseconds, or a string:
                  ""standard"", ""short"", ""resume"" or ""click""
-progressive n  : create a progressively-loaded block with n chunks for use
                  with 47loader_progressive_simple or
                  47loader_progressive_meter
-reverse        : reverse the block
-speed s        : desired speed, defaults to ""standard""

The -speed option is a friendlier way of altering the timings than
-extracycles.  The available speeds are:

speed        |  corresponds to | timings
-------------+-----------------+-----------
fast         | -extracycles -2 | 475T/950T
eager        | -extracycles -1 | 509T/1018T
standard     | -extracycles 0  | 543T/1086T
cautious     | -extracycles 2  | 611T/1222T
conservative | -extracycles 4  | 679T/1358T
speedlock7   | -extracycles 5  | 713T/1426T
rom          |                 | 855T/1710T
");
      Environment.Exit(1);
    }
    // opens the output file or stream
    private static Stream OpenOutput()
    {
      if (string.IsNullOrWhiteSpace(_outputFileName))
        return Console.OpenStandardOutput();

      var str = File.Open(_outputFileName, FileMode.OpenOrCreate);
      str.Seek(0, SeekOrigin.End);
      return str;
    }
    // normal implementation of WriteData for simple blocks
    private static void WriteData_Simple()
    {
      Block block = new Block(_blockHeader, _data);
      block.WriteBlock(_tapefile);
    }
    // WriteData implementation for progressive loads
    private static void WriteData_Progressive()
    {
      Block block;

      checked
      {
        // calculate lengths of chunks; should be as even as possible
        var lengths = (from i in Enumerable.Range(0, _progressive)
                       let l = (ushort)(_data.Count / _progressive)
                       select new HighLow16(l)).ToArray();
        int remainder = _data.Count % _progressive;
        for (int i = 0; i < remainder; i++)
          lengths[i] += 1;
        // each block apart from the last one contains the length of
        // the next at the end; these extra two bytes need including
        // in the lengths
        for (int i = 0; i < lengths.Length - 1; i++)
          lengths[i] += 2;

        // first "bootstrap" block is just the length of the first real
        // block.  If -countdown is in use, it is followed by the
        // countdown stop and start numbers, both in BCD format
        IEnumerable<byte> firstBlockData = lengths[0];
        if (_countdownStart != null)
        {
          var countdownStop = _countdownStart - _progressive;
          var countdownExtraBytes = new byte[]
          {
            ToBinaryCodedDecimal((byte)countdownStop),
            ToBinaryCodedDecimal((byte)_countdownStart)
          };
          firstBlockData = firstBlockData.Concat(countdownExtraBytes);
        }
        block = new Block(_blockHeader.DeepCopy(), firstBlockData);
        block.BlockHeader.Pause = HighLow16.Zero;
        block.WriteBlock(_tapefile);

        // each chunk includes the length of the next block at the end
        int bytesDone = 0, byteCount;
        for (int i = 0; i < (_progressive - 1); i++)
        {
          // the last two bytes in the block are the length of the
          // next, so we don't include them in the number of bytes
          // to take from _data
          byteCount = (ushort)lengths[i] - 2;
          block = new Block(_blockHeader.DeepCopy(),
                            _data.Skip(bytesDone).Take(byteCount)
                            .Concat(lengths[i + 1]));
          block.BlockHeader.PilotPulseCount = _bleep
            ? BleepPilotPulseCount
            : TinyPilotPulseCount;
          block.BlockHeader.Pause = HighLow16.Zero;
          block.WriteBlock(_tapefile);
          bytesDone += byteCount;
        }
        // except the very last chunk, of course; that's just data
        // on its own, and doesn't have its pause forced to zero
        byteCount = (ushort)lengths.Last();
        block = new Block(_blockHeader.DeepCopy(),
                          _data.Skip(bytesDone).Take(byteCount));
        block.BlockHeader.PilotPulseCount = _bleep
          ? BleepPilotPulseCount
          : TinyPilotPulseCount;
        block.WriteBlock(_tapefile);
      }
    }
    // WriteData implementation for instascreens
    private static void WriteData_Instascreen()
    {
      if (_data.Count != 6912)
      {
        Console.Error.WriteLine("not a 6912 byte screen");
        Environment.Exit(1);
      }

      // one block for the pixmap with no pause
      var block = new Block(_blockHeader.DeepCopy(), _data.Take(6144));
      block.BlockHeader.Pause = 0;
      block.WriteBlock(_tapefile);
      // one block for the attrs with short pilot
      block = new Block(_blockHeader.DeepCopy(), _data.Skip(6144));
      block.BlockHeader.PilotPulseCount = TinyPilotPulseCount;
      block.BlockHeader.Pause = 0;
      block.WriteBlock(_tapefile);
      // pulses for the loader to read through while it blits
      // the attrs
      const int shortPulseCount = 17;
      const ushort shortPulseLength = 1280;
      const int pilotPulseCount = 12;
      //*
      var pulses = (from i in Enumerable.Range(0, shortPulseCount)
                    select new HighLow16(shortPulseLength))
        .Concat(from i in Enumerable.Range(0, pilotPulseCount)
                select _blockHeader.PilotPulse).ToArray();
      var count = (byte)pulses.Length;
      var bytes = new[]
      { (byte)0x13, // TZX block ID for pulse sequence
        count
      }.Concat(from pulse in pulses
                     from b in pulse
                     select b).ToArray();
      _tapefile.Write(bytes, 0, bytes.Length);
      //*/
      // one pulse per block, for test/debug:
      /*
    foreach (var pulse in (from i in Enumerable.Range(0, shortPulseCount)
                           select new HighLow16(shortPulseLength))
             .Concat(from i in Enumerable.Range(0, pilotPulseCount)
                     select _blockHeader.PilotPulse)) {
      var bytes = new byte[] { 0x13, 1, pulse.Low, pulse.High };
      _tapefile.Write(bytes, 0, bytes.Length);
    }
    //*/
    }
    // WriteData implementation for fancy screens
    private static void WriteData_FancyScreen()
    {
      FancyScreen.WriteData(_tapefile, _dynamicTable, _data, _blockHeader);
    }

    // converts a byte to BCD
    private static byte ToBinaryCodedDecimal(byte input)
    {
      int tens = input / 10;
      int units = input % 10;
      int bcd = (tens * 16) + units;
      return checked((byte)bcd);
    }

    public static int Main(string[] args)
    {
      if (args.Length < 1)
      {
        Die();
        return 1;
      }

      try
      {
        var files = ParseArguments(args);

        using (var data = new MemoryStream())
        using (_tapefile = OpenOutput())
        {
          for (int i = 0; i < files.Length; i++)
          {
            if (!File.Exists(files[i]))
            {
              Console.Error.WriteLine("File not found: " + files[i]);
              Die();
            }
            using (var file = File.OpenRead(files[i]))
            {
              file.CopyTo(data);
            }
          }

          if (!_noHeader)
            Tzx.FileHeader.Standard.Write(_tapefile);
          _data.AddRange(data.ToArray());
          if (_reverse)
            _data.Reverse();
          WriteData();
        }
      }
      catch (Exception e)
      {
        Console.Error.WriteLine
          ("{0}: {1}", e.GetType().FullName, e.Message);
        Console.Error.WriteLine(e.StackTrace);
        Console.Error.WriteLine();
        Die();
        return 1;
      }

      return 0;
    }
  }
}

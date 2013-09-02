// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;

// simple run-length encoder
class RunLengthEncode
{
  static int Main(string[] args)
  {
    const int maxRun = 257;
    int run = -1, prev = -1;
    byte sentinel;

    if ((args.Length != 1) || !byte.TryParse(args[0], out sentinel)) {
      Console.Error.WriteLine("Usage: rle.exe sentinel");
      Console.Error.WriteLine("Sentinel must be between 0 and 255");
      Console.Error.WriteLine("Encodes from stdin to stdout");
      return 1;
    }

    using (var input = Console.OpenStandardInput())
    using (var output = Console.OpenStandardOutput())
    {
      int thisByte;
      Action flushRun = delegate {
        // runs of up to two bytes are represented literally
        // runs of between 3 and 257 bytes are represented
        // with the sentinel byte followed by the run length
        // minus one, mod 256
        while (run > 0) {
          int thisRun = Math.Min(run, maxRun);
          switch (thisRun) {
          case 2:
            output.WriteByte((byte)prev);
            goto case 1; // fall through
          case 1:
            output.WriteByte((byte)prev);
            break;
          default:
            output.WriteByte(sentinel);
            output.WriteByte((byte)prev);
            output.WriteByte((byte)((thisRun - 1) % 256));
            break;
          }
          run -= thisRun;
        }
        run = -1;
      };

      while ((thisByte = input.ReadByte()) >= 0) {
        if (thisByte == sentinel) {
          Console.Error.WriteLine("Sentinel {0} encountered in input",
                                  sentinel);
          return 1;
        }
        if (thisByte == prev) {
          // same as previous byte, so part of the current run
          run++;
        } else {
          // different to previous byte, so starting a new run
          // flush any existing run
          flushRun();
          // start a new run
          prev = thisByte;
          run = 1;
        }
      }

      // flush any trailing run
      flushRun();

      return 0;
    }
  }
}
// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;

// simple run-length encoder
class RunLengthEncode
{
  static int Main()
  {
    int run = -1, prev = -1;

    using (var input = Console.OpenStandardInput())
    using (var output = Console.OpenStandardOutput())
    {
      int thisByte;

      while ((thisByte = input.ReadByte()) >= 0) {
        if (thisByte == prev) {
          // same as previous byte, so part of a run
          run++;
          if (run == 255) {
            // maximum length for a run
            output.WriteByte((byte)prev);
            output.WriteByte(255);
            run = -1;
            prev = thisByte;
          }
        } else {
          // different to previous byte, so not part of a run
          // flush any existing run
          if (run >= 0) {
            output.WriteByte((byte)prev);
            output.WriteByte((byte)run);
            run = -1;
          }
          output.WriteByte((byte)thisByte);
          prev = thisByte;
        }
      }

      // flush any trailing run
      if (run >= 0) {
        output.WriteByte((byte)prev);
        output.WriteByte((byte)run);
      }
      return 0;
    }
  }
}
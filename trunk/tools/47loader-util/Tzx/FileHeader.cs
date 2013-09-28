// 47loader (c) Stephen Williams 2013
// See LICENSE for distribution terms

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace FortySevenLoader.Tzx
{
  /// <summary>
  /// Representation of a TZX file header as per
  /// http://www.worldofspectrum.org/TZXformat.html#TZXFORMAT
  /// </summary>
  public struct FileHeader : IEnumerable<byte>
  {
    #region Private fields

    private static readonly byte[] _headerPrefix =
    Encoding.ASCII.GetBytes("ZXTape!\x1a");

    private readonly byte _major, _minor;

    #endregion

    #region Constructor

    /// <summary>
    /// Initializes a new instance of the
    /// <see cref="FortySevenLoader.FileHeader"/> class.
    /// </summary>
    /// <param name='major'>
    /// The major version number, defaults to 1.
    /// </param>
    /// <param name='minor'>
    /// The minor version number, defaults to 20.
    /// </param>
    public FileHeader(byte major = 1, byte minor = 20)
    {
      _major = major;
      _minor = minor;
    }

    #endregion

    #region Public methods

    /// <summary>
    /// Writes the header to a stream.
    /// </summary>
    /// <param name='stream'>
    /// The stream to which to write the header.
    /// </param>
    public void Write(Stream stream)
    {
      if (stream == null)
        throw new ArgumentNullException("stream");

      var bytes = this.ToArray();
      stream.Write(bytes, 0, bytes.Length);
    }

    #endregion

    #region IEnumerable<byte> implementation

    /// <summary>
    /// Converts the tape header into a sequence of bytes for writing
    /// to a stream.  The bytes follow the specification at
    /// http://www.worldofspectrum.org/TZXformat.html#TZXFORMAT
    /// </summary>
    /// <returns>
    /// An enumerator over the byte sequence.
    /// The enumerator.
    /// </returns>
    public IEnumerator<byte> GetEnumerator()
    {
      var bytes = _headerPrefix.Concat(new[] { _major, _minor });
      return bytes.GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
      return GetEnumerator();
    }

    #endregion
  }
}

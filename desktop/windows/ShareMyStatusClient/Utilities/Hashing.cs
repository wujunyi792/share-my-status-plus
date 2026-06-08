using System.Security.Cryptography;

namespace ShareMyStatusClient.Utilities;

public static class Hashing
{
    /// <summary>Lower-case hex MD5 of the given bytes (matches the macOS cover hash).</summary>
    public static string Md5Hex(byte[] data)
    {
        var hash = MD5.HashData(data);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}

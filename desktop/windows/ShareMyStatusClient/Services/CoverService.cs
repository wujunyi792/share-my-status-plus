using System.Net.Http;
using System.Text;
using System.Text.Json;
using ShareMyStatusClient.Models.Api;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Deduplicates and uploads album artwork (cover_service). Hash is the lower-case
/// MD5 hex of the raw image bytes — identical to the macOS client and the backend.
/// </summary>
public sealed class CoverService
{
    private readonly AppLogger _logger = AppLogger.Cover;
    private readonly HttpClient _http;
    private readonly object _gate = new();

    // MD5 -> coverHash, bounded to avoid unbounded growth (matches macOS cap of 100).
    private readonly Dictionary<string, string> _uploaded = new();
    private const int MaxCacheEntries = 100;

    private string _baseUrl = string.Empty;
    private string _secretKey = string.Empty;

    public CoverService()
    {
        _http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    }

    /// <summary>Derives the API base URL from the full report endpoint by stripping its path.</summary>
    public void UpdateConfiguration(string endpointUrl, string secretKey)
    {
        lock (_gate)
        {
            if (Uri.TryCreate(endpointUrl, UriKind.Absolute, out var uri))
                _baseUrl = $"{uri.Scheme}://{uri.Authority}";
            else
                _baseUrl = endpointUrl;
            _secretKey = secretKey;
        }
        _logger.Info("Cover service configuration updated");
    }

    public async Task<string?> CheckAndUploadCoverAsync(byte[] artworkData, CancellationToken ct)
    {
        var md5 = Hashing.Md5Hex(artworkData);

        lock (_gate)
        {
            if (_uploaded.TryGetValue(md5, out var cached))
                return cached;
        }

        if (await CheckCoverExistsAsync(md5, ct).ConfigureAwait(false))
        {
            CacheInsert(md5, md5);
            return md5;
        }

        _logger.Info($"Uploading new cover: {md5}");
        var coverHash = await UploadCoverAsync(artworkData, ct).ConfigureAwait(false);
        CacheInsert(md5, coverHash);
        return coverHash;
    }

    private void CacheInsert(string md5, string hash)
    {
        lock (_gate)
        {
            if (_uploaded.Count >= MaxCacheEntries)
                _uploaded.Clear();
            _uploaded[md5] = hash;
        }
    }

    private async Task<bool> CheckCoverExistsAsync(string md5, CancellationToken ct)
    {
        string baseUrl, secret;
        lock (_gate) { baseUrl = _baseUrl; secret = _secretKey; }

        var url = $"{baseUrl}/api/v1/cover/exists?md5={Uri.EscapeDataString(md5)}";
        using var message = new HttpRequestMessage(HttpMethod.Get, url);
        message.Headers.TryAddWithoutValidation("Accept", "application/json");
        message.Headers.TryAddWithoutValidation("X-Secret-Key", secret);

        using var response = await _http.SendAsync(message, ct).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
            throw new CoverException($"HTTP错误: {(int)response.StatusCode}");

        var body = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        var parsed = JsonSerializer.Deserialize<CoverExistsResponse>(body, ApiJson.Options);
        return parsed?.Exists ?? false;
    }

    private async Task<string> UploadCoverAsync(byte[] artworkData, CancellationToken ct)
    {
        string baseUrl, secret;
        lock (_gate) { baseUrl = _baseUrl; secret = _secretKey; }

        var url = $"{baseUrl}/api/v1/cover/upload";
        var payload = new CoverUploadRequest { B64 = Convert.ToBase64String(artworkData) };
        var json = JsonSerializer.Serialize(payload, ApiJson.Options);

        using var content = new StringContent(json, Encoding.UTF8, "application/json");
        using var message = new HttpRequestMessage(HttpMethod.Post, url) { Content = content };
        message.Headers.TryAddWithoutValidation("X-Secret-Key", secret);

        using var response = await _http.SendAsync(message, ct).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
            throw new CoverException($"HTTP错误: {(int)response.StatusCode}");

        var body = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        var parsed = JsonSerializer.Deserialize<CoverUploadResponse>(body, ApiJson.Options);
        if (parsed?.CoverHash is not { Length: > 0 } hash)
            throw new CoverException("封面上传失败");

        _logger.Info($"Cover uploaded successfully: {hash}");
        return hash;
    }
}

public sealed class CoverException : Exception
{
    public CoverException(string message) : base(message) { }
}

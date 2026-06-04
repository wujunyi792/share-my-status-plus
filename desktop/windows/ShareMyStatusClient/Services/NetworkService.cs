using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Text;
using System.Text.Json;
using ShareMyStatusClient.Models.Api;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

public sealed class NetworkException : Exception
{
    public NetworkException(string message) : base(message) { }
}

/// <summary>HTTP client for reporting status to the backend (state_service BatchReport).</summary>
public sealed class NetworkService : IDisposable
{
    private readonly AppLogger _logger = AppLogger.Network;
    private readonly HttpClient _http;
    private readonly object _gate = new();

    private string _endpointUrl = string.Empty;
    private string _secretKey = string.Empty;

    public DateTimeOffset? LastReportTime { get; private set; }
    public int ReportCount { get; private set; }

    public NetworkService()
    {
        _http = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(30),
        };
        var ua = $"ShareMyStatus-Windows/1.0 (Windows {Environment.OSVersion.Version})";
        _http.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", ua);
    }

    public void UpdateConfiguration(string endpointUrl, string secretKey)
    {
        lock (_gate)
        {
            _endpointUrl = endpointUrl;
            _secretKey = secretKey;
        }
        _logger.Info("Network configuration updated");
    }

    /// <summary>A best-effort "is the machine online" check (matches macOS NWPathMonitor intent).</summary>
    public static bool IsConnected => NetworkInterface.GetIsNetworkAvailable();

    private static string? BaseUrlOf(string endpointUrl) =>
        Uri.TryCreate(endpointUrl, UriKind.Absolute, out var uri) ? $"{uri.Scheme}://{uri.Authority}" : null;

    /// <summary>Validates an endpoint + secret by hitting the authenticated client/resources route.</summary>
    public async Task<(bool Ok, string Message)> TestConnectionAsync(string endpointUrl, string secretKey, CancellationToken ct)
    {
        if (!IsConnected)
            return (false, "网络未连接");
        if (string.IsNullOrWhiteSpace(endpointUrl) || BaseUrlOf(endpointUrl) is not { } baseUrl)
            return (false, "服务器地址无效");
        if (string.IsNullOrWhiteSpace(secretKey))
            return (false, "Secret Key 为空");

        using var message = new HttpRequestMessage(HttpMethod.Get, $"{baseUrl}/api/v1/client/resources");
        message.Headers.TryAddWithoutValidation("X-Secret-Key", secretKey);
        message.Headers.TryAddWithoutValidation("Accept", "application/json");

        try
        {
            using var response = await _http.SendAsync(message, ct).ConfigureAwait(false);
            if (response.StatusCode == HttpStatusCode.Unauthorized)
                return (false, "认证失败：Secret Key 不正确");
            if (!response.IsSuccessStatusCode)
                return (false, $"服务器返回 HTTP {(int)response.StatusCode}");
            return (true, "连接成功，配置有效");
        }
        catch (OperationCanceledException)
        {
            return (false, "连接超时");
        }
        catch (Exception ex)
        {
            return (false, $"连接失败：{ex.Message}");
        }
    }

    /// <summary>Fetches server-provided client resource links (user doc / signature DIY URL).</summary>
    public async Task<ClientResources?> FetchClientResourcesAsync(CancellationToken ct)
    {
        string endpoint, secret;
        lock (_gate) { endpoint = _endpointUrl; secret = _secretKey; }

        if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(secret) || BaseUrlOf(endpoint) is not { } baseUrl)
            return null;

        using var message = new HttpRequestMessage(HttpMethod.Get, $"{baseUrl}/api/v1/client/resources");
        message.Headers.TryAddWithoutValidation("X-Secret-Key", secret);
        message.Headers.TryAddWithoutValidation("Accept", "application/json");

        try
        {
            using var response = await _http.SendAsync(message, ct).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
                return null;
            var body = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            return JsonSerializer.Deserialize<ClientResources>(body, ApiJson.Options);
        }
        catch
        {
            return null;
        }
    }

    public async Task<BatchReportResponse> ReportStatusAsync(BatchReportRequest request, CancellationToken ct)
    {
        string endpoint, secret;
        lock (_gate)
        {
            endpoint = _endpointUrl;
            secret = _secretKey;
        }

        if (!IsConnected)
            throw new NetworkException("网络未连接");
        if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(secret))
            throw new NetworkException("配置无效");
        if (!Uri.TryCreate(endpoint, UriKind.Absolute, out _))
            throw new NetworkException("无效的URL");

        var json = JsonSerializer.Serialize(request, ApiJson.Options);
        using var content = new StringContent(json, Encoding.UTF8, "application/json");
        using var message = new HttpRequestMessage(HttpMethod.Post, endpoint) { Content = content };
        message.Headers.TryAddWithoutValidation("X-Secret-Key", secret);

        using var response = await _http.SendAsync(message, ct).ConfigureAwait(false);

        switch ((int)response.StatusCode)
        {
            case >= 200 and <= 299:
            {
                var body = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                var parsed = JsonSerializer.Deserialize<BatchReportResponse>(body, ApiJson.Options)
                             ?? new BatchReportResponse();
                lock (_gate)
                {
                    LastReportTime = DateTimeOffset.Now;
                    ReportCount += request.Events.Count;
                }
                _logger.Debug($"Report ok: accepted={parsed.Accepted ?? 0}, deduped={parsed.Deduped ?? 0}");
                return parsed;
            }
            case 401:
                throw new NetworkException("认证失败");
            case 429:
                throw new NetworkException("请求过于频繁");
            default:
                throw new NetworkException($"HTTP错误: {(int)response.StatusCode}");
        }
    }

    public void Dispose() => _http.Dispose();
}

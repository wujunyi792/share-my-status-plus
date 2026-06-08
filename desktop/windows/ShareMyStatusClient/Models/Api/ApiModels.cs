using System.Text.Json;
using System.Text.Json.Serialization;

namespace ShareMyStatusClient.Models.Api;

// API models mirror idl/common.thrift and the service IDLs.
// Wire format is camelCase JSON; null optionals are omitted to match the
// macOS client's Swift Codable behaviour (encodeIfPresent).

/// <summary>Shared JSON options for all API request/response (de)serialization.</summary>
public static class ApiJson
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };
}

/// <summary>Base response wrapper (common.thrift BaseResponse).</summary>
public sealed class BaseResponse
{
    public int Code { get; set; }
    public string? Message { get; set; }
    public List<string>? Warnings { get; set; }
}

/// <summary>System metrics. Percentages are 0..1. <c>ts</c> is epoch milliseconds.</summary>
public sealed class SystemInfo
{
    public double? BatteryPct { get; set; }
    public bool? Charging { get; set; }
    public double? CpuPct { get; set; }
    public double? MemoryPct { get; set; }
    public long Ts { get; set; }
}

/// <summary>Now-playing music info. <c>ts</c> is epoch milliseconds.</summary>
public sealed class MusicInfo
{
    public string? Title { get; set; }
    public string? Artist { get; set; }
    public string? Album { get; set; }
    public string? CoverHash { get; set; }
    public long Ts { get; set; }
}

/// <summary>Mapped activity label, e.g. "在工作". <c>ts</c> is epoch milliseconds.</summary>
public sealed class ActivityInfo
{
    public string Label { get; set; } = string.Empty;
    public long Ts { get; set; }
}

/// <summary>A single report event. Exactly one of system/music/activity is set per event.</summary>
public sealed class ReportEvent
{
    public string Version { get; set; } = "1";
    public SystemInfo? System { get; set; }
    public MusicInfo? Music { get; set; }
    public ActivityInfo? Activity { get; set; }
    public string? IdempotencyKey { get; set; }

    public ReportEvent()
    {
    }

    public static ReportEvent ForSystem(SystemInfo system) => new()
    {
        System = system,
        IdempotencyKey = Guid.NewGuid().ToString(),
    };

    public static ReportEvent ForMusic(MusicInfo? music) => new()
    {
        Music = music,
        IdempotencyKey = Guid.NewGuid().ToString(),
    };

    public static ReportEvent ForActivity(ActivityInfo activity) => new()
    {
        Activity = activity,
        IdempotencyKey = Guid.NewGuid().ToString(),
    };
}

// ---- state_service.thrift ----

public sealed class BatchReportRequest
{
    public List<ReportEvent> Events { get; set; } = new();
}

public sealed class BatchReportResponse
{
    public BaseResponse? Base { get; set; }
    public int? Accepted { get; set; }
    public int? Deduped { get; set; }
}

// ---- cover_service.thrift ----

public sealed class CoverExistsResponse
{
    public BaseResponse? Base { get; set; }
    public bool? Exists { get; set; }
    public string? CoverHash { get; set; }
}

public sealed class CoverUploadRequest
{
    public string B64 { get; set; } = string.Empty;
}

public sealed class CoverUploadResponse
{
    public BaseResponse? Base { get; set; }
    public string? CoverHash { get; set; }
}

/// <summary>Server-provided client resource links (mirrors macOS ClientResources).</summary>
public sealed class ClientResources
{
    public string? UserDocUrl { get; set; }
    public string? FeishuSignatureDiyUrl { get; set; }
}

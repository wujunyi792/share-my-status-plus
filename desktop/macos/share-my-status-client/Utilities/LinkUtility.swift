//
//  LinkUtility.swift
//  share-my-status-client
//
//  Link customization utility for Feishu signature links
//

import Foundation

/// Utility class for link customization and template rendering
class LinkUtility {
    
    // URL Validation
    
    /// Validates if a string is a valid base URL (must start with http:// or https://)
    static func isValidBaseUrl(_ url: String) -> Bool {
        guard !url.isEmpty else { return false }
        return url.hasPrefix("http://") || url.hasPrefix("https://")
    }
    
    /// Validates if a string is a valid redirect URL (must start with http:// or https://)
    static func isValidRedirectUrl(_ url: String) -> Bool {
        return url.isEmpty || url.hasPrefix("http://") || url.hasPrefix("https://")
    }
    
    // URL Creation
    
    /// Creates a customized share URL with the given parameters
    /// - Parameters:
    ///   - baseUrl: The base URL string (must start with http:// or https://)
    ///   - redirectUrl: Optional redirect URL (r parameter)
    ///   - displayFormat: Optional display format string with placeholders (m parameter)
    /// - Returns: The customized URL string, or nil if the base URL is invalid
    static func createCustomizedUrl(
        baseUrl: String,
        redirectUrl: String?,
        displayFormat: String?
    ) -> String? {
        guard isValidBaseUrl(baseUrl) else {
            return nil
        }
        
        var components = baseUrl
        
        // Add redirect URL if provided
        if let redirectUrl = redirectUrl, !redirectUrl.isEmpty, isValidRedirectUrl(redirectUrl) {
            if let encoded = redirectUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let separator = components.contains("?") ? "&" : "?"
                components += separator + "r=" + encoded
            }
        }
        
        // Add display format if provided
        if let displayFormat = displayFormat, !displayFormat.isEmpty {
            if let encoded = displayFormat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let separator = components.contains("?") ? "&" : "?"
                components += separator + "m=" + encoded
            }
        }
        
        return components
    }
    
    // Template Formatting
    
    /// Template variables container
    struct TemplateVariables {
        // Music variables
        var artist: String = ""
        var title: String = ""
        var album: String = ""
        
        // System variables
        var batteryPct: Double?
        var charging: Bool = false
        var cpuPct: Double?
        var memoryPct: Double?
        
        // Activity variables
        var activityLabel: String = ""
        
        // Time variables
        var now: Date = Date()
        var timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        
        // Stats variables (require authorization)
        var topArtist: String?
        var topTitle: String?
        var uniqueTracks: Int?
        var playCountWindow: String?
        
        // Derived display values
        var batteryPctRounded: Int? {
            guard let pct = batteryPct else { return nil }
            return Int((pct * 100).rounded())
        }
        
        var cpuPctRounded: Int? {
            guard let pct = cpuPct else { return nil }
            return Int((pct * 100).rounded())
        }
        
        var memoryPctRounded: Int? {
            guard let pct = memoryPct else { return nil }
            return Int((pct * 100).rounded())
        }
        
        var nowISO: String {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timeZone
            return formatter.string(from: now)
        }
        
        var nowLocal: String {
            let formatter = DateFormatter()
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: now)
        }
        
        var dateYMD: String {
            let formatter = DateFormatter()
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: now)
        }
    }
    
    /// Formats the display text by replacing placeholders with actual data
    /// - Parameters:
    ///   - format: The format string with placeholders and optional ternary expressions
    ///   - variables: The template variables to use for replacement
    /// - Returns: The formatted display text
    static func formatDisplayText(format: String, variables: TemplateVariables) -> String {
        var result = format
        
        // Replace music variables
        result = result.replacingOccurrences(of: "{artist}", with: variables.artist)
        result = result.replacingOccurrences(of: "{title}", with: variables.title)
        result = result.replacingOccurrences(of: "{album}", with: variables.album)
        
        // Replace system variables
        if let batteryPct = variables.batteryPct {
            result = result.replacingOccurrences(of: "{batteryPct}", with: String(format: "%.2f", batteryPct))
        } else {
            result = result.replacingOccurrences(of: "{batteryPct}", with: "N/A")
        }
        
        if let cpuPct = variables.cpuPct {
            result = result.replacingOccurrences(of: "{cpuPct}", with: String(format: "%.2f", cpuPct))
        } else {
            result = result.replacingOccurrences(of: "{cpuPct}", with: "N/A")
        }
        
        if let memoryPct = variables.memoryPct {
            result = result.replacingOccurrences(of: "{memoryPct}", with: String(format: "%.2f", memoryPct))
        } else {
            result = result.replacingOccurrences(of: "{memoryPct}", with: "N/A")
        }
        
        // Replace activity variables
        result = result.replacingOccurrences(of: "{activityLabel}", with: variables.activityLabel)
        
        // Replace derived display variables
        if let batteryPctRounded = variables.batteryPctRounded {
            result = result.replacingOccurrences(of: "{batteryPctRounded}", with: "\(batteryPctRounded)")
        } else {
            result = result.replacingOccurrences(of: "{batteryPctRounded}", with: "N/A")
        }
        
        if let cpuPctRounded = variables.cpuPctRounded {
            result = result.replacingOccurrences(of: "{cpuPctRounded}", with: "\(cpuPctRounded)")
        } else {
            result = result.replacingOccurrences(of: "{cpuPctRounded}", with: "N/A")
        }
        
        if let memoryPctRounded = variables.memoryPctRounded {
            result = result.replacingOccurrences(of: "{memoryPctRounded}", with: "\(memoryPctRounded)")
        } else {
            result = result.replacingOccurrences(of: "{memoryPctRounded}", with: "N/A")
        }
        
        // Replace time variables
        result = result.replacingOccurrences(of: "{nowISO}", with: variables.nowISO)
        result = result.replacingOccurrences(of: "{nowLocal}", with: variables.nowLocal)
        result = result.replacingOccurrences(of: "{dateYMD}", with: variables.dateYMD)
        
        // Replace stats variables
        result = result.replacingOccurrences(of: "{topArtist}", with: variables.topArtist ?? "未知")
        result = result.replacingOccurrences(of: "{topTitle}", with: variables.topTitle ?? "未知")
        
        if let uniqueTracks = variables.uniqueTracks {
            result = result.replacingOccurrences(of: "{uniqueTracks}", with: "\(uniqueTracks)")
        } else {
            result = result.replacingOccurrences(of: "{uniqueTracks}", with: "0")
        }
        
        result = result.replacingOccurrences(of: "{playCountWindow}", with: variables.playCountWindow ?? "")
        
        // Process ternary expressions (e.g., {charging?'充电中':'未在充电'})
        result = processTernaryExpressions(result, variables: variables)
        
        return result
    }
    
    /// Process ternary expressions in the format {variable?'true_value':'false_value'}
    private static func processTernaryExpressions(_ text: String, variables: TemplateVariables) -> String {
        var result = text
        
        // Regex pattern to match ternary expressions
        // Pattern: {variable?'true_value':'false_value'}
        let pattern = #"\{(\w+)\?'([^']*)':'([^']*)'\}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        
        // Process matches in reverse order to avoid index issues
        for match in matches.reversed() {
            guard match.numberOfRanges == 4,
                  let variableRange = Range(match.range(at: 1), in: result),
                  let trueValueRange = Range(match.range(at: 2), in: result),
                  let falseValueRange = Range(match.range(at: 3), in: result),
                  let fullRange = Range(match.range(at: 0), in: result) else {
                continue
            }
            
            let variable = String(result[variableRange])
            let trueValue = String(result[trueValueRange])
            let falseValue = String(result[falseValueRange])
            
            // Evaluate the condition based on variable name
            let replacement: String
            switch variable {
            case "charging":
                replacement = variables.charging ? trueValue : falseValue
            default:
                // Unknown variable, keep original
                continue
            }
            
            result.replaceSubrange(fullRange, with: replacement)
        }
        
        return result
    }
    
    // URL Parsing
    
    /// Parse result from a customized URL
    struct ParsedUrl {
        let baseUrl: String
        let redirectUrl: String?
        let displayFormat: String?
    }
    
    /// Extract sharing key from URLComponents supporting /status/{key} or /s/{key}
    private static func extractSharingKey(from components: URLComponents) -> String? {
        let segments = components.path.split(separator: "/").map(String.init)
        if let statusIdx = segments.firstIndex(of: "status"), statusIdx + 1 < segments.count {
            return segments[statusIdx + 1]
        }
        if let sIdx = segments.firstIndex(of: "s"), sIdx + 1 < segments.count {
            return segments[sIdx + 1]
        }
        return nil
    }
    
    /// Attempts to parse a customized URL and extract its components
    /// - Parameter url: The customized URL to parse
    /// - Returns: A ParsedUrl struct containing the base URL, redirect URL, and display format
    static func parseCustomizedUrl(_ url: String) -> ParsedUrl? {
        guard let urlComponents = URLComponents(string: url) else {
            return nil
        }
        
        // Extract the query parameters
        let queryItems = urlComponents.queryItems ?? []
        
        // Find the redirect URL (r parameter)
        let rValue = queryItems.first(where: { $0.name == "r" })?.value?.removingPercentEncoding
        
        // Find the display format (m parameter)
        let mValue = queryItems.first(where: { $0.name == "m" })?.value?.removingPercentEncoding
        
        // Remove r and m parameters to get the base URL
        var baseUrlComponents = urlComponents
        baseUrlComponents.queryItems = queryItems.filter { $0.name != "r" && $0.name != "m" }
        
        // Normalize path to /s/{sharingKey} if base path contains /status/{sharingKey} or /s/{sharingKey}
        if let sharingKey = extractSharingKey(from: baseUrlComponents) {
            baseUrlComponents.path = "/s/\(sharingKey)"
        }
        
        guard let baseUrl = baseUrlComponents.url?.absoluteString else {
            return nil
        }
        
        return ParsedUrl(baseUrl: baseUrl, redirectUrl: rValue, displayFormat: mValue)
    }
    
    // Security & Validation
    
    /// Sanitize user input to prevent XSS attacks
    static func sanitizeText(_ text: String, maxLength: Int = 256) -> String {
        var sanitized = text
        
        // Limit length
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }
        
        // Basic HTML/XSS escaping
        let escapeMap: [Character: String] = [
            "<": "&lt;",
            ">": "&gt;",
            "&": "&amp;",
            "\"": "&quot;",
            "'": "&#39;"
        ]
        
        var result = ""
        for char in sanitized {
            if let escaped = escapeMap[char] {
                result.append(escaped)
            } else {
                result.append(char)
            }
        }
        
        return result
    }
}


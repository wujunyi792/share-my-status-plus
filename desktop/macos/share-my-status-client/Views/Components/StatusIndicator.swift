//
//  StatusIndicator.swift
//  share-my-status-client
//


import SwiftUI

/// Status indicator component
struct StatusIndicator: View {
    let isActive: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

/// Connection status view
struct ConnectionStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            
            Text(isConnected ? "已连接" : "未连接")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        StatusIndicator(isActive: true, text: "正在运行")
        StatusIndicator(isActive: false, text: "已停止")
        ConnectionStatusView(isConnected: true)
        ConnectionStatusView(isConnected: false)
    }
    .padding()
}


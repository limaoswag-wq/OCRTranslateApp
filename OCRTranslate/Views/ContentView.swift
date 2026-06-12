import SwiftUI

struct ContentView: View {
    @StateObject private var broadcastMonitor = BroadcastMonitor.shared
    @StateObject private var translationManager = TranslationManager.shared
    @State private var showSettings = false
    @State private var showBroadcastPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Status Card
                        statusCard
                        
                        // Start/Stop Button
                        broadcastButton
                        
                        // Latest Translation
                        if !broadcastMonitor.lastOCRText.isEmpty {
                            translationCard
                        }
                        
                        // History placeholder
                        historySection
                    }
                    .padding()
                }
            }
            .navigationTitle("OCR 屏幕翻译")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(broadcastMonitor.isBroadcasting ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(broadcastMonitor.isBroadcasting ? "正在翻译中" : "等待启动")
                    .font(.headline)
                
                Spacer()
                
                Text(currentEngineName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            
            if let lastUpdate = broadcastMonitor.lastUpdateTime {
                Text("上次更新: \(lastUpdate, style: .relative)前")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Broadcast Button
    
    private var broadcastButton: some View {
        Button {
            triggerBroadcast()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: broadcastMonitor.isBroadcasting ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(broadcastMonitor.isBroadcasting ? "停止翻译" : "开始屏幕翻译")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(broadcastMonitor.isBroadcasting ? Color.red : Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // MARK: - Translation Result Card
    
    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最新识别结果")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                // Original text
                VStack(alignment: .leading, spacing: 4) {
                    Label("原文", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(broadcastMonitor.lastOCRText)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                Divider()
                
                // Translated text
                VStack(alignment: .leading, spacing: 4) {
                    Label("译文", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(broadcastMonitor.lastTranslatedText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用说明")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(icon: "1.circle.fill", text: "点击「开始屏幕翻译」按钮")
                instructionRow(icon: "2.circle.fill", text: "在弹出的系统菜单中选择「开始直播」")
                instructionRow(icon: "3.circle.fill", text: "切换到需要翻译的应用（如游戏）")
                instructionRow(icon: "4.circle.fill", text: "悬浮窗将自动显示翻译结果")
                instructionRow(icon: "5.circle.fill", text: "使用完毕后点击「停止翻译」")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private var currentEngineName: String {
        translationManager.config.engineType.displayName
    }
    
    private func triggerBroadcast() {
        if broadcastMonitor.isBroadcasting {
            broadcastMonitor.sendStopCommand()
            broadcastMonitor.isBroadcasting = false
        } else {
            // Trigger the system broadcast picker
            showBroadcastPicker = true
            // The actual broadcast start is handled by the system
            // We simulate the state change for UI purposes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                broadcastMonitor.isBroadcasting = true
            }
        }
    }
}

#Preview {
    ContentView()
}

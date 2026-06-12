import SwiftUI
import ReplayKit

struct ContentView: View {
    @StateObject private var broadcastMonitor = BroadcastMonitor.shared
    @StateObject private var translationManager = TranslationManager.shared
    @State private var showSettings = false
    @State private var broadcastController: RPBroadcastActivityViewController?
    @State private var showBroadcastPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        statusCard
                        broadcastButton
                        ocrRegionCard
                        
                        if !broadcastMonitor.lastOCRText.isEmpty {
                            translationCard
                        }
                        
                        historySection
                    }
                    .padding()
                }
            }
            .navigationTitle("OCR 屏幕翻译")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .overlay {
                if showBroadcastPicker {
                    BroadcastPickerOverlay(isShowing: $showBroadcastPicker)
                }
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
    
    // MARK: - OCR Region Card
    
    private var ocrRegionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OCR 识别区域")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(OCRRegion.allCases, id: \.self) { region in
                    Button {
                        translationManager.config.ocrRegion = region
                        translationManager.saveSettings()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: region.icon)
                                .font(.title3)
                            Text(region.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            translationManager.config.ocrRegion == region
                                ? Color.accentColor.opacity(0.15)
                                : Color(.tertiarySystemGroupedBackground)
                        )
                        .foregroundColor(
                            translationManager.config.ocrRegion == region
                                ? .accentColor
                                : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Translation Result Card
    
    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最新识别结果")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("原文", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(broadcastMonitor.lastOCRText)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                Divider()
                
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
                instructionRow(icon: "4.circle.fill", text: "App 将自动识别屏幕文字并翻译")
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
            showBroadcastPicker = true
        }
    }
}

// MARK: - Broadcast Picker Overlay

struct BroadcastPickerOverlay: UIViewRepresentable {
    @Binding var isShowing: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = "com.limaoswag.ocrtranslate.ScreenTranslator"
        picker.showsMicrophoneButton = false
        picker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(picker)
        picker.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        picker.center = view.center
        
        // Auto-trigger the picker tap after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                    break
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isShowing = false
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

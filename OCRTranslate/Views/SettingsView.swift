import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var translationManager = TranslationManager.shared
    @State private var showAISettings = false
    
    private let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "自动检测"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁体中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("ar", "العربية"),
        ("th", "ไทย"),
        ("vi", "Tiếng Việt"),
        ("it", "Italiano"),
        ("nl", "Nederlands"),
        ("pl", "Polski"),
        ("tr", "Türkçe"),
        ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"),
        ("ms", "Bahasa Melayu"),
        ("sv", "Svenska"),
        ("da", "Dansk"),
        ("fi", "Suomi"),
        ("no", "Norsk"),
        ("cs", "Čeština"),
        ("el", "Ελληνικά"),
        ("he", "עברית"),
        ("hu", "Magyar"),
        ("ro", "Română"),
        ("uk", "Українська")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Translation Engine Selection
                Section {
                    Picker("翻译引擎", selection: $translationManager.config.engineType) {
                        ForEach(TranslationEngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .onChange(of: translationManager.config.engineType) { _ in
                        translationManager.saveSettings()
                    }
                } header: {
                    Text("翻译引擎")
                } footer: {
                    Text("Apple 翻译支持离线使用，需在设置中下载语言包。其他引擎需要网络连接。")
                }
                
                // Language Settings
                Section("语言设置") {
                    Picker("源语言", selection: $translationManager.config.sourceLanguage) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: translationManager.config.sourceLanguage) { _ in
                        translationManager.saveSettings()
                    }
                    
                    Picker("目标语言", selection: $translationManager.config.targetLanguage) {
                        ForEach(supportedLanguages.filter { $0.code != "auto" }, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .onChange(of: translationManager.config.targetLanguage) { _ in
                        translationManager.saveSettings()
                    }
                }
                
                // API Settings (conditional)
                if translationManager.config.engineType != .apple {
                    Section {
                        if translationManager.config.engineType == .openai {
                            aiSettingsView
                        } else {
                            cloudAPISettingsView
                        }
                    } header: {
                        Text("API 配置")
                    }
                }
                
                // OCR Settings
                Section {
                    HStack {
                        Text("识别频率")
                        Spacer()
                        Text("每 1.5 秒")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("变化阈值")
                        Spacer()
                        Text("15%")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("OCR 设置")
                } footer: {
                    Text("当屏幕文字变化超过阈值时触发翻译，避免重复翻译相同内容。")
                }
                
                // About
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Cloud API Settings
    
    private var cloudAPISettingsView: some View {
        Group {
            SecureField("API Key", text: $translationManager.config.apiKey)
                .textContentType(.password)
                .onChange(of: translationManager.config.apiKey) { _ in
                    translationManager.saveSettings()
                }
            
            if translationManager.config.engineType == .baidu {
                SecureField("密钥", text: $translationManager.config.apiSecret)
                    .textContentType(.password)
                    .onChange(of: translationManager.config.apiSecret) { _ in
                        translationManager.saveSettings()
                    }
            }
            
            if translationManager.config.engineType == .tencent {
                SecureField("SecretKey", text: $translationManager.config.apiSecret)
                    .textContentType(.password)
                    .onChange(of: translationManager.config.apiSecret) { _ in
                        translationManager.saveSettings()
                    }
            }
        }
    }
    
    // MARK: - AI Settings
    
    private var aiSettingsView: some View {
        Group {
            TextField("API 地址", text: $translationManager.config.apiEndpoint)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .onChange(of: translationManager.config.apiEndpoint) { _ in
                    translationManager.saveSettings()
                }
            
            SecureField("API Key", text: $translationManager.config.apiKey)
                .textContentType(.password)
                .onChange(of: translationManager.config.apiKey) { _ in
                    translationManager.saveSettings()
                }
            
            TextField("模型名称", text: $translationManager.config.aiModel)
                .autocapitalization(.none)
                .onChange(of: translationManager.config.aiModel) { _ in
                    translationManager.saveSettings()
                }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt 提示词")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $translationManager.config.aiPrompt)
                    .frame(minHeight: 120)
                    .font(.caption)
                    .onChange(of: translationManager.config.aiPrompt) { _ in
                        translationManager.saveSettings()
                    }
            }
        }
    }
}

#Preview {
    SettingsView()
}

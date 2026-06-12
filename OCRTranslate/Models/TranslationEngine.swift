import Foundation

// MARK: - Translation Engine Types

enum TranslationEngineType: String, Codable, CaseIterable {
    case apple = "apple"
    case google = "google"
    case baidu = "baidu"
    case tencent = "tencent"
    case openai = "openai"
    
    var displayName: String {
        switch self {
        case .apple:   return "Apple 翻译（离线）"
        case .google:  return "Google Translate"
        case .baidu:   return "百度翻译"
        case .tencent: return "腾讯翻译"
        case .openai:  return "AI 翻译（自定义）"
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .apple: return false
        default:     return true
        }
    }
}

// MARK: - Translation Engine Configuration

struct TranslationEngineConfig: Codable {
    var engineType: TranslationEngineType = .apple
    
    // API settings for cloud engines
    var apiKey: String = ""
    var apiSecret: String = ""
    var apiEndpoint: String = ""
    
    // AI-specific settings
    var aiModel: String = ""
    var aiPrompt: String = """
我将给你发送JSON格式的内容, 每个键都是待翻译文本内容, 值都是空字符串. 我需要你把每个键的文本内容翻译为简体中文, 然后回填到原本是空字符串的值里. 请注意不要对翻译做解释, 直接给出译文, 并保持JSON格式返回给我
"""
    
    // Language settings
    var sourceLanguage: String = "auto"
    var targetLanguage: String = "zh-Hans"
}

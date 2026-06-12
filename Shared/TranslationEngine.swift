import Foundation

// MARK: - OCR Region

enum OCRRegion: String, Codable, CaseIterable {
    case full = "full"
    case top = "top"
    case bottom = "bottom"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .full:   return "全屏"
        case .top:    return "上半屏"
        case .bottom: return "下半屏"
        case .custom: return "自定义"
        }
    }
    
    var icon: String {
        switch self {
        case .full:   return "rectangle"
        case .top:    return "rectangle.topthird.inset.filled"
        case .bottom: return "rectangle.bottomthird.inset.filled"
        case .custom: return "rectangle.and.hand.point.up.left"
        }
    }
    
    /// Returns the crop rect as fraction of screen (x, y, width, height)
    var cropRect: CGRect {
        switch self {
        case .full:
            return CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        case .top:
            return CGRect(x: 0.05, y: 0.0, width: 0.9, height: 0.5)
        case .bottom:
            return CGRect(x: 0.05, y: 0.5, width: 0.9, height: 0.5)
        case .custom:
            // Default custom: center 60% area
            return CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6)
        }
    }
}

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
    
    // OCR region settings
    var ocrRegion: OCRRegion = .full
}

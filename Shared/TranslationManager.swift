import Foundation
import NaturalLanguage

class TranslationManager: ObservableObject {
    static let shared = TranslationManager()
    
    @Published var config = TranslationEngineConfig()
    
    private let defaults = UserDefaults(suiteName: "group.com.limaoswag.ocrtranslate") ?? .standard
    private let configKey = "translationEngineConfig"
    
    private init() {}
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }
    
    func loadSettings() {
        guard let data = defaults.data(forKey: configKey),
              let saved = try? JSONDecoder().decode(TranslationEngineConfig.self, from: data) else { return }
        config = saved
    }
    
    func translate(_ text: String, completion: @escaping (String?) -> Void) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(nil)
            return
        }
        
        switch config.engineType {
        case .apple:
            translateWithApple(text, completion: completion)
        case .google:
            translateWithGoogle(text, completion: completion)
        case .baidu:
            translateWithBaidu(text, completion: completion)
        case .tencent:
            translateWithTencent(text, completion: completion)
        case .openai:
            translateWithAI(text, completion: completion)
        }
    }
    
    // MARK: - Apple Translation (Language Detection Only)
    
    private func translateWithApple(_ text: String, completion: @escaping (String?) -> Void) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let lang = recognizer.dominantLanguage?.rawValue ?? "unknown"
        DispatchQueue.main.async {
            completion("[检测到: \(lang)] 请在设置中切换为Google或AI翻译引擎")
        }
    }
    
    // MARK: - Google Translate
    
    private func translateWithGoogle(_ text: String, completion: @escaping (String?) -> Void) {
        guard !config.apiKey.isEmpty else {
            completion("[请配置 Google API Key]")
            return
        }
        
        let targetLang = config.targetLanguage == "zh-Hans" ? "zh-CN" : config.targetLanguage
        
        var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "target", value: targetLang),
            URLQueryItem(name: "key", value: config.apiKey),
            URLQueryItem(name: "format", value: "text")
        ]
        if config.sourceLanguage != "auto" {
            components.queryItems?.append(URLQueryItem(name: "source", value: config.sourceLanguage))
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = json["data"] as? [String: Any],
                      let translations = dataObj["translations"] as? [[String: Any]],
                      let first = translations.first,
                      let translated = first["translatedText"] as? String else {
                    completion("[Google翻译失败]")
                    return
                }
                completion(translated)
            }
        }.resume()
    }
    
    // MARK: - Baidu Translate
    
    private func translateWithBaidu(_ text: String, completion: @escaping (String?) -> Void) {
        guard !config.apiKey.isEmpty, !config.apiSecret.isEmpty else {
            completion("[请配置百度翻译 AppID 和密钥]")
            return
        }
        
        let salt = "\(Int.random(in: 10000...99999))"
        let signStr = config.apiKey + text + salt + config.apiSecret
        let sign = signStr.md5
        
        let sourceLang = config.sourceLanguage == "auto" ? "auto" : config.sourceLanguage
        let targetLang = config.targetLanguage == "zh-Hans" ? "zh" : config.targetLanguage
        
        let urlStr = "https://fanyi-api.baidu.com/api/trans/vip/translate?q=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&from=\(sourceLang)&to=\(targetLang)&appid=\(config.apiKey)&salt=\(salt)&sign=\(sign)"
        
        guard let url = URL(string: urlStr) else {
            completion("[百度翻译URL错误]")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["trans_result"] as? [[String: Any]] else {
                    completion("[百度翻译失败]")
                    return
                }
                let translated = results.compactMap { $0["dst"] as? String }.joined(separator: "\n")
                completion(translated.isEmpty ? "[百度翻译结果为空]" : translated)
            }
        }.resume()
    }
    
    // MARK: - Tencent Translate
    
    private func translateWithTencent(_ text: String, completion: @escaping (String?) -> Void) {
        guard !config.apiKey.isEmpty, !config.apiSecret.isEmpty else {
            completion("[请配置腾讯翻译 SecretId 和 SecretKey]")
            return
        }
        completion("[腾讯翻译需要完整SDK，请使用其他引擎]")
    }
    
    // MARK: - AI Translation (OpenAI Compatible)
    
    private func translateWithAI(_ text: String, completion: @escaping (String?) -> Void) {
        guard !config.apiKey.isEmpty, !config.apiEndpoint.isEmpty else {
            completion("[请配置AI翻译API地址和Key]")
            return
        }
        
        let model = config.aiModel.isEmpty ? "gpt-3.5-turbo" : config.aiModel
        let prompt = config.aiPrompt.isEmpty ? "Translate the following text to \(config.targetLanguage):" : config.aiPrompt
        
        let textDict = [text: ""]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: textDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion("[AI翻译数据格式错误]")
            return
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": jsonString]
            ],
            "temperature": 0.3
        ]
        
        let endpoint = config.apiEndpoint.hasSuffix("/chat/completions") ? config.apiEndpoint : config.apiEndpoint + "/v1/chat/completions"
        
        guard let url = URL(string: endpoint) else {
            completion("[AI翻译URL无效]")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion("[AI翻译失败]")
                    return
                }
                
                if let contentData = content.data(using: .utf8),
                   let resultDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: String],
                   let translated = resultDict[text] {
                    completion(translated)
                } else {
                    completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }.resume()
    }
    
    // MARK: - Language Helpers
    
    private func detectLanguage(_ text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }
    
    private func languageCodeToNLLanguage(_ code: String) -> NLLanguage? {
        let mapping: [String: NLLanguage] = [
            "zh-Hans": .simplifiedChinese,
            "zh-Hant": .traditionalChinese,
            "en": .english,
            "ja": .japanese,
            "ko": .korean,
            "fr": .french,
            "de": .german,
            "es": .spanish,
            "pt": .portuguese,
            "ru": .russian,
            "ar": .arabic,
            "th": .thai,
            "vi": .vietnamese,
            "it": .italian,
            "nl": .dutch,
            "pl": .polish,
            "tr": .turkish
        ]
        return mapping[code]
    }
}

import CryptoKit

extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

import Foundation

struct TranslateResult: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
    
    init(originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        self.id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
    }
}

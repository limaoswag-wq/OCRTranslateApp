import ReplayKit
import Vision
import CoreImage
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    
    private let ocrEngine = OCREngine.shared
    private let translationManager = TranslationManager.shared
    
    private var lastOCRFrame: OCRFrame?
    private var lastProcessTime: TimeInterval = 0
    private var frameCount: Int = 0
    
    private let processEveryNFrames = 30
    private let minimumProcessInterval: TimeInterval = 1.5
    
    private let appGroupID = "group.com.limaoswag.ocrtranslate"
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    private var translationDataPath: URL? {
        sharedContainerURL?.appendingPathComponent("translation_data.json")
    }
    
    // MARK: - Broadcast Lifecycle
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[Broadcast] Started")
        translationManager.loadSettings()
        lastProcessTime = Date().timeIntervalSince1970
        frameCount = 0
        writeStatus("broadcasting")
    }
    
    override func broadcastPaused() {
        print("[Broadcast] Paused")
    }
    
    override func broadcastResumed() {
        print("[Broadcast] Resumed")
    }
    
    override func broadcastFinished() {
        print("[Broadcast] Finished")
        writeStatus("stopped")
    }
    
    // MARK: - Sample Buffer Processing
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            processVideoFrame(sampleBuffer)
        default:
            break
        }
    }
    
    // MARK: - Video Frame Processing
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        guard frameCount % processEveryNFrames == 0 else { return }
        
        let now = Date().timeIntervalSince1970
        guard now - lastProcessTime >= minimumProcessInterval else { return }
        lastProcessTime = now
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        let extent = ciImage.extent
        let region = translationManager.config.ocrRegion.cropRect
        let cropRect = CGRect(
            x: extent.width * region.origin.x,
            y: extent.height * region.origin.y,
            width: extent.width * region.size.width,
            height: extent.height * region.size.height
        )
        let croppedImage = ciImage.cropped(to: cropRect)
        
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else { return }
        
        performOCR(on: cgImage)
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on image: CGImage) {
        let semaphore = DispatchSemaphore(value: 0)
        
        ocrEngine.recognizeText(from: image) { [weak self] blocks in
            guard let self = self else {
                semaphore.signal()
                return
            }
            
            let newFrame = OCRFrame(blocks: blocks, timestamp: Date())
            
            guard self.ocrEngine.hasContentChanged(old: self.lastOCRFrame, new: newFrame) else {
                semaphore.signal()
                return
            }
            
            self.lastOCRFrame = newFrame
            let text = newFrame.fullText
            
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                semaphore.signal()
                return
            }
            
            print("[OCR] New text: \(text.prefix(50))...")
            
            self.translationManager.translate(text) { [weak self] translatedText in
                guard let self = self, let translated = translatedText else {
                    semaphore.signal()
                    return
                }
                
                let result = TranslateResult(
                    originalText: text,
                    translatedText: translated,
                    sourceLanguage: self.translationManager.config.sourceLanguage,
                    targetLanguage: self.translationManager.config.targetLanguage
                )
                self.writeTranslation(result)
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: .now() + 3.0)
    }
    
    // MARK: - Shared Data Writing
    
    private func writeTranslation(_ result: TranslateResult) {
        guard let path = translationDataPath else { return }
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: path, options: .atomic)
        } catch {
            print("[Broadcast] Write error: \(error)")
        }
    }
    
    private func writeStatus(_ status: String) {
        guard let container = sharedContainerURL else { return }
        let path = container.appendingPathComponent("broadcast_status.txt")
        try? status.write(to: path, atomically: true, encoding: .utf8)
    }
}

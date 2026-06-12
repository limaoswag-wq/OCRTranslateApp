import ReplayKit
import Vision
import CoreImage
import UIKit
import os.log

private let logger = Logger(subsystem: "com.limaoswag.ocrtranslate.ScreenTranslator", category: "Broadcast")

class SampleHandler: RPBroadcastSampleHandler {
    
    // MARK: - Properties
    
    private let ocrEngine = OCREngine.shared
    private let translationManager = TranslationManager.shared
    
    private var lastOCRFrame: OCRFrame?
    private var lastProcessTime: TimeInterval = 0
    private var frameCount: Int = 0
    
    // Process OCR every N frames to reduce CPU usage
    private let processEveryNFrames = 30  // ~1 second at 30fps
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
        logger.info("Broadcast started")
        translationManager.loadSettings()
        lastProcessTime = Date().timeIntervalSince1970
        frameCount = 0
        
        // Write initial status
        writeStatus("broadcasting")
    }
    
    override func broadcastPaused() {
        logger.info("Broadcast paused")
    }
    
    override func broadcastResumed() {
        logger.info("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        logger.info("Broadcast finished")
        writeStatus("stopped")
    }
    
    // MARK: - Sample Buffer Processing
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            processVideoFrame(sampleBuffer)
        case .audioApp:
            // Ignore audio - we don't need it for OCR
            break
        case .audioMic:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Video Frame Processing
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        
        // Throttle: only process every N frames
        guard frameCount % processEveryNFrames == 0 else { return }
        
        // Also check time interval
        let now = Date().timeIntervalSince1970
        guard now - lastProcessTime >= minimumProcessInterval else { return }
        lastProcessTime = now
        
        // Extract CGImage from sample buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("Failed to get image buffer")
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        // Crop to center 80% to avoid status bar and dock
        let extent = ciImage.extent
        let cropRect = CGRect(
            x: extent.width * 0.05,
            y: extent.height * 0.05,
            width: extent.width * 0.9,
            height: extent.height * 0.9
        )
        let croppedImage = ciImage.cropped(to: cropRect)
        
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else {
            logger.error("Failed to create CGImage")
            return
        }
        
        // Run OCR
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
            
            // Check if content has changed
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
            
            logger.info("OCR detected new text: \(text.prefix(50))...")
            
            // Translate
            self.translationManager.translate(text) { [weak self] translatedText in
                guard let self = self, let translated = translatedText else {
                    semaphore.signal()
                    return
                }
                
                logger.info("Translation result: \(translated.prefix(50))...")
                
                // Write to shared container
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
        
        // Wait for completion with timeout
        _ = semaphore.wait(timeout: .now() + 3.0)
    }
    
    // MARK: - Shared Data Writing
    
    private func writeTranslation(_ result: TranslateResult) {
        guard let path = translationDataPath else {
            logger.error("No shared container path")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: path, options: .atomic)
            logger.info("Translation written to shared container")
        } catch {
            logger.error("Failed to write translation: \(error.localizedDescription)")
        }
    }
    
    private func writeStatus(_ status: String) {
        guard let container = sharedContainerURL else { return }
        let path = container.appendingPathComponent("broadcast_status.txt")
        try? status.write(to: path, atomically: true, encoding: .utf8)
    }
}

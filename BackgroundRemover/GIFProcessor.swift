// GIFProcessor.swift

import SwiftUI
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

struct GIFFrame: Identifiable {
    let id = UUID()
    var image: UIImage
    var delay: TimeInterval
}

struct GIFMetadata {
    var frames: [GIFFrame]
    var loopCount: Int
}

class GIFProcessor: ObservableObject {
    @Published var gifMetadata: GIFMetadata?
    @Published var isProcessing = false
    private let fileManager = FileManager.default
    private let pipeline = EffectsPipeline()
    
    func loadGIF(url: URL) {
        guard let frames = extractFramesAndTiming(from: url) else { return }
        let loopCount = getLoopCount(from: url)
        gifMetadata = GIFMetadata(frames: frames, loopCount: loopCount)
    }
    
    func processGIF() {
        guard let frames = gifMetadata?.frames else { return }
        let tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent("gifProcessing", isDirectory: true)
        do {
            try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create temporary directory: \(error)")
            return
        }
        
        isProcessing = true
        for (index, frame) in frames.enumerated() {
            guard let imageData = frame.image.pngData() else { continue }
            let frameURL = tempDirectoryURL.appendingPathComponent("frame_\(index).png")
            do {
                try imageData.write(to: frameURL)
            } catch {
                print("Failed to write frame to temporary directory: \(error)")
            }
        }
        
        pipeline.processFolder(url: tempDirectoryURL) { [weak self] in
            self?.reassembleGIF(from: tempDirectoryURL)
            self?.isProcessing = false
        }
    }
    
    func reassembleGIF(from folderURL: URL) {
        guard let frames = gifMetadata?.frames, frames.count > 0 else { return }
        let frameDelay = frames.map { $0.delay }
        let destinationURL = folderURL.appendingPathComponent("output.gif")
        var cgImages = [CGImage]()
        
        for frame in frames {
            if let cgImage = frame.image.cgImage {
                cgImages.append(cgImage)
            }
        }
        
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeGIF, cgImages.count, nil) else { return }
        
        let gifProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: gifMetadata?.loopCount ?? 0]]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        for (index, cgImage) in cgImages.enumerated() {
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay[index]]]
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }
        
        if !CGImageDestinationFinalize(destination) {
            print("Failed to finalize GIF creation.")
            return
        }
        
        print("GIF reassembled at \(destinationURL.path)")
    }
    
    private func extractFramesAndTiming(from url: URL) -> [GIFFrame]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var frames: [GIFFrame] = []
        let count = CGImageSourceGetCount(source)
        
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let delay = getFrameDelay(for: source, at: index)
            frames.append(GIFFrame(image: UIImage(cgImage: cgImage), delay: delay))
        }
        return frames
    }
    
    private func getFrameDelay(for source: CGImageSource, at index: Int) -> TimeInterval {
        let defaultDelay = 0.1
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
              let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval ?? gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval else {
            return defaultDelay
        }
        return delayTime < 0.02 ? defaultDelay : delayTime
    }
    
    private func getLoopCount(from url: URL) -> Int {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyProperties(source, nil) as? [String: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
              let loopCount = gifProperties[kCGImagePropertyGIFLoopCount as String] as? Int else {
            return 0
        }
        return loopCount
    }
}

struct GIFEditorView: View {
    @ObservedObject var gifProcessor = GIFProcessor()
    
    var body: some View {
        VStack {
            if let gifMetadata = gifProcessor.gifMetadata {
                List(gifMetadata.frames) { frame in
                    HStack {
                        Image(uiImage: frame.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        Text("Delay: \(frame.delay) seconds")
                    }
                }
                Button("Process GIF") {
                    gifProcessor.processGIF()
                }
                .disabled(gifProcessor.isProcessing)
                
                if gifProcessor.isProcessing {
                    ProgressView()
                }
            } else {
                Text("No GIF loaded")
            }
        }
//        .onAppear {
//            // Load the GIF from your assets or a specific URL when the view appears
//            if let url = Bundle.main.url(forResource: "yourGIF", withExtension: "gif") {
//                gifProcessor.loadGIF(url: url)
//            }
//        }
    }
}

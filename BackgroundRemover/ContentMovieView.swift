//
//  ContentMovieView.swift
import SwiftUI
import AVFoundation

struct ContentMovieView: View {
    @State private var showMoviePicker = false
    @State private var outputDirectory: URL?
    @ObservedObject var effectsPipeline = EffectsPipeline()
    @State private var videoInfo: VideoInfo?

    struct VideoInfo {
        var duration: Double
        var resolution: CGSize
        var frameRate: Double
        var totalFrames: Int
    }

    var body: some View {
        VStack {
            Button("Select Movie") {
                showMoviePicker = true
            }
            .fileImporter(
                isPresented: $showMoviePicker,
                allowedContentTypes: [.movie],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }

            if let info = videoInfo {
                Text("Duration: \(info.duration) seconds")
                Text("Resolution: \(Int(info.resolution.width)) x \(Int(info.resolution.height))")
                Text("Frame Rate: \(info.frameRate) fps")
                Text("Total Frames: \(info.totalFrames)")
            }

            if let outputDirectory = outputDirectory {
                Text("Output Directory: \(outputDirectory.path)")
            }
        }
    }

    private  func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let movieURL = urls[0]
            let outputDirectory = movieURL.deletingPathExtension().standardizedFileURL
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                self.outputDirectory = outputDirectory
                extractAllFrames(from: movieURL, outputDirectory: outputDirectory)  
                extractMovieInfo(movieURL: movieURL)

            } catch {
                print("Error creating directory: \(error.localizedDescription)")
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }

    func extractMovieInfo(movieURL: URL) {
        let asset = AVAsset(url: movieURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("No video track found in asset.")
            return
        }
        let resolution = videoTrack.naturalSize
        let frameRate = videoTrack.nominalFrameRate
        let totalFrames = Int(duration * Double(frameRate))

        videoInfo = VideoInfo(duration: duration, resolution: resolution, frameRate: Double(frameRate), totalFrames: totalFrames)
    }
}
    func extractAllFrames(from movieURL: URL, outputDirectory: URL) {
        let asset = AVAsset(url: movieURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("No video track found in asset.")
            return
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            print("Failed to initialize AVAssetReader.")
            return
        }

        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)])
        reader.add(readerOutput)

        reader.startReading()

        var frameIndex = 0
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvImageBuffer: imageBuffer)
                let uiImage = UIImage(ciImage: ciImage)

                if let imageData = uiImage.pngData() {
                    let fileName = "frame_\(frameIndex).png"
                    let fileURL = outputDirectory.appendingPathComponent(fileName)

                    do {
                        try imageData.write(to: fileURL)
                        print("Saved frame \(frameIndex) to \(fileURL.path)")
                    } catch {
                        print("Failed to save frame \(frameIndex): \(error.localizedDescription)")
                    }
                }
            }
            frameIndex += 1
        }
//    private func handleFileSelection(result: Result<[URL], Error>) {
//        switch result {
//        case .success(let urls):
//            let movieURL = urls[0]
//            let outputDirectory = movieURL.deletingPathExtension().standardizedFileURL
//            do {
//                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
//                self.outputDirectory = outputDirectory
//                extractMovieFrames(movieURL: movieURL, outputDirectory: outputDirectory)
//            } catch {
//                print("Error creating directory: \(error.localizedDescription)")
//            }
//        case .failure(let error):
//            print("Error selecting file: \(error.localizedDescription)")
//        }
//    }
//    func getFrameRate(from movieURL: URL, completion: @escaping (Int?) -> Void) {
//        let asset = AVAsset(url: movieURL)
//        let keys = ["tracks"]
//        
//        asset.loadValuesAsynchronously(forKeys: keys) {
//            var error: NSError? = nil
//            let status = asset.statusOfValue(forKey: "tracks", error: &error)
//            if status == .loaded {
//                guard let videoTrack = asset.tracks(withMediaType: .video).first else {
//                    print("No video track found in asset.")
//                    completion(nil)
//                    return
//                }
//                
//                let frameRate = Int(round(videoTrack.nominalFrameRate))
//                completion(frameRate)
//            } else {
//                print("Error loading tracks: \(error?.localizedDescription ?? "Unknown error")")
//                completion(nil)
//            }
//        }
//}    
//    func extractMovieFrames(movieURL: URL, outputDirectory: URL) {
//        let asset = AVAsset(url: movieURL)
//        let imageGenerator = AVAssetImageGenerator(asset: asset)
//        imageGenerator.appliesPreferredTrackTransform = true
//        
//        let times = asset.duration.seconds / Double(asset.duration.timescale)
//        getFrameRate(from: movieURL) { frameRate in
//        let finalFrameRate = frameRate ?? 30 // Default to 30 fps if frame rate can't be determined
//        // Use finalFrameRate for further processing
//
//
//            for i in 0..<(frameRate ?? 30) {
//            let time = CMTime(seconds: Double(i) / 30.0, preferredTimescale: asset.duration.timescale)
//            do {
//                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
//                let fileName = "frame_\(i).png"
//                let fileURL = outputDirectory.appendingPathComponent(fileName)
//
//                guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil) else {
//                    print("Could not create image destination.")
//                    continue
//                }
//
//                CGImageDestinationAddImage(destination, cgImage, nil)
//
//                if !CGImageDestinationFinalize(destination) {
//                    print("Failed to write image to \(fileURL).")
//                }
//            } catch {
//                print("Error extracting frame at time \(time): \(error.localizedDescription)")
//            }
//    }
//}
//    }
    }



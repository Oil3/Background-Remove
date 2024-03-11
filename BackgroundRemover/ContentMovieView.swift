//
//  ContentMovieView.swift
import SwiftUI
import AVFoundation

struct ContentMovieView: View {
    @State private var showMoviePicker = false
    @State private var showFolderPicker = false
    @State private var outputDirectory: URL?
    @ObservedObject var effectsPipeline = EffectsPipeline()

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

            Button("Process Folder") {
                showFolderPicker = true
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    let folderURL = urls[0]
                    effectsPipeline.processFolder(url: folderURL) {
                        print("Folder processing completed.")
                    }
                case .failure(let error):
                    print("Error selecting folder: \(error.localizedDescription)")
                }
            }
            
            if let outputDirectory = outputDirectory {
                Text("Output Directory: \(outputDirectory.path)")
            }
        }
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let movieURL = urls[0]
            let outputDirectory = movieURL.deletingPathExtension().standardizedFileURL
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                self.outputDirectory = outputDirectory
                extractMovieFrames(movieURL: movieURL, outputDirectory: outputDirectory)
            } catch {
                print("Error creating directory: \(error.localizedDescription)")
            }
        case .failure(let error):
            print("Error selecting file: \(error.localizedDescription)")
        }
    }
    func getFrameRate(from movieURL: URL) -> Int? {
        let asset = AVAsset(url: movieURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("No video track found in asset.")
            return nil
        }
        let frameRate = videoTrack.nominalFrameRate
//        return Double(frameRate)
        return Int(round(frameRate))

    }
    
    func extractMovieFrames(movieURL: URL, outputDirectory: URL) {
        let asset = AVAsset(url: movieURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let times = asset.duration.seconds / Double(asset.duration.timescale)
        let frameRate = getFrameRate(from: movieURL) ?? 30 // Default to 30 fps if frame rate can't be determined

        for i in 0..<frameRate {
            let time = CMTime(seconds: Double(i) / 30.0, preferredTimescale: asset.duration.timescale)
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let fileName = "frame_\(i).png"
                let fileURL = outputDirectory.appendingPathComponent(fileName)

                guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil) else {
                    print("Could not create image destination.")
                    continue
                }

                CGImageDestinationAddImage(destination, cgImage, nil)

                if !CGImageDestinationFinalize(destination) {
                    print("Failed to write image to \(fileURL).")
                }
            } catch {
                print("Error extracting frame at time \(time): \(error.localizedDescription)")
            }
    }
}
    }



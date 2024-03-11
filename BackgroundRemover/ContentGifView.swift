//
//  ContentGifView.swift
import SwiftUI
import MobileCoreServices
import ImageIO

struct ContentGifView: View {
    @State private var showFilePicker = false
    @State private var outputDirectory: URL?

    var body: some View {
        VStack {
            Button("Select GIF") {
                showFilePicker = true
            }
            
            if let outputDirectory = outputDirectory {
                Text("Output Directory: \(outputDirectory.path)")
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.gif],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                let gifURL = urls[0]
                let outputDirectory = gifURL.deletingPathExtension().standardizedFileURL
                do {
                    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                    self.outputDirectory = outputDirectory
                    extractGIFFrames(gifURL: gifURL, outputDirectory: outputDirectory)
                } catch {
                    print("Error creating directory: \(error.localizedDescription)")
                }                

            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
    }
}

func extractGIFFrames(gifURL: URL, outputDirectory: URL) {
    guard let source = CGImageSourceCreateWithURL(gifURL as CFURL, nil) else {
        print("Could not create image source.")
        return
    }
    
    let count = CGImageSourceGetCount(source)
    
    for i in 0..<count {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
            print("Could not create image for frame \(i).")
            continue
        }
        
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
    }
}

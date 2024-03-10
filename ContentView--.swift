//
//  ContentView--.swift
//  SubjectLiftingEffects
//
//  Created by ZZS on 10/03/2024.
//  Copyright © 2024 Apple. All rights reserved.
//
import SwiftUI
import UniformTypeIdentifiers
import Combine
import PhotosUI 

struct ImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.image] }
    var image: UIImage
    
    init(image: UIImage) {
        self.image = image
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.image = image
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ProcessedImage: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage
}

struct ContentView: View {
    @StateObject private var pipeline = EffectsPipeline()
    @State private var showFilePicker = false
    @State private var showSavePanel = false
    @State private var processedImages: [ProcessedImage] = []
    @State private var selectedImages: Set<UUID> = Set<UUID>()
    @State private var processingFolder = false
    
    var body: some View {
        VStack {
            if let outputImage = pipeline.output {
                Image(uiImage: outputImage)
                    .resizable()
                    .scaledToFit()
            }

            Button("Choose from Files") {
                showFilePicker = true
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                handleFilePickerResult(result)
            }

            Button("Process Folder") {
                showSavePanel = true
            }
            .fileImporter(isPresented: $showSavePanel, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                handleFolderPickerResult(result)
            }

            Button("Save Selected to Files") {
                saveSelectedImagesToFile()
            }
            .disabled(selectedImages.isEmpty)
            
            Button("Save All to Files") {
                saveAllImagesToFile()
            }
            .disabled(processedImages.isEmpty)
        }
        .disabled(processingFolder)
        .overlay {
            if processingFolder {
                ProgressView("Processing...")
            }
        }
    }
}

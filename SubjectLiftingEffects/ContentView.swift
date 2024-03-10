/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main interactive UI for subject-lifting effects.
*/

import PhotosUI 
import SwiftUI
import UniformTypeIdentifiers
import Combine


struct ImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.image] } // Define the content types your document can read.
    var image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    // Initialize your document with a configuration to read from a file.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let image = UIImage(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.image = image
    }

    // This method is called to write your document to a file.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
struct ContentView: View {
    @StateObject private var pipeline = EffectsPipeline()
    @State private var showFilePicker = false
    @State private var showSavePanel = false
    @State private var showFolderPicker = false

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
                switch result {
                case .success(let urls):
                    let url = urls[0]
                    if let imageData = try? Data(contentsOf: url),
                       let ciImage = CIImage(data: imageData) {
                        pipeline.inputImage = ciImage
                        pipeline.effect = .none // Assuming you have a specific effect for background removal or just want the subject
                        pipeline.background = .transparent // This should trigger the background removal
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }

            Button("Save Result Image") {
                if pipeline.output != nil {
                    showSavePanel = true
                }
            }
            .fileExporter(isPresented: $showSavePanel, document: ImageDocument(image: pipeline.output ?? UIImage()), contentType: .image, defaultFilename: "ResultImage") { result in
                switch result {
                case .success(let url):
                    print("Saved to \(url)")
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }

            Button("Process Folder") {
                showFolderPicker = true
            }
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                // Processing a folder of images for background removal can be integrated here.
                // This requires iterating over images in the folder, processing each as done with the single file selection.
            }
        }
    }
}

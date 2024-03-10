//ContentView.swift

//import PhotosUI 
import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ImageDocument: FileDocument { //this is necessary so far
    static var readableContentTypes: [UTType] { [.image] } // Define the content types. I prefer not but lets do best practices.
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
                        pipeline.effect = .none // core task is background removal but this might be purposeful too
                        pipeline.background = .transparent // This to trigger the background removal
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
                switch result {
                case .success(let urls):
                    let folderUrl = urls[0]
//                    processingFolder = true // Show a progress view or disable buttons
                    pipeline.processFolder(url: folderUrl) {
//                    processingFolder = false // Hide the progress view or enable buttons
                }
                case .failure(let error):
                    print(error.localizedDescription)
                }
        }
    }
}
}

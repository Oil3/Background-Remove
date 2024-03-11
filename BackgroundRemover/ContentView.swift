//ContentView.swift

//import PhotosUI 
import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ImageDocument: FileDocument { //this is necessary so far
    static var readableContentTypes: [UTType] { [.image] } // Define the content types. I prefer not but lets do best practices.
    static var writableContentTypes: [UTType] { [.png, .gif, .image, .movie] }
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
    @StateObject private var gifProcessor = GIFProcessor()
    @State private var showFilePicker = false
    @State private var showSavePanel = false
    @State private var showFolderPicker = false
    @State private var processingFolder = false
    @State private var showGIFPicker = false
    @State private var selectedGIFURL: URL?

    var body: some View {
        NavigationView {
            SidebarView(showFilePicker: $showFilePicker,
                        showSavePanel: $showSavePanel,
                        showFolderPicker: $showFolderPicker,
                        processingFolder: $processingFolder,
                        showGIFPicker: $showGIFPicker)
                        
            if let outputImage = pipeline.output {
                Image(uiImage: outputImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Select an image or folder to begin.")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle("Background Remover")
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
            .fileExporter(isPresented: $showSavePanel, document: ImageDocument(image: pipeline.output ?? UIImage()), contentType: .png) { result in
                switch result {
                case .success(let url):
                    print("Saved to \(url)")
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
            
            .fileImporter(
                isPresented: $showGIFPicker,
                allowedContentTypes: [.image], // Or a more specific type if desired
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, url.pathExtension.lowercased() == "gif" {
                        selectedGIFURL = url
                        gifProcessor.loadGIF(url: url) // Load the selected GIF
                    }
                case .failure(let error):
                    print("File selection error: \(error.localizedDescription)")
                }
            }

//            Button("Process Folder") {
//                showFolderPicker = true
//            }
            
            .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    let folderUrl = urls[0]
                    processingFolder = true // Show a progress view or disable buttons
                    pipeline.processFolder(url: folderUrl) {
//                    processingFolder = false // Hide the progress view or enable buttons
                }
                case .failure(let error):
                    print(error.localizedDescription)
                }
        }
    }
}


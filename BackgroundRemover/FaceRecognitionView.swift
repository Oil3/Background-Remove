import SwiftUI

struct FaceRecognitionView: View {
    @State private var resultText = "Select a photo and a folder to compare"
    @State private var isImageImporterPresented = false
    @State private var isFolderImporterPresented = false
    @State private var selectedImage: UIImage?
    @State private var folderURL: URL?

    var body: some View {
        VStack {
            Text(resultText)
                .padding()

            Button("Select Photo") {
                isImageImporterPresented = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .fileImporter(
                isPresented: $isImageImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, let image = UIImage(contentsOfFile: url.path) {
                        selectedImage = image
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }

            Button("Select Folder") {
                isFolderImporterPresented = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .fileImporter(
                isPresented: $isFolderImporterPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    folderURL = urls.first
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }

            if selectedImage != nil && folderURL != nil {
                Button("Start Comparison") {
                    compareFaceWithFolder()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }

    func compareFaceWithFolder() {
        guard let image = selectedImage, let folderURL = folderURL else {
            resultText = "Please select a photo and a folder"
            return
        }

        let faceRecognition = FaceDetectandRec()

        faceRecognition.extractEmbedding(from: image) { testEmbedding in
            guard let testEmbedding = testEmbedding else {
                resultText = "Failed to extract embedding from photo"
                return
            }

            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

                for fileURL in contents {
                    if let validateImage = UIImage(contentsOfFile: fileURL.path) {
                        faceRecognition.extractEmbedding(from: validateImage) { validateEmbedding in
                            guard let validateEmbedding = validateEmbedding else {
                                print("Failed to extract embedding from \(fileURL.lastPathComponent)")
                                return
                            }

                            let match = faceRecognition.isMatch(embedding1: testEmbedding, embedding2: validateEmbedding)
                            print(match ? "Match found with \(fileURL.lastPathComponent)" : "No match found with \(fileURL.lastPathComponent)")
                        }
                    }
                }

                resultText = "Comparison completed. Check console for results."
            } catch {
                print("Error reading folder contents: \(error)")
                resultText = "Error reading folder contents"
            }
        }
    }
}

struct FaceRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        FaceRecognitionView()
    }
}

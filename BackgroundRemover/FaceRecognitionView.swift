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

    let faceRecognition = FaceRecognition()

    faceRecognition.handleFaceRecognition(for: image) { processedImage in
        guard let processedImage = processedImage else {
            resultText = "Failed to process selected photo"
            return
        }

        // Save the processed selected image for debugging
        faceRecognition.saveImage(processedImage, withName: "selected", index: 0, inSubfolder: "debug", within: folderURL)

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            var matchFound = false

            for (index, fileURL) in contents.enumerated() {
                if let folderImage = UIImage(contentsOfFile: fileURL.path) {
                    faceRecognition.handleFaceRecognition(for: folderImage) { folderProcessedImage in
                        guard let folderProcessedImage = folderProcessedImage else {
                            print("Failed to process image from \(fileURL.lastPathComponent)")
                            return
                        }

                        // Save the processed image from the folder for debugging
                        faceRecognition.saveImage(folderProcessedImage, withName: "processed_\(index)", index: index, inSubfolder: "debug", within: folderURL)

                        // Check for a match
                        let isMatch = faceRecognition.isMatch(embedding1: processedImage, embedding2: folderProcessedImage, threshold: 0.8)
                        if isMatch {
                            matchFound = true
                            resultText = "Match found with \(fileURL.lastPathComponent)"
                            print("Match found with \(fileURL.lastPathComponent)")
                        } else {
                            print("No match with \(fileURL.lastPathComponent)")
                        }
                    }
                }
            }

            if !matchFound {
                resultText = "No match found in the folder"
            }
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

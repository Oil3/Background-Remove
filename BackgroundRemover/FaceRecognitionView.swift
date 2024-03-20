import SwiftUI

struct FaceRecognitionView: View {
    @State private var resultText = "Select two photos to compare"
    @State private var isImporterPresented = false
    @State private var selectedImages: [UIImage] = []

    var body: some View {
        VStack {
            Text(resultText)
                .padding()

            if selectedImages.count < 2 {
                Button("Select Photo") {
                    isImporterPresented = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            if let image = UIImage(contentsOfFile: url.path) {
                                selectedImages.append(image)
                                if selectedImages.count == 2 {
                                    compareFaces()
                                }
                            }
                        }
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
            } else {
                Button("Compare Faces") {
                    compareFaces()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }

    func compareFaces() {
        guard selectedImages.count == 2 else {
            resultText = "Please select two photos"
            return
        }

        let faceRecognition = FaceDetectandRec()

        faceRecognition.extractEmbedding(from: selectedImages[0]) { testEmbedding in
            guard let testEmbedding = testEmbedding else {
                resultText = "Failed to extract embedding from first photo"
                return
            }

            faceRecognition.extractEmbedding(from: selectedImages[1]) { validateEmbedding in
                guard let validateEmbedding = validateEmbedding else {
                    resultText = "Failed to extract embedding from second photo"
                    return
                }

                let match = faceRecognition.isMatch(embedding1: testEmbedding, embedding2: validateEmbedding)
                resultText = match ? "Match found" : "No match found"
            }
        }
    }
}

struct FaceRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        FaceRecognitionView()
    }
}

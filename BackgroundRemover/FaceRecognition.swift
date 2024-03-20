//
//  FaceRecognition.swift
//  BackgroundRemover
import UIKit
import CoreML
import Vision

class FaceRecognition {

    let model = try? facenet(configuration: MLModelConfiguration())

    func extractEmbedding(from image: UIImage, completion: @escaping (MLMultiArray?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let firstFace = results.first,
                  let faceImage = self.cropFace(from: image, faceObservation: firstFace) else {
                completion(nil)
                return
            }

            do {
                let input = try facenetInput(input__0With: faceImage)
                let output = try self.model?.prediction(input: input)
                completion(output?.output__0)
            } catch {
                print("Error extracting embedding: \(error)")
                completion(nil)
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    func cropFace(from image: UIImage, faceObservation: VNFaceObservation) -> CGImage? {
        let faceRect = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(image.size.width), Int(image.size.height))
        return image.cgImage?.cropping(to: faceRect)
    }

    func calculateDistance(_ embedding1: MLMultiArray, _ embedding2: MLMultiArray) -> Double {
        guard embedding1.count == embedding2.count else { return Double.infinity }
        var distance: Double = 0
        for i in 0..<embedding1.count {
            let diff = embedding1[i].doubleValue - embedding2[i].doubleValue
            distance += diff * diff
        }
        return sqrt(distance)
    }

    func isMatch(embedding1: MLMultiArray, embedding2: MLMultiArray, threshold: Double = 0.8) -> Bool {
        let distance = calculateDistance(embedding1, embedding2)
        return distance < threshold
    }
}

//// Usage
//let faceRecognition = FaceRecognition()
//
//let testPhoto = UIImage(named: "testPhoto")!
//let validatePhoto = UIImage(named: "validatePhoto")!
//
//faceRecognition.extractEmbedding(from: testPhoto) { testEmbedding in
//    guard let testEmbedding = testEmbedding else {
//        print("Failed to extract embedding from test photo")
//        return
//    }
//
//    faceRecognition.extractEmbedding(from: validatePhoto) { validateEmbedding in
//        guard let validateEmbedding = validateEmbedding else {
//            print("Failed to extract embedding from validate photo")
//            return
//        }
//
//        let match = faceRecognition.isMatch(embedding1: testEmbedding, embedding2: validateEmbedding)
//        print(match ? "Match found" : "No match found")
//    }
//}

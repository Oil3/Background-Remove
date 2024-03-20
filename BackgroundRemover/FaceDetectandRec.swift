//
//  FaceDetectandRec.swift
//  BackgroundRemover
//
//  Created by ZZS on 19/03/2024.
//

import UIKit
import CoreML
import Vision

class FaceDetectandRec {

    let model = try? facenet(configuration: MLModelConfiguration())

    func extractEmbedding(from image: UIImage, completion: @escaping (MLMultiArray?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let firstFace = results.first else {
                completion(nil)
                return
            }

            let faceImage = self.cropAndResizeFace(from: cgImage, faceObservation: firstFace)

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

    func cropAndResizeFace(from image: CGImage, faceObservation: VNFaceObservation) -> CGImage {
        let faceRect = VNImageRectForNormalizedRect(faceObservation.boundingBox, image.width, image.height)
        guard let croppedFace = image.cropping(to: faceRect) else { return image }
        guard let resizedFace = croppedFace.resize(to: CGSize(width: 160, height: 160)) else { return image }
        return resizedFace
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

extension CGImage {
    func resize(to size: CGSize) -> CGImage? {
        let bitsPerComponent = self.bitsPerComponent
        let bytesPerPixel = self.bitsPerPixel / 8
        let newBytesPerRow = Int(size.width) * bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: newBytesPerRow,
            space: self.colorSpace!,
            bitmapInfo: self.bitmapInfo.rawValue
        ) else {
            print("Failed to create CGContext for resizing image")
            return nil
        }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}


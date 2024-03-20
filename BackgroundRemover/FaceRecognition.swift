//
//  FaceRecognition.swift
import UIKit
import Vision
import CoreML

class FaceRecognition {
    let model = try? facenet(configuration: MLModelConfiguration())

    private func correctHorizon(for image: UIImage, using observation: VNHorizonObservation) -> UIImage {
        let transform = CGAffineTransform(rotationAngle: -observation.angle)
        return image.applying(transform)
    }

    private func cropAndAlignFace(from image: UIImage, for observation: VNFaceObservation) -> UIImage {
        let imageSize = image.size
        let faceRect = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
        
        guard let croppedImage = image.cropped(to: faceRect) else { return image }
        
        let resizedImage = resizeImage(croppedImage, to: CGSize(width: 160, height: 160))
        
        return resizedImage
    }

    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }

    func handleFaceRecognition(for image: UIImage, completion: @escaping (UIImage?) -> Void) {
        let horizonRequest = VNDetectHorizonRequest { [unowned self] request, error in
            guard error == nil, let results = request.results, let horizonObservation = results.first as? VNHorizonObservation else {
                completion(nil)
                return
            }
            let correctedImage = self.correctHorizon(for: image, using: horizonObservation)
            
            self.detectFace(in: correctedImage, completion: completion)
        }
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        try? handler.perform([horizonRequest])
    }

    private func detectFace(in image: UIImage, completion: @escaping (UIImage?) -> Void) {
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

            let faceImage = self.cropAndAlignFace(from: image, for: firstFace)
            self.extractEmbedding(from: faceImage, completion: { embedding in
                completion(faceImage)
            })
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    func extractEmbedding(from image: UIImage, completion: @escaping (MLMultiArray?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        do {
            let input = try facenetInput(input__0With: cgImage)
            let output = try self.model?.prediction(input: input)
            completion(output?.output__0)
        } catch {
            print("Error extracting embedding: \(error)")
            completion(nil)
        }
    }

    func saveImage(_ image: UIImage, withName baseName: String, index: Int, inSubfolder subfolderName: String, within folderURL: URL) {
        guard let data = image.pngData() else { return }

        let subfolderURL = folderURL.appendingPathComponent(subfolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true, attributes: nil)

        let fileName = "\(baseName)_\(index).png"
        let fileURL = subfolderURL.appendingPathComponent(fileName)

        try? data.write(to: fileURL)
        print("Saved aligned face image to: \(fileURL)")
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

extension UIImage {
    func applying(_ transform: CGAffineTransform) -> UIImage {
        let size = self.size.applying(transform)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!
        context.concatenate(transform)
        draw(at: CGPoint(x: 0, y: 0))
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resultImage
    }

    func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension Collection where Element == CGPoint {
    func average() -> CGPoint? {
        guard !isEmpty else { return nil }
        let sum = reduce(CGPoint.zero) { $0 + $1 }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }
}

    func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

//
//extension Collection where Element == CGPoint {
//    func average() -> CGPoint? {
//        guard !isEmpty else { return nil }
//        let sum = reduce(CGPoint.zero) { $0 + $1 }
//        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
//    }
//}

//func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
//    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
//}
//extension UIImage {
//    func applying(_ transform: CGAffineTransform) -> UIImage {
//        let size = self.size.applying(transform)
//        UIGraphicsBeginImageContext(size)
//        let context = UIGraphicsGetCurrentContext()!
//        context.concatenate(transform)
//        draw(at: CGPoint(x: 0, y: 0))
//        let resultImage = UIGraphicsGetImageFromCurrentImageContext()!
//        UIGraphicsEndImageContext()
//        return resultImage
//    }
//    func cropped(to rect: CGRect) -> UIImage? {
//        guard let cgImage = self.cgImage?.cropping(to: rect) else { return nil }
//        return UIImage(cgImage: cgImage)
//    }
//}
    

//
//  FaceRecognition.swift
import UIKit
import Vision
import CoreML

class FaceRecognition {
    private func correctHorizon(for image: UIImage, using observation: VNHorizonObservation) -> UIImage {
        let transform = CGAffineTransform(rotationAngle: -observation.angle)
        return image.applying(transform)
    }

    private func cropAndAlignFace(from image: UIImage, for observation: VNFaceObservation) -> UIImage {
        // Convert the normalized bounding box coordinates to the image's pixel dimensions
        let imageSize = image.size
        let faceRect = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
        
        // Crop the image to the face's bounding box
        guard let croppedImage = image.cropped(to: faceRect) else { return image }
        
        // Resize the cropped image to 160x160
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

    let model = try? facenet(configuration: MLModelConfiguration())

    
            // Proceed with Face Detection
// Main function to handle the face recognition process
    func handleFaceRecognition(for image: UIImage, completion: @escaping (UIImage?) -> Void) {
        // Start with Horizon Detection
        let horizonRequest = VNDetectHorizonRequest() { [unowned self] request, error in
            guard error == nil, let results = request.results, let horizonObservation = results.first as? VNHorizonObservation else {
                completion(nil)
                return
            }
            let correctedImage = self.correctHorizon(for: image, using: horizonObservation)
            
            // Proceed with Face Detection
            self.detectFace(in: correctedImage, completion: completion)
        }
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        try? handler.perform([horizonRequest])
    }
    
    // Detect face using VNDetectFaceRectanglesRequest with revision 3
private func detectFace(in image: UIImage, completion: @escaping (UIImage?) -> Void) {
    let faceDetectionRequest = VNDetectFaceRectanglesRequest { [unowned self] request, error in
        guard error == nil, let results = request.results, let faceObservation = results.first as? VNFaceObservation else {
            completion(nil)
            return
        }
        let faceImage = self.cropAndAlignFace(from: image, for: faceObservation)
        let resizedFaceImage = self.resizeImage(faceImage, to: CGSize(width: 160, height: 160))
        completion(resizedFaceImage)
    }

    faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3

    let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
    try? handler.perform([faceDetectionRequest])
}

    func extractEmbedding(from image: UIImage, completion: @escaping (MLMultiArray?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
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
    

    func cropFace(from image: UIImage, faceObservation: VNFaceObservation) -> CGImage? {
        let faceRect = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(image.size.width), Int(image.size.height))
        return image.cgImage?.cropping(to: faceRect)
    }
//maybe use     open func computeDistance(_ outDistance: UnsafeMutablePointer<Float>, to featurePrint:
    func calculateDistance(_ embedding1: MLMultiArray, _ embedding2: MLMultiArray) -> Double {
        guard embedding1.count == embedding2.count else { return Double.infinity }
        var distance: Double = 0
        for i in 0..<embedding1.count {
            let diff = embedding1[i].doubleValue - embedding2[i].doubleValue
            distance += diff * diff
        }
        return sqrt(distance)
    }

    func isMatch(embedding1: MLMultiArray, embedding2: MLMultiArray, threshold: Double =   0.8) -> Bool {
        let distance = calculateDistance(embedding1, embedding2)
        return distance < threshold
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


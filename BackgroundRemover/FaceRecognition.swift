//
//  FaceRecognition.swift
import UIKit
import Vision
import CoreML

class FaceRecognition {
    let model = try? facenet(configuration: MLModelConfiguration())

    // Align and extract embedding
    func alignAndExtractEmbedding(from image: UIImage, folderURL: URL, completion: @escaping (MLMultiArray?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let firstFace = results.first,
                  let landmarks = firstFace.landmarks,
                  let leftEye = landmarks.leftEye?.normalizedPoints.average(),
                  let rightEye = landmarks.rightEye?.normalizedPoints.average() else {
                completion(nil)
                return
            }

            let alignedImage = self.alignFace(image: image, leftEye: leftEye, rightEye: rightEye)
            let index = Int(Date().timeIntervalSince1970) // Use a timestamp as an index
            self.saveImage(alignedImage, withName: "aligned_face", index: index, inSubfolder: "AlignedFaces", within: folderURL)
            self.extractEmbedding(from: alignedImage, completion: completion)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
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

    func alignFace(image: UIImage, leftEye: CGPoint, rightEye: CGPoint) -> UIImage {
        let desiredLeftEyePosition = CGPoint(x: 0.35, y: 0.35)
        let desiredRightEyePosition = CGPoint(x: 0.65, y: 0.35)

        let angle = atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x)
        let distance = sqrt(pow(rightEye.x - leftEye.x, 2) + pow(rightEye.y - leftEye.y, 2))
        let desiredDistance = (desiredRightEyePosition.x - desiredLeftEyePosition.x)
        let scale = desiredDistance / distance

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: image.size.width / 2, y: image.size.height / 2)
        transform = transform.rotated(by: angle)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -image.size.width / 2, y: -image.size.height / 2)

        let rotatedImage = image.applying(transform)
        let croppedImage = rotatedImage.cropped(to: CGRect(x: (rotatedImage.size.width - 160) / 2, y: (rotatedImage.size.height - 160) / 2, width: 160, height: 160))!

        return croppedImage
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
    
//    func compareFaceWithFolder() {
//        guard let image = selectedImage, let folderURL = folderURL else {
//            resultText = "Please select a photo and a folder"
//            return
//        }
//
//        let faceRecognition = FaceRecognition()
//
//        faceRecognition.alignAndExtractEmbedding(from: image, folderURL: folderURL) { testEmbedding in
//            guard let testEmbedding = testEmbedding else {
//                resultText = "Failed to extract embedding from photo"
//                return
//            }
//
//            do {
//                let fileManager = FileManager.default
//                let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
//
//                for fileURL in contents {
//                    if let validateImage = UIImage(contentsOfFile: fileURL.path) {
//                        faceRecognition.alignAndExtractEmbedding(from: validateImage, folderURL: folderURL) { validateEmbedding in
//                            guard let validateEmbedding = validateEmbedding else {
//                                print("Failed to extract embedding from \(fileURL.lastPathComponent)")
//                                return
//                            }
//
//                            let match = faceRecognition.isMatch(embedding1: testEmbedding, embedding2: validateEmbedding)
//                            print(match ? "Match found with \(fileURL.lastPathComponent)" : "No match found with \(fileURL.lastPathComponent)")
//                        }
//                    }
//                }
//
//                resultText = "Comparison completed. Check console for results."
//            } catch {
//                print("Error reading folder contents: \(error)")
//                resultText = "Error reading folder contents"
//            }
//        }
//    }


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
    

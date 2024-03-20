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

            if let alignedImage = self.alignFace(image: image, leftPupil: leftEye, rightPupil: rightEye) {
                let index = Int(Date().timeIntervalSince1970) // Use a timestamp as an index
                self.saveImage(alignedImage, withName: "aligned_face", index: index, inSubfolder: "AlignedFaces", within: folderURL)
                self.extractEmbedding(from: alignedImage, completion: completion)
            } else {
        // If alignedImage is nil, do not execute the code and call the completion with nil
        completion(nil)
            }   
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

    func alignFace(image: UIImage, leftPupil: CGPoint, rightPupil: CGPoint) -> UIImage? {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Move the origin to the middle of the left and right pupils
        let eyeCenter = CGPoint(x: (leftPupil.x + rightPupil.x) / 2.0, y: (leftPupil.y + rightPupil.y) / 2.0)
        context.translateBy(x: eyeCenter.x * size.width, y: eyeCenter.y * size.height)

        // Rotate the context
        let angle = atan2(rightPupil.y - leftPupil.y, rightPupil.x - leftPupil.x)
        context.rotate(by: -angle)

        // Translate back
        context.translateBy(x: -eyeCenter.x * size.width, y: -eyeCenter.y * size.height)

        // Draw the image in the context
        image.draw(at: CGPoint(x: 0, y: 0))

        // Retrieve the transformed image from the context
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Crop the rotated image to the desired size centered on the eye center
        let cropRect = CGRect(
            x: (size.width - 160) / 2.0,
            y: (size.height - 160) / 2.0,
            width: 160,
            height: 160
        ).integral

        // Return the cropped image
        return rotatedImage?.cropped(to: cropRect)
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
    
//extension VNFaceLandmarks2D {
//    var leftPupil: CGPoint? {
//        return self.pupils?.normalizedPoints.first
//    }
//
//    var rightPupil: CGPoint? {
//        return self.pupils?.normalizedPoints.last
//    }
//}

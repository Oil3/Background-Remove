//
//  ViewController.swift

import UIKit
import Vision
import UniformTypeIdentifiers

class ViewController: UIViewController {
    var imageView: UIImageView!
    var resultImageView: UIImageView!
    var maskView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        maskView = UIImageView(frame: view.bounds)
        maskView.contentMode = .scaleAspectFit
        view.addSubview(maskView)
        
        resultImageView = UIImageView(frame: view.bounds)
        resultImageView.contentMode = .scaleAspectFit
        view.addSubview(resultImageView)
        
        let chooseFileButton = UIButton(frame: CGRect(x: 20, y: 50, width: 200, height: 50))
        chooseFileButton.setTitle("Choose File", for: .normal)
        chooseFileButton.backgroundColor = .blue
        chooseFileButton.addTarget(self, action: #selector(chooseFile), for: .touchUpInside)
        view.addSubview(chooseFileButton)
        
        let saveResultButton = UIButton(frame: CGRect(x: 20, y: 110, width: 200, height: 50))
        saveResultButton.setTitle("Save Result Image", for: .normal)
        saveResultButton.backgroundColor = .green
        saveResultButton.addTarget(self, action: #selector(saveResultImage), for: .touchUpInside)
        view.addSubview(saveResultButton)
        
        let manualMaskingButton = UIButton(frame: CGRect(x: 20, y: 170, width: 200, height: 50))
        manualMaskingButton.setTitle("Manual Masking", for: .normal)
        manualMaskingButton.backgroundColor = .orange
        manualMaskingButton.addTarget(self, action: #selector(manualMasking), for: .touchUpInside)
        view.addSubview(manualMaskingButton)
        
        let executeFolderButton = UIButton(frame: CGRect(x: 20, y: 230, width: 200, height: 50))
        executeFolderButton.setTitle("Execute Folder", for: .normal)
        executeFolderButton.backgroundColor = .red
        executeFolderButton.addTarget(self, action: #selector(executeFolder), for: .touchUpInside)
        view.addSubview(executeFolderButton)
    }
    
    @objc func chooseFile() {
        // Updated to use UTType for specifying file types
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    @objc func saveResultImage() {
        guard let image = resultImageView.image else { return }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func manualMasking() {
    }
    
    @objc func executeFolder() {
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving image: \(error.localizedDescription)")
        } else {
            print("Successfully saved image.")
        }
    }
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let image = UIImage(contentsOfFile: url.path)
        imageView.image = image
    }
}

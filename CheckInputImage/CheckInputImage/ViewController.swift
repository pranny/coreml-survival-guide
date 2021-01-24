import UIKit
import Vision

class ViewController: UIViewController {
  @IBOutlet var beforeImageView: UIImageView!
  @IBOutlet var afterImageView: UIImageView!
  @IBOutlet var cropScaleOptionButton: UIBarButtonItem!
  
  var imageCropAndScaleOption: VNImageCropAndScaleOption = .scaleFill
  var lastImage: UIImage?
  
  lazy var visionRequest: VNCoreMLRequest = {
    do {
      let visionModel = try VNCoreMLModel(for: Image2Image().model)
      
      let request = VNCoreMLRequest(model: visionModel, completionHandler: { request, error in
        if let results = request.results as? [VNPixelBufferObservation],
           let pixelBuffer = results.first?.pixelBuffer {
          let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
          let resultImage = UIImage(ciImage: ciImage)
          self.afterImageView.image = resultImage
          // Save the image here.
          DispatchQueue.global(qos: .background).async {
            self.showCVPixelBufferData(pixelBuffer: pixelBuffer)
          }
          
        }
      })
      
      request.imageCropAndScaleOption = imageCropAndScaleOption
      return request
    } catch {
      fatalError("Failed to create VNCoreMLModel: \(error)")
    }
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    updateCropScaleButton()
    
    lastImage = UIImage(named: "sunflower.jpg")
    predict(image: lastImage)
  }
  
  private func showCVPixelBufferData(pixelBuffer: CVPixelBuffer){
    
    let count = 2
    let stride = MemoryLayout<Int>.stride
    let byteCount = stride * count
    
    print(pixelBuffer)
    
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    for plane in 0...max(0, CVPixelBufferGetPlaneCount(pixelBuffer) - 1) {
      if let srcAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane) {
        let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        
        for h in 0..<CVPixelBufferGetHeightOfPlane(pixelBuffer, plane) {
          let srcPtr = srcAddr.advanced(by: h * srcBytesPerRow)
          let bufferPointer = UnsafeRawBufferPointer(start: srcPtr, count: byteCount)
          for (index, byte) in bufferPointer.enumerated() {
            print("plane: \(plane) HoP: \(h) byte at \(index): \(byte)")
          }
        }
      }
    }
  }
  
  
  func predict(image: UIImage?) {
    if let image = image, let ciImage = CIImage(image: image) {
      beforeImageView.image = image
      
      let orientation = CGImagePropertyOrientation(image.imageOrientation)
      
      // To see what happens when the image orientation is wrong,
      // choose a fixed orientation value here:
      //let orientation = CGImagePropertyOrientation.up
      
      let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.visionRequest])
      } catch {
        print("Failed to perform prediction: \(error)")
      }
    }
  }
  
  @IBAction func choosePhotoFromLibrary(_ sender: Any) {
    presentPhotoPicker(sourceType: .photoLibrary)
  }
  
  func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = sourceType
    present(picker, animated: true)
  }
  
  @IBAction func changeCropScaleOption(_ sender: Any) {
    switch imageCropAndScaleOption {
    case .centerCrop:
      imageCropAndScaleOption = .scaleFit
    case .scaleFit:
      imageCropAndScaleOption = .scaleFill
    case .scaleFill:
      imageCropAndScaleOption = .centerCrop
    @unknown default:
      fatalError("eek!")
    }
    
    updateCropScaleButton()
    
    visionRequest.imageCropAndScaleOption = imageCropAndScaleOption
    predict(image: lastImage)
  }
  
  func updateCropScaleButton() {
    switch imageCropAndScaleOption {
    case .centerCrop:
      cropScaleOptionButton.title = "centerCrop"
    case .scaleFit:
      cropScaleOptionButton.title = "scaleFit"
    case .scaleFill:
      cropScaleOptionButton.title = "scaleFill"
    @unknown default:
      fatalError("eek!")
    }
  }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    
    lastImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
    predict(image: lastImage)
  }
}

extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    default: self = .up
    }
  }
}

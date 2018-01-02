//
//  ViewController.swift
//  QR-Code-Reader
//
//  Created by 黃健偉 on 2017/12/29.
//  Copyright © 2017年 黃健偉. All rights reserved.
//  https://www.youtube.com/watch?v=FypyjizK_ww
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var videoPreview: UIView!
    
    var stringURL = String()
    var stringText = String()
    
    // Added to support different barcodes
    let supportedBarCodes = [AVMetadataObject.ObjectType.qr, AVMetadataObject.ObjectType.code128, AVMetadataObject.ObjectType.code39, AVMetadataObject.ObjectType.code93, AVMetadataObject.ObjectType.upce, AVMetadataObject.ObjectType.pdf417, AVMetadataObject.ObjectType.ean13, AVMetadataObject.ObjectType.aztec]

    enum error: Error {
        case noCameraAvailable
        case videoInputInitFail
    }
    
    var lastZoomFactor: CGFloat = 1.0
    var myButton = UIButton(type: .system)

    @IBAction func pinch(_ pinch: UIPinchGestureRecognizer) {
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 5.0
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("No Camera.")
            return
        }
        
        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), avCaptureDevice.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try avCaptureDevice.lockForConfiguration()
                defer { avCaptureDevice.unlockForConfiguration() }
                avCaptureDevice.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began:
            fallthrough
        case .changed:
            update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

/*        let fullScreenSize = UIScreen.main.bounds.size

        myButton.frame = CGRect(
            x: 0, y: 0, width: 100, height: 30)
        myButton.setTitle("Try", for: .normal)
        myButton.backgroundColor = UIColor.init(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        myButton.addTarget(nil, action: #selector(ViewController.simpleHint), for: .touchUpInside)
        myButton.center = CGPoint( x: fullScreenSize.width * 0.5, y: fullScreenSize.height * 0.15)
*/
        do {
            try scanQRCode()
        } catch {
            print("Failed to scan the QR/Bar code.")
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func scanQRCode() throws {
        let avCaptureSession = AVCaptureSession()
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("No Camera.")
            throw error.noCameraAvailable
        }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else {
            print("Fail to Init Camera.")
            throw error.videoInputInitFail
        }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        avCaptureSession.addInput(avCaptureInput)
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = supportedBarCodes//[AVMetadataObject.ObjectType.qr]
        
        let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = videoPreview.bounds
        self.videoPreview.layer.addSublayer(avCaptureVideoPreviewLayer)
        avCaptureSession.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            if supportedBarCodes.contains(machineReadableCode.type) {
                if verifyUrl(str: machineReadableCode.stringValue!)  {
                    stringURL = machineReadableCode.stringValue!
                    performSegue(withIdentifier: "openLink", sender: self)
                } else {
                    stringText = machineReadableCode.stringValue!
                    print(stringText)
                    simpleHint(message: stringText)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "openLink" {
            let destination = segue.destination as! WebViewController
            destination.url = URL(string: stringURL)
        }
    }
    
    private func verifyUrl(str:String) -> Bool {
        if let url = NSURL(string: str) {
            return UIApplication.shared.canOpenURL(url as URL)
        }
        return false
    }

    func simpleHint(message: String) {
        let alert = UIAlertController(title: "Scan Result", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "確認", style: .default)
        alert.addAction(okAction)
        self.present( alert, animated: true, completion: nil)
    }
}


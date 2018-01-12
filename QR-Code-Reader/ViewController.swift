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
    var cameraDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?

    
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
        do {
            try scanQRCode()
        } catch {
            print("Failed to scan the QR/Bar code.")
        }
        
        //debig for big5 convert to utf8
        /*
        //let code = "､E､ｭｵLｹ]"
        let code = "ｶﾇｲﾎ"
        let big5encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(UInt(CFStringEncodings.big5.rawValue))))
        let code2 = String(data: code.data(using: .nonLossyASCII)!, encoding: big5encoding)

        print("Big5 encoded String: " + code2!)
         */
       

        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let screenSize = videoPreview.bounds.size
        if let touchPoint = touches.first {
            let x = touchPoint.location(in: videoPreview).y / screenSize.height
            let y = 1.0 - touchPoint.location(in: videoPreview).x / screenSize.width
            let focusPoint = CGPoint(x: x, y: y)
            
            if let device = cameraDevice {
                do {
                    try device.lockForConfiguration()
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .continuousAutoFocus
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .continuousAutoExposure
                    device.unlockForConfiguration()
                }
                catch {
                    // just ignore
                }
            }
        }
    }

    func scanQRCode() throws {
        let avCaptureSession = AVCaptureSession()
        previewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)

        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("No Camera.")
            throw error.noCameraAvailable
        }
        cameraDevice = avCaptureDevice
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else {
            print("Fail to Init Camera.")
            throw error.videoInputInitFail
        }
        
        //try to enable auto focus
        if avCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
            try! avCaptureDevice.lockForConfiguration()
            avCaptureDevice.focusMode = .continuousAutoFocus
            avCaptureDevice.unlockForConfiguration()
        }

        //try to enable auto exposure
        if avCaptureDevice.isExposureModeSupported(.autoExpose) {
            try! avCaptureDevice.lockForConfiguration()
            avCaptureDevice.exposureMode = .continuousAutoExposure
            avCaptureDevice.unlockForConfiguration()
        }

        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        avCaptureSession.addInput(avCaptureInput)
        avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = supportedBarCodes
        
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
                    if invoiceVerify(qrCodeText: stringText) {
                        invoiceParse(qrCodeText: stringText)
                        let sortedDict = invoiceDict.sorted { $0.0 < $1.0 }
                        var invoiceStr: String = ""
                        for (item, value) in sortedDict {
                            print("\(item): \(value)")
                            invoiceStr += "\(item): \(value)\n"
                        }
                        for item in itemDictArray {
                            print(item)
                            invoiceStr += "\(item)\n"
                        }
                        simpleHint(title: "中華民國電子發票，第一頁", message: invoiceStr)
                    } else if invoice2Verify(qrCodeText: stringText) {
                            invoice2Parse(qrCodeText: stringText)
                            var invoiceStr: String = ""
                            for item in itemDictArray {
                                print(item)
                                invoiceStr += "\(item)\n"
                            }
                            simpleHint(title: "中華民國電子發票，第二頁", message: invoiceStr)
                    } else {
                        print(stringText)
                        simpleHint(title: "掃描結果", message: stringText)
                    }
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
    
    func simpleHint(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .cancel) { (action) in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(OKAction)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.left
        
        let messageText = NSMutableAttributedString(
            string: message,
            attributes: [
                NSAttributedStringKey.paragraphStyle: paragraphStyle,
                NSAttributedStringKey.font: UIFont.systemFont(ofSize: 13.0)
            ]
        )
        
        alert.setValue(messageText, forKey: "attributedMessage")
        self.present(alert, animated: true, completion: nil)

    }
    
    //for Taiwan E-invoice
    //(一) 左方二維條碼記載事項：
    //  1. 發票字軌 (10 位)：記錄發票完整十碼號碼。
    //  2. 發票開立日期 (7 位)：記錄發票三碼民國年、二碼月份、二碼日期。
    //  3. 隨機碼 (4 位)：記錄發票上隨機碼四碼。
    //  4. 銷售額 (8 位)：記錄發票上未稅之金額總計八碼，將金額轉換以十六進位方式記載。若營業人銷售系統無法順利將稅項分離計算，則以00000000 記載。
    //  5. 總計額 (8 位)：記錄發票上含稅總金額總計八碼，將金額轉換以十六進位方式記載。
    //  6. 買方統一編號 (8 位)：記錄發票上買受人統一編號，若買受人為一般消費者則以 00000000 記載。
    //  7. 賣方統一編號 (8 位)：記錄發票上賣方統一編號。
    //  8. 加密驗證資訊 (24 位)：將發票字軌十碼及隨機碼四碼以字串方式合併後使用 AES 加密並採用 Base64 編碼轉換。
    //
    //    以上欄位總計 77 碼。下述資訊為接續以上資訊繼續延伸記錄，且每個欄位前皆以間隔符號“:”(冒號)區隔各記載事項，若左方二維條碼不敷記載，則繼續記載於右方二維條碼。
    //
    //  9. 營業人自行使用區 (10 位)：提供營業人自行放置所需資訊，若不使用則以 10 個“*”符號呈現。
    //  10.二維條碼記載完整品目筆數：記錄左右兩個二維條碼記載消費品目筆數，以十進位方式記載。
    //  11.該張發票交易品目總筆數：記錄該張發票記載總消費品目筆數，以十進位方式記載。
    //  12.中文編碼參數 (1 位)：定義後續資訊的編碼規格，若以：
    //    (1) Big5 編碼，則此值為 0
    //    (2) UTF-8 編碼，則此值為 1
    //    (3) Base64 編碼，則此值為 2
    //    編碼資訊包含從第一個品名前的間隔符號後的所有資訊(品名、數量、單價、補充說明)，且不包含右方二維條碼前兩碼起始符號。
    //    未來視辦理狀況，將僅開放 UTF-8 編碼規格。
    //
    //    接續之品名、數量、單價為重覆循環呈現至所有品目記載完成，若品目筆數過多以致左右兩個二維條碼無法全部記載，則以記載最多可放置於左右兩個二維條碼內容之品目為原則。
    //
    //  13.品名：商品名稱，請避免使用間隔符號“:”(冒號)於品名。
    //  14.數量：商品數量，在中文編碼前，以十進位方式記載。
    //  15.單價：商品單價，在中文編碼前，以十進位方式記載。
    //  16.補充說明：非必要使用資訊，營業人可自行選擇是否運用，於左右兩個二維條碼已記載所有品目資訊後，始可使用此空間。長度不限。
    //
    //(二) 右方二維條碼記載事項：
    //  1. 右方二維條碼前兩碼起始符號 (2 位)：首 2 碼固定以“**”為起始符號，供未來讀取端辨識左方或右方二維條碼之用。
    //  2. 接續左方二維條碼不敷記載之中文編碼後資訊
    
    var invoiceDict: [String: String] = [:]
    var itemDictArray: [String] = []
    
    let textBaseDict: [String: String] = [
        "0": "Big5",
        "1": "UTF-8",
        "2": "Base64",
        ]
    
    func invoiceVerify(qrCodeText: String) -> Bool {
        if qrCodeText.count < 78 {
            return false
        }
        //發票字軌
        print(qrCodeText.substring(from: 0, to: 2))
        let check1 = qrCodeText.substring(from: 0, to: 2).isLetterset()
        print(check1)
        print(qrCodeText.substring(from: 2, to: 10))
        let check2 = qrCodeText.substring(from: 2, to: 10).isNumber()
        print(check2)

        //開立日期
        print(qrCodeText.substring(from: 10, to: 13))
        let check3 = qrCodeText.substring(from: 10, to: 13).isNumber()
        print(check3)

        print(qrCodeText.substring(from: 13, to: 15))
        let check4 = (qrCodeText.substring(from: 13, to: 15).isNumber()) && (Int(qrCodeText.substring(from: 13, to: 15))! <= 12)
        print(check4)

        print(qrCodeText.substring(from: 15, to: 17))
        let check5 = qrCodeText.substring(from: 15, to: 17).isNumber() && (Int(qrCodeText.substring(from: 15, to: 17))! <= 31)
        print(check5)

        //主要項目77碼結束，之後的項目以":"(冒號)區隔各記載事項
        print(qrCodeText.substring(from: 77, to: 78))
        let check6 = qrCodeText.substring(from: 77, to: 78).isColon()
        print(check6)

        return check1 && check2 && check3 && check4 && check5 && check6
    }

    func invoice2Verify(qrCodeText: String) -> Bool {
        //起始兩個"**"
        print(qrCodeText.substring(from: 0, to: 2))
        
        return qrCodeText.substring(from: 0, to: 2).isStar()
    }

    //big5 - "YH625882881061129065500000381000003ae0000000046038423pSPPr4Z2OFqheeh9OP47YA==:**********:1:1:0:､E､ｭｵLｹ]:35.00:26.90"
    //utf8 - "ZH0872526710701013550000000000000004d0000000028997723uaxq26SZudKCJOGnIG/9SA==:**********:2:2:1:味味一品原汁珍味牛肉麵185g:1:46:"
    func invoiceParse(qrCodeText: String) {
        invoiceDict["  01.發票字軌"] = qrCodeText.substring(from: 0, to: 2) + "-" + qrCodeText.substring(from: 2, to: 10) //10
        invoiceDict["  02.開立日期"] = qrCodeText.substring(from: 10, to: 13) + "年" + qrCodeText.substring(from: 13, to: 15) + "月" + qrCodeText.substring(from: 15, to: 17) + "日" //7
        invoiceDict["  03.隨機碼"] = qrCodeText.substring(from: 17, to: 21) //4
        invoiceDict["  04.銷售額"] = String(describing: Int(qrCodeText.substring(from: 21, to: 29), radix: 16)!) //8
        invoiceDict["  05.總計額"] = String(describing: Int(qrCodeText.substring(from: 29, to: 37), radix: 16)!) //8
        invoiceDict["  06.買方統一編號"] = qrCodeText.substring(from: 37, to: 45) //8
        invoiceDict["  07.賣方統一編號"] = qrCodeText.substring(from: 45, to: 53) //8
        invoiceDict["  08.加密驗證資訊"] = qrCodeText.substring(from: 53, to: 77) //24
        //以下欄位沒固定大小，以：區隔
        let itemsString: String = qrCodeText.substring(from: 78)
        var itemArray = itemsString.components(separatedBy: ":")
        invoiceDict["  09.營業人自行使用區"] = itemArray[0] //10
        invoiceDict["  10.二維條碼記載完整品目筆數"] = itemArray[1]
        invoiceDict["  11.該張發票交易品目總筆數"] = itemArray[2]
        invoiceDict["  12.中文編碼"] = textBaseDict[itemArray[3]] //1
        itemDictArray = []
        //以下為產品明細
        if itemArray.count > 5 {
            let index = (itemArray.count-4)/3
            for idx in 1...index {
                itemDictArray.append("  產品明細" + String(idx) + ": ")
                //need to check Big5 & Base64 case
                if itemArray[3] == "0" { // Chinese Big5
                    itemDictArray.append("    a.品名: " + itemArray[idx*3+1])
                } else if itemArray[3] == "1" { // UTF-8
                    itemDictArray.append("    a.品名: " + itemArray[idx*3+1])
                } else if itemArray[3] == "2" { //Base64
                    itemDictArray.append("    a.品名: " + itemArray[idx*3+1])
                }
                itemDictArray.append("    b.數量: " + itemArray[idx*3+2])
                itemDictArray.append("    c.單價: " + itemArray[idx*3+3])
                //itemDictArray.append("    d.補充說明: " + itemArray[idx*4+3])
            }
        }
        return
    }
    //"**泰安洗選蛋10入:1:31"
    //"**麻婆豆腐燴飯:1:60:LCxKT點數:4:0"
    func invoice2Parse(qrCodeText: String) {
        var index: Int = 0
        if qrCodeText.count > 2 {
            if Array(qrCodeText)[2] == ":" {
                index = 3
            } else {
                index = 2
            }
            
        }
        let itemsString: String = qrCodeText.substring(from: index)
        let itemArray = itemsString.components(separatedBy: ":")
        print(itemArray)
        itemDictArray = []
        //以下為產品明細
        if itemArray != [""] {
            let index = (itemArray.count)/3
            for idx in 0..<index {
                //need to check Big5 & Base64 case
                itemDictArray.append("  產品明細" + String(idx+1) + ": ")
                itemDictArray.append("    a.品名: " + itemArray[idx*3+0])
                itemDictArray.append("    b.數量: " + itemArray[idx*3+1])
                itemDictArray.append("    c.單價: " + itemArray[idx*3+2])
            }
        }
        return
    }
}

struct CharLib {
    static var numset = Set("0123456789")
    static var letterset = Set("abcdefghijklmnopqrstuvwxyz")
    static var colon = Set(":")
    static var star = Set("*")

}

extension String {
    //substring(range)
    func substring(from: Int, to: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: to - from)
        return String(self[start ..< end])
    }
    func substring(range: NSRange) -> String {
        return substring(from: range.lowerBound, to: range.upperBound)
    }
    
    //substring(startIndex ... to)
    func substring(to: Int) -> String {
        let end = index(startIndex, offsetBy: to)
        return String(self[..<end])
    }
    func substring(to: NSRange) -> String {
        return substring(to: to.upperBound)
    }
    
    //substring(from ... endIndex)
    func substring(from: Int) -> String {
        let start = index(startIndex, offsetBy: from)
        return String(self[start...])
    }
    func substring(from: NSRange) -> String {
        return substring(from: from.lowerBound)
    }
    
    //determines if string is a number (0-9)
    func isNumber() -> Bool {
        let charset = Set(self)
        return charset.isSubset(of: CharLib.numset)
    }
    
    //determines if string is a letterset (a-z)
    func isLetterset() -> Bool {
        let charset = Set(self.lowercased())
        return charset.isSubset(of: CharLib.letterset)
    }
    
    //determines if string is a colon (:)
    func isColon() -> Bool {
        let charset = Set(self)
        return charset.isSubset(of: CharLib.colon)
    }
    
    //determines if string is a star (*)
    func isStar() -> Bool {
        let charset = Set(self)
        return charset.isSubset(of: CharLib.star)
    }
}



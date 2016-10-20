//
//  ViewController.swift
//  HLCNNDigitalRecognition
//
//  Created by Denis Svinarchuk on 20/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var digitView: DigitView!
    @IBOutlet weak var digitLabel: UILabel!
    
    var runningNet = MNISTDeepCNN()

    func detectDigit(context: CGContext) {
        
        runningNet.updateSource(bytes: context.data!)
        
        let digit = runningNet.forward()
        var label = "?"
        
        if digit < UInt.max {
            label = "\(digit)"
        }
        
        digitLabel.text = label
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        digitView.backgroundColor = UIColor.white
        digitView.layer.borderWidth = 1
        digitView.layer.borderColor = UIColor.gray.cgColor
        digitView.layer.cornerRadius = 5
    
        
        digitView.complete = { (context)  in
            if let context = context {
                self.detectDigit(context: context)
            }
        }
    }

}


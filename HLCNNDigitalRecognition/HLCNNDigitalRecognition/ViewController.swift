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
    
    var runningNet = MNIST_Deep_ConvNN()

    func detectDigit(context: CGContext) {
        
        runningNet.updateSource(bytes: context.data!)
        
        // run the network forward pass
        let digit = runningNet.forward()
        var label = "?"
        
        // show the prediction
        if digit < UInt.max {
            label = "\(digit)"
        }
        
        digitLabel.text = label
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        digitView.complete = { (context)  in
            if let context = context {
                self.detectDigit(context: context)
            }
        }
    }

}

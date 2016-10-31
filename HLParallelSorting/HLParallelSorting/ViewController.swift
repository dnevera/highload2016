//
//  ViewController.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 08/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import UIKit
import Accelerate
import simd

let runRandom = false

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if runRandom {
            testRandomProgression()
        }
        else {
            testSortProgression()
        }
    }
    
    override func didReceiveMemoryWarning() {
        print("Шеф! Усе пропало!")
    }
}


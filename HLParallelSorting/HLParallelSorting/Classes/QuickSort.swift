//
//  QuickSort.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation

func quicksort<T: Comparable>(_ a: [T]) -> [T] {
    guard a.count > 1 else { return a }
    let x = a[a.count/2]
    let l = a.filter { $0 < x }
    let r = a.filter { $0 > x }
    return quicksort(l) + a.filter { $0 == x } + quicksort(r)
}

//
//  QuickSort.swift
//  HLParallelSorting
//
//  Created by Denis Svinarchuk on 12/10/16.
//  Copyright © 2016 Moscow Exchange. All rights reserved.
//

import Foundation

/**
 * Классическая быстрая сортирвка на CPU
 */
func quicksort<T: Comparable>(_ a: [T]) -> [T] {
    guard a.count > 1 else { return a }
    let x = a[a.count/2]
    return quicksort(a.filter { $0 < x }) + a.filter { $0 == x } + quicksort( a.filter { $0 > x })
}

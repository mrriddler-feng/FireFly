//
//  Extensions.swift
//  FireFly
//
//  Created by 峰 on 2025/3/18.
//

extension SIMD4 {
    /// Retrieves first 3 elements
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

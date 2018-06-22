//
//  DispatchTime+Demo.swift
//  Demo
//
//  Created by Lacy Rhoades on 6/22/18.
//  Copyright © 2018 Lacy Rhoades. All rights reserved.
//

import Foundation

extension DispatchTime {
    static func seconds(_ secs: TimeInterval) -> DispatchTime {
        return DispatchTime.now() + secs
    }
}

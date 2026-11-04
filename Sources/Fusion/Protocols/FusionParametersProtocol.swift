//
//  FusionParametersProtocol.swift
//  Fusion
//
//  Created by Vinzenz Weist on 26.11.25.
//  Copyright © 2025 Vinzenz Weist. All rights reserved.
//

import Foundation
import Network

public protocol FusionParametersProtocol: Sendable {
    /// The underlying `NWParameters`
    var parameters: NWParameters { get }
    
    /// The `TaskPriority` for the connection
    var priority: TaskPriority { get }
    
    /// The `FusionCeiling` to limit frame size
    var ceiling: FusionCeiling { get }
    
    /// The `FusionLeverage` to limit data slices
    var leverage: FusionLeverage { get }
    
    /// The configurable `FusionParameters`
    ///
    /// - Parameters:
    ///   - parameters: the underlying `NWParameters`
    ///   - priority: the `TaskPriority` for the connection
    ///   - ceiling: the `FusionCeiling` to limit frame size
    ///   - leverage: the `FusionLeverage` to limit the size of a single read
    init(with parameters: NWParameters, priority: TaskPriority, ceiling: FusionCeiling, leverage: FusionLeverage)
}

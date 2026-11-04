//
//  FusionFramer.swift
//  Fusion
//
//  Created by Vinzenz Weist on 07.06.21.
//  Copyright © 2021 Vinzenz Weist. All rights reserved.
//

import Foundation

struct FusionFramer: FusionFramerProtocol, Sendable {
    private var buffer: Data = .init()
    
    /// Clear the internal `Data` message buffer
    ///
    /// Current message buffer will be cleared
    mutating func clear() -> Void { self.buffer.removeAll() }
    
    /// Create a `FusionMessage` conform frame
    ///
    /// - Parameters:
    ///   - message: generic type which conforms to `FusionMessage`
    ///   - ceiling: the outbound frame size limit from `FusionCeiling`
    /// - Returns: the message frame as `Data`
    static func create<Message: FusionFrame>(message: Message, ceiling: FusionCeiling = .unlimited) throws(FusionFramerError) -> Data {
        guard message.size <= FusionStatic.total.rawValue, message.size <= ceiling.rawValue else { throw .outbound }
        var frame = Data(capacity: Int(message.size)); frame.append(message.opcode); frame.append(UInt32(message.size).endian); frame.append(message.encode)
        return frame
    }
    
    /// Parse a `FusionMessage` conform to the `FusionFrame`
    ///
    /// - Parameters:
    ///   - slice: the `Data` slice of the `FusionMessage` conform to the `FusionFrame`
    ///   - ceiling: the inbound buffer size limit from `FusionCeiling`
    /// - Returns: a collection of `FusionMessage`s conform to the `FusionFrame` and `Error`
    mutating func parse(slice: Data, ceiling: FusionCeiling = .unlimited) throws(FusionFramerError) -> [FusionFrame] {
        var messages: [FusionFrame] = [], index = append(slice: slice)
        guard buffer.count <= FusionStatic.total.rawValue, buffer.count <= ceiling.rawValue else { throw .inbound }
        while let length = try buffer.length(at: index) {
            guard length <= ceiling.rawValue else { throw .inbound }
            guard buffer.endIndex - index >= length else { break }
            messages.append(try extract(at: index, length: length)); index += Int(length)
        }
        compact(from: index); return messages
    }
}

// MARK: - Private API Extension -

private extension FusionFramer {
    /// Append a slice to the message buffer
    ///
    /// An empty message buffer adopts the slice without copying
    ///
    /// - Parameter slice: the received `Data`
    /// - Returns: the start index of the message buffer
    private mutating func append(slice: Data) -> Data.Index {
        if buffer.isEmpty { buffer = slice } else { buffer.append(slice) }
        return buffer.startIndex
    }
    
    /// Extract a single `FusionFrame` from the message buffer
    ///
    /// - Parameters:
    ///   - index: the start index of the frame
    ///   - length: the total frame length
    /// - Returns: the decoded `FusionFrame`
    private func extract(at index: Data.Index, length: UInt32) throws(FusionFramerError) -> FusionFrame {
        guard buffer.indices.contains(index) else { throw .opcode }
        guard let message = buffer.decode(with: buffer[index], at: index, from: length) else { throw .decode }
        return message
    }
    
    /// Remove parsed bytes and reserve capacity for the pending frame
    ///
    /// Avoids repeated reallocations while large frames are received in many slices
    ///
    /// - Parameter index: the start index of the unparsed bytes
    private mutating func compact(from index: Data.Index) -> Void {
        if index != buffer.startIndex { buffer = index < buffer.endIndex ? Data(buffer[index...]) : .init() }
        guard let length = try? buffer.length(at: buffer.startIndex), length > buffer.count else { return }
        buffer.reserveCapacity(min(Int(length), Int(FusionCeiling.extreme.rawValue)))
    }
}

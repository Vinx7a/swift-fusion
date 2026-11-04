//
//  Extensions.swift
//  Fusion
//
//  Created by Vinzenz Weist on 07.06.21.
//  Copyright © 2021 Vinzenz Weist. All rights reserved.
//

import Foundation
import Network

// MARK: - Network -

extension NetworkConnection<TCP> {
    /// Validate connection establishment
    ///
    /// Checks if connection was established otherwise throws error
    ///
    /// - Parameter timeout: the establishment timeout as `Duration`
    func established(timeout: Duration = .timeout) async throws -> Void {
        let clock = ContinuousClock(), deadline = clock.now + timeout
        while true {
            switch state { case .ready: return case .failed(let error), .waiting(let error): throw error case .cancelled: throw CancellationError() default: break }
            guard clock.now < deadline else { throw FusionConnectionError.timeout }; try await clock.sleep(for: .interval)
        }
    }
}

extension TCP {
    /// Create the `TCP` protocol from `NWParameters`
    ///
    /// The protocol stack builder replaces the transport options of the initial parameters,
    /// the configured `NWProtocolTCP.Options` are applied to the `TCP` protocol instead
    ///
    /// - Parameter parameters: the `NWParameters` containing `NWProtocolTCP.Options`
    init(from parameters: NWParameters) {
        guard let options = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options else { self.init(); return }
        self = TCP().flags(from: options).timeouts(from: options)
    }
    
    /// Apply the flags of `NWProtocolTCP.Options`
    ///
    /// - Parameter options: the `NWProtocolTCP.Options`
    /// - Returns: the configured `TCP`
    private func flags(from options: NWProtocolTCP.Options) -> TCP {
        let tcp = self.noDelay(options.noDelay).noPush(options.noPush).noOptions(options.noOptions).retransmitFinDrop(options.retransmitFinDrop)
        return tcp.ackStretchingDisabled(options.disableAckStretching).fastOpenAllowed(options.enableFastOpen).ecnDisabled(options.disableECN)
    }
    
    /// Apply the timeouts, keepalive and segment size of `NWProtocolTCP.Options`
    ///
    /// - Parameter options: the `NWProtocolTCP.Options`
    /// - Returns: the configured `TCP`
    private func timeouts(from options: NWProtocolTCP.Options) -> TCP {
        var tcp = self
        if options.enableKeepalive { tcp = tcp.keepalive(idleTimeInSeconds: UInt32(options.keepaliveIdle), count: UInt32(options.keepaliveCount), intervalInSeconds: UInt32(options.keepaliveInterval)) }
        if options.maximumSegmentSize > .zero { tcp = tcp.maximumSegmentSize(UInt32(options.maximumSegmentSize)) }
        if options.connectionTimeout > .zero { tcp = tcp.connectionTimeout(UInt32(options.connectionTimeout)) }
        if options.persistTimeout > .zero { tcp = tcp.persistTimeout(UInt32(options.persistTimeout)) }
        if options.connectionDropTime > .zero { tcp = tcp.retransmitConnectionDropTime(UInt32(options.connectionDropTime)) }
        return tcp
    }
}

// MARK: - Duration -

extension Duration {
    /// Interval time
    static var interval: Self { .milliseconds(5) }
    
    /// Timeout deadline
    static var timeout: Self { .seconds(4.0) }
}

// MARK: - UInt32 -

extension UInt32 {
    /// Convert integer to data with bigEndian
    var endian: Data { withUnsafeBytes(of: self.bigEndian) { Data($0) } }
    
    /// The fusion frame payload range
    var payload: Range<Int>? {
        guard self >= FusionStatic.header.rawValue else { return nil }
        return Int(FusionStatic.header.rawValue)..<Int(self)
    }
}

// MARK: - Fusion Framer Data -

extension Data {
    /// Extract the frame length from the header
    ///
    /// - Parameter index: the start index of the frame
    /// - Returns: the extracted length as `UInt32`
    func length(at index: Index) throws(FusionFramerError) -> UInt32? {
        guard self.endIndex - index >= FusionStatic.header.rawValue else { return nil }
        let lower = index + Int(FusionStatic.opcode.rawValue), upper = index + Int(FusionStatic.header.rawValue)
        let length = UInt32(bigEndian: self[lower..<upper].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        if length != .zero { return length } else { throw FusionFramerError.invalid }
    }
    
    /// Decode a `FusionMessage` as `FusionFrame`
    ///
    /// - Parameters:
    ///   - opcode: the `FusionOpcode`
    ///   - index: the start index of the frame
    ///   - length: the length of the frame
    /// - Returns: the `FusionMessage`
    func decode(with opcode: UInt8, at index: Index, from length: UInt32) -> FusionFrame? {
        guard let range = length.payload else { return nil }
        return FusionOpcode(rawValue: opcode)?.rawType.decode(from: Data(self[(index + range.lowerBound)..<(index + range.upperBound)]))
    }
}

//
//  FusionTransport.swift
//  Fusion
//
//  Created by Vinzenz Weist on 07.06.21.
//  Copyright © 2021 Vinzenz Weist. All rights reserved.
//

import Foundation
import Network

public actor FusionConnection: FusionConnectionProtocol, Sendable {
    private let (stream, continuation) = FusionStream.makeStream()
    private let parameters: FusionParameters
    
    private let endpoint: NWEndpoint
    private var framer = FusionFramer()
    private var connection: NetworkConnection<TCP>?
    private var process: Task<Void, Never>?
    
    /// The `FusionConnection` is a custom network connector that implements the **Fusion Framing Protocol (FFP)**.
    /// It is built on top of the standard `Network` framework library. This fast and lightweight custom framing protocol
    /// enables high-speed data transmission and provides fine-grained control over network flow.
    ///
    /// - Parameters:
    ///   - host: the connected `NWEndpoint`
    ///   - parameters: network framework `FusionParameters`
    public init(using endpoint: NWEndpoint, parameters: FusionParameters = .init()) {
        self.endpoint = endpoint
        self.parameters = parameters
    }
    
    /// Start to establish a new connection
    ///
    /// Set config for `NetworkConnection` and establish new connection
    public func start() async throws -> Void {
        guard connection == nil, process == nil else { throw FusionConnectionError.established }
        let connection = NetworkConnection(to: endpoint, using: .parameters(initialParameters: parameters.parameters) { TCP(from: parameters.parameters) })
        self.connection = connection; process = Task(priority: parameters.priority) { [weak self] in await self?.processing() }
        do { try await connection.established() } catch { await cancel(); throw error }
    }
    
    /// Cancel the current connection
    ///
    /// Stops the receiver and cancels the current connection
    public func cancel() async -> Void {
        process?.cancel(); connection = nil; continuation.finish()
    }
    
    /// Send messages over the established connection
    ///
    /// The frame is send at once, concurrent sends can not interleave
    ///
    /// - Parameter message: the message conform to `FusionMessage`
    public func send<Message: FusionMessage>(message: Message) async throws -> Void {
        guard let connection, let message = message as? FusionFrame else { return }
        let frame = try FusionFramer.create(message: message, ceiling: parameters.ceiling)
        try await connection.send(frame); continuation.yield(.init(report: .init(outbound: frame.count)))
    }
    
    /// Receive messages over the established connection
    ///
    /// - Returns: the iteratable `AsyncThrowingStream` contains `FusionResult`
    public nonisolated func receive() -> AsyncThrowingStream<FusionResult, Error> {
        return stream
    }
}

// MARK: - Private API Extension -

private extension FusionConnection {
    /// Receive message frames over the connection until it is cancelled or closed
    ///
    /// Finishes the stream on the end of stream or with the occurred `Error`
    private func processing() async -> Void {
        do { while !Task.isCancelled, let connection, try await receive(from: connection) { continue }; continuation.finish() } catch { continuation.finish(throwing: error) }
    }
    
    /// Receive data from the connection and parse it with `FusionFramer`
    ///
    /// Exposes the parsed `FusionMessage` and the `FusionReport`
    ///
    /// - Parameter connection: the `NetworkConnection`
    /// - Returns: false if the end of stream is reached
    private func receive(from connection: NetworkConnection<TCP>) async throws -> Bool {
        let (data, metadata) = try await connection.receive(atMost: Int(parameters.leverage.rawValue))
        if !data.isEmpty { continuation.yield(.init(report: .init(inbound: data.count))) }
        for message in try framer.parse(slice: data, ceiling: parameters.ceiling) { continuation.yield(.init(message: message)) }
        return !metadata.endOfStream
    }
}

//
//  FusionTests.swift.swift
//  Fusion
//
//  Created by Vinzenz Weist on 07.06.21.
//  Copyright © 2021 Vinzenz Weist. All rights reserved.
//

import Testing
import Foundation
import Network
@testable import Fusion

@Suite("Fusion Tests")
struct FusionTests {
    static let host = ProcessInfo.processInfo.environment["FUSION_HOST"] ?? "de0.weist.org"
    let connection = FusionConnection(using: .hostPort(host: .init(host), port: 7878))
    
    /// Send `String` message
    @Test("Send String")
    func sendString() async throws {
        try await sendReceive(message: "16384")
    }
    
    /// Send `Data` message
    @Test("Send Data")
    func sendData() async throws {
        try await sendReceive(message: Data(count: 16384))
    }
    
    /// Send `UInt16` message
    @Test("Send UInt")
    func sendUInt() async throws {
        try await sendReceive(message: UInt16(16384))
    }
    
    /// Framer error validation
    @Test("Famer Error")
    func framerError() async throws {
        var framer = FusionFramer()
        let malformed = Data([1, 0, 0, 0, 1, 0, 0, 0, 10, 80, 97, 115, 115, 33])
        let invalid = Data([0x1, 0x0, 0x0, 0x0, 0x6, 0xFF])
        let breakSync = Data([0x01, 0x00, 0x00, 0x00, 0x01, 0xAA, 0x02, 0x00, 0x00, 0x00, 0x01, 0xBB])
        let zeroLen = Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let oversized = Data([0x02, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: FusionFramerError.outbound) { try FusionFramer.create(message: Data(count: Int(UInt32.max))) }
        #expect(throws: FusionFramerError.outbound) { try FusionFramer.create(message: Data(count: Int(FusionCeiling.medium.rawValue)), ceiling: .low) }
        #expect(throws: FusionFramerError.inbound) { framer.clear(); _ = try framer.parse(slice: Data(count: Int(UInt32.max) + 1)) }
        #expect(throws: FusionFramerError.inbound) { framer.clear(); _ = try framer.parse(slice: Data(count: Int(FusionCeiling.high.rawValue)), ceiling: .low) }
        #expect(throws: FusionFramerError.inbound) { framer.clear(); _ = try framer.parse(slice: oversized, ceiling: .low) }
        #expect(throws: FusionFramerError.invalid) { framer.clear(); _ = try framer.parse(slice: zeroLen) }
        #expect(throws: FusionFramerError.decode) { framer.clear(); _ = try framer.parse(slice: invalid) }
        #expect(throws: FusionFramerError.decode) { framer.clear(); _ = try framer.parse(slice: malformed) }
        #expect(throws: FusionFramerError.decode) { framer.clear(); _ = try framer.parse(slice: breakSync) }
    }
    
    /// Create + parse with `FusionFramer`
    @Test("Parse Message") func parseMessage() async throws {
        var framer = FusionFramer(), frames: Data = .init()
        let messages: [FusionMessage] = ["Hello World! 🌍", Data(count: 16384), UInt16.max]
        var parsed: [FusionMessage] = .init()
        
        guard let messages = messages as? [FusionFrame] else { return }
        frames.append(try FusionFramer.create(message: messages[0]))
        frames.append(try FusionFramer.create(message: messages[1]))
        frames.append(try FusionFramer.create(message: messages[2]))
        
        for message in try framer.parse(slice: frames) { parsed.append(message) }
        
        #expect(parsed.count == messages.count)
        if let message = messages[0] as? String, let parse = parsed[0] as? String { #expect(message == parse) }
        if let message = messages[1] as? Data, let parse = parsed[1] as? Data { #expect(message == parse) }
        if let message = messages[2] as? UInt16, let parse = parsed[2] as? UInt16 { #expect(message == parse) }
    }
    
    /// Robustness check
    @Test("Parse Incomplete") func parseIncomplete() async throws {
        var framer = FusionFramer(), messages: [String] = []
        var frames = try FusionFramer.create(message: "Pass!")
        let slices: [Data] = [Data([1, 0, 0, 0]), Data([10, 80, 97]), Data([115, 115, 33])]
        
        frames.append(contentsOf: slices[0])
        for message in try framer.parse(slice: frames) { if let message = message as? String { messages.append(message) } }
        
        for _ in try framer.parse(slice: slices[1]) { /* nothing to append */ }
        
        frames.append(contentsOf: slices[2])
        for message in try framer.parse(slice: slices[2]) { if let message = message as? String { messages.append(message) } }
        #expect(messages.count == 2); #expect(messages[0] == messages[1])
    }
    
    /// Large frame received in many unaligned slices
    @Test("Parse Large") func parseLarge() async throws {
        var framer = FusionFramer(), parsed: [FusionFrame] = []
        let frame = try FusionFramer.create(message: Data(repeating: 0x7, count: 0x400000)), size = 0x10000 - 3
        for index in stride(from: .zero, to: frame.count, by: size) { parsed += try framer.parse(slice: frame[index..<min(index + size, frame.count)]) }
        #expect(parsed.count == 1)
        #expect((parsed.first as? Data) == Data(repeating: 0x7, count: 0x400000))
        #expect((parsed.first as? Data)?.startIndex == .zero)
    }
    
    /// Many frames inside a single slice
    @Test("Parse Many") func parseMany() async throws {
        var framer = FusionFramer(), frames = Data()
        for index in 0..<512 { frames.append(try FusionFramer.create(message: UInt16(index % 64))) }
        let parsed = try framer.parse(slice: frames).compactMap { $0 as? UInt16 }
        #expect(parsed == (0..<512).map { UInt16($0 % 64) })
    }
    
    /// Zer0 payload
    @Test("Zero Payload")
    func zeroPayload() async throws {
        var framer = FusionFramer()
        do {
            let frame = try FusionFramer.create(message: Data())
            let parsed = try framer.parse(slice: frame)
            #expect(parsed.count == 1); #expect(parsed[0] is Data); #expect((parsed[0] as? Data)?.count == 0)
        }
        framer.clear()
        do {
            let frame = try FusionFramer.create(message: "")
            let parsed = try framer.parse(slice: frame)
            #expect(parsed.count == 1); #expect(parsed[0] is String); #expect((parsed[0] as? String) == "")
        }
    }
    
    /// The `NWProtocolTCP.Options` are applied to the `TCP` protocol
    @Test("TCP Options")
    func tcpOptions() async throws {
        let options = NWProtocolTCP.Options(); options.noDelay = true; options.connectionTimeout = 3
        let parameters = NWParameters(tls: nil, tcp: options)
        let connection = NetworkConnection(to: .hostPort(host: "127.0.0.1", port: 7878), using: .parameters(initialParameters: parameters) { TCP(from: parameters) })
        let applied = connection.parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options
        #expect(applied?.noDelay == true); #expect(applied?.connectionTimeout == 3)
    }
    
    /// Error description
    @Test("Error description")
    func errorDescription() async throws {
        do {
            var count = 0
            for state in FusionConnectionError.allCases { count += 1; #expect(!state.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            #expect(count == FusionConnectionError.allCases.count)
        }
        do {
            var count = 0
            for state in FusionFramerError.allCases { count += 1; #expect(!state.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            #expect(count == FusionFramerError.allCases.count)
        }
    }
}

// MARK: - Private API Extension -

extension FusionTests {
    /// Perform Send + Receive
    ///
    /// - Parameter message: message that conforms to `FusionMessage`
    private func sendReceive<Message: FusionMessage>(message: Message) async throws {
        try await connection.start(); try await connection.send(message: message)
        for try await result in connection.receive() {
            guard let messages = result.message else { continue }
            if message is String { if let messages = messages as? Data { #expect(messages.count == Int(message as! String)) } }
            if message is Data { if let messages = messages as? String { #expect(messages == "\((message as! Data).count)") } }
            if message is UInt16 { if let messages = messages as? UInt16 { #expect(messages == message as! UInt16) } }
            await connection.cancel()
        }
    }
}

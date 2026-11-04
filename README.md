# Swift Fusion
The `FusionConnection` is a custom network connector that implements the **Fusion Framing Protocol (FFP)**
It is built on top of the standard `Network` framework library. This fast and lightweight custom framing protocol 
enables high-speed data transmission and provides fine-grained control over network flow.

# Overview
| Swift Version                                                                                                | License                                                                                                                                              | Coverage                                                                                                                                              |
|--------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| [![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg?logo=swift&style=flat)](https://swift.org)   | [![License](https://img.shields.io/badge/license-MIT-blue.svg?longCache=true&style=flat)](https://github.com/Vinz1911/swift-fusion/blob/main/LICENSE) | [![codecov](https://codecov.io/github/Vinz1911/swift-fusion/branch/main/graph/badge.svg?token=EE3S0BOINS)](https://codecov.io/github/Vinz1911/swift-fusion) |
| [![Swift 6.2](https://img.shields.io/badge/SPM-Support-orange.svg?logo=swift&style=flat)](https://swift.org) |                                                                                                                                                      |                                                                                                                                                       |
> [!IMPORTANT]  
> With the beginning of version 2.0.0 the framework uses an entire new private and public interface.
> The Framework was migrated to use the new structured concurrency based API for safe and easy handling.
> Below version 2.0.0 can be used for 'old' API interface but will not be actively maintained anymore.

## Installation:
### Swift Packages

```swift
// ...
dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(url: "https://github.com/Vinz1911/swift-fusion", exact: "2.0.0"),
]

// in targets
dependencies: [
    .product(name: "Fusion", package: "swift-fusion")
]
// ...
```

## Import:
```swift
// Import the Framework
import Fusion

// Create a new connection
let connection = FusionConnection(using: .hostPort(host: "example.com", port: 7878))

// Support for NWParameters, the NWProtocolTCP.Options are applied to the connection
let options = NWProtocolTCP.Options(); options.noDelay = true
let connection = FusionConnection(using: .hostPort(host: "example.com", port: 7878), parameters: .init(with: .init(tls: nil, tcp: options)))

// Start connection
try await connection.start()

// ...
```

## Send Messages:
```swift
// Import the Framework
import Fusion

// Create a new connection
let connection = FusionConnection(using: .hostPort(host: "example.com", port: 7878))

// Start connection
try await connection.start()

// The framework accepts different kind of messages
// `String` for text (UTF-8) based messages
// `Data` for raw byte messages
// `UInt16` for ping - pong messages (generates a data frame based on input value)

// Send String
try await connection.send(message: "Hello World!")

// Send Data
try await connection.send(message: Data(count: 100))

// Send UInt16
try await connection.send(message: UInt16.max)
```

## Receive Message:
```swift
// Import the Framework
import Fusion

// Create a new connection
let connection = FusionConnection(using: .hostPort(host: "example.com", port: 7878))

// Start connection
try await connection.start()

// Send message
try await connection.send(message: "Hello World! 👻")

// Receive message and get report
for try await result in connection.receive() {
    if let message = result.message {
        /// Message as String, Data or UInt16
    }
    if let report = result.report {
        /// Inbound and Outbound byte transfer report
    }
}
```

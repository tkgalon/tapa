import Foundation

public let spikeMachServiceName = "id.tapa.spike.daemon"

@objc public protocol SpikeService {
    func ping(reply: @escaping @Sendable (String) -> Void)
}

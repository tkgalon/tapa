import Foundation
import TapaCore

public struct SystemMonotonicClock: MonotonicClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    public init() {}

    public func seconds() -> TimeInterval {
        let nanoseconds = Double(mach_continuous_time()) * Double(Self.timebase.numer) / Double(Self.timebase.denom)
        return nanoseconds / 1_000_000_000
    }
}

public enum BootSession {
    public struct Unavailable: Error {}

    /// A UUID that changes on every boot.
    public static func currentID() throws -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
            throw Unavailable()
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else {
            throw Unavailable()
        }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard let id = String(bytes: bytes, encoding: .utf8) else { throw Unavailable() }
        return id
    }
}

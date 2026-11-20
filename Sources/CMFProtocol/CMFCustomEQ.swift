import Foundation

public struct CMFCustomEQ: Hashable, Sendable {
    public enum Band: UInt8, CaseIterable, Sendable {
        case bass = 0
        case mid = 1
        case treble = 2
    }

    public struct Filter: Hashable, Sendable {
        public var gain: Float
        public var frequency: Float
        public var q: Float

        public init(gain: Float, frequency: Float, q: Float) {
            self.gain = gain
            self.frequency = frequency
            self.q = q
        }
    }

    public static let gainRange: ClosedRange<Int> = -6...6
    static let recordLength = 13

    public static let factory = CMFCustomEQ(filters: [
        .bass: Filter(gain: 0, frequency: 140, q: 0.8),
        .mid: Filter(gain: 0, frequency: 980, q: 0.66),
        .treble: Filter(gain: 0, frequency: 3500, q: 1.0),
    ])

    public var filters: [Band: Filter]

    public init(filters: [Band: Filter]) {
        self.filters = filters
    }

    public func gain(_ band: Band) -> Int {
        Int((filters[band]?.gain ?? 0).rounded())
    }

    public func setting(_ band: Band, to gain: Int) -> CMFCustomEQ {
        var copy = self
        var filter = filters[band] ?? Self.factory.filters[band]!
        filter.gain = Float(min(max(gain, Self.gainRange.lowerBound), Self.gainRange.upperBound))
        copy.filters[band] = filter
        return copy
    }

    // The headphones apply a pre-gain equal to the largest boost so the curve never clips.
    public var totalGain: Float {
        -max(0, filters.values.map(\.gain).max() ?? 0)
    }

    public func encoded() -> [UInt8] {
        var bytes: [UInt8] = [UInt8(Band.allCases.count)]
        bytes += totalGain.littleEndianBytes
        for band in [Band.mid, .treble, .bass] {
            let filter = filters[band] ?? Self.factory.filters[band]!
            bytes.append(band.rawValue)
            bytes += filter.gain.littleEndianBytes + filter.frequency.littleEndianBytes + filter.q.littleEndianBytes
        }
        return bytes
    }

    public static func decode(_ payload: [UInt8]) -> CMFCustomEQ? {
        guard let count = payload.first, count > 0, payload.count >= 5 + Int(count) * recordLength else { return nil }
        var filters: [Band: Filter] = [:]
        for index in 0..<Int(count) {
            let offset = 5 + index * recordLength
            guard let band = Band(rawValue: payload[offset]) else { continue }
            filters[band] = Filter(
                gain: Float(littleEndian: payload, at: offset + 1),
                frequency: Float(littleEndian: payload, at: offset + 5),
                q: Float(littleEndian: payload, at: offset + 9)
            )
        }
        return filters.count == Band.allCases.count ? CMFCustomEQ(filters: filters) : nil
    }
}

extension Float {
    fileprivate var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: bitPattern.littleEndian, Array.init)
    }

    fileprivate init(littleEndian bytes: [UInt8], at offset: Int) {
        let bits = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
        self.init(bitPattern: bits)
    }
}

public final class CMFCustomEQCache: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = CMFCustomEQ.factory

    public init() {}

    public var value: CMFCustomEQ {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

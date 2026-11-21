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
        guard let gain = filters[band]?.gain, gain.isFinite else { return 0 }
        return Int(min(max(gain, Float(Self.gainRange.lowerBound)), Float(Self.gainRange.upperBound)).rounded())
    }

    public var gains: [Band: Int] {
        Dictionary(uniqueKeysWithValues: Band.allCases.map { ($0, gain($0)) })
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
            let gain = Float(littleEndian: payload, at: offset + 1)
            let frequency = Float(littleEndian: payload, at: offset + 5)
            let q = Float(littleEndian: payload, at: offset + 9)
            // Values come straight off the wire; a corrupt or unexpected reply must not reach Int conversion.
            guard gain.isFinite, frequency.isFinite, q.isFinite else { return nil }
            let limit = Float(gainRange.upperBound)
            filters[band] = Filter(gain: min(max(gain, -limit), limit), frequency: frequency, q: q)
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

/// Holds the latest Custom EQ so an edit to one band keeps the others, even while earlier writes are in flight.
public final class CMFCustomEQCache: @unchecked Sendable {
    private struct Edit {
        let gains: [CMFCustomEQ.Band: Int]
        let date: Date
    }

    /// A write the headphones never confirm stops blocking read-backs after this long.
    public static let editLifetime: TimeInterval = 3

    private let lock = NSLock()
    private var stored = CMFCustomEQ.factory
    private var unconfirmed: [Edit] = []
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = Date.init) {
        self.now = now
    }

    public var value: CMFCustomEQ {
        lock.withLock { stored }
    }

    /// Applies a local edit and returns the full curve to write.
    public func edit(_ band: CMFCustomEQ.Band, to gain: Int) -> CMFCustomEQ {
        lock.withLock {
            stored = stored.setting(band, to: gain)
            unconfirmed.append(Edit(gains: stored.gains, date: now()))
            return stored
        }
    }

    /// Reconciles a read-back from the headphones and returns the curve the UI should show.
    ///
    /// A read-back that matches a pending edit confirms it and every edit before it. The cache only adopts the
    /// headphones' values once no newer edit is waiting, so an older confirmation cannot revert a newer edit.
    public func reconcile(_ reported: CMFCustomEQ) -> CMFCustomEQ {
        lock.withLock {
            let cutoff = now().addingTimeInterval(-Self.editLifetime)
            unconfirmed.removeAll { $0.date < cutoff }
            if let matched = unconfirmed.lastIndex(where: { $0.gains == reported.gains }) {
                unconfirmed.removeFirst(matched + 1)
            }
            if unconfirmed.isEmpty { stored = reported }
            return stored
        }
    }
}

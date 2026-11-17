import Foundation

extension Data {
    init(hex: String) {
        self.init(hex.split(separator: " ").compactMap { UInt8($0, radix: 16) })
    }
}

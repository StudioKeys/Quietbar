public enum CMFCommand: UInt16, CaseIterable, Sendable {
    case getProtocolVersion = 0xC001
    case getBattery = 0xC007
    case getNoiseControl = 0xC01E
    case getDualConnection = 0xC027
    case getLowLag = 0xC041
    case getCustomEQ = 0xC044
    case getSpatialAudio = 0xC04F
    case getEQPreset = 0xC050
    case setNoiseControl = 0xF00F
    case setDualConnection = 0xF01A
    case setEQPreset = 0xF01D
    case setLowLag = 0xF040
    case setCustomEQ = 0xF041
    case setSpatialAudio = 0xF052
    case batteryChanged = 0xE001
    case noiseControlChanged = 0xE003

    public var responseCommand: UInt16 {
        rawValue & 0x7FFF
    }
}

public enum CMFCommand: UInt16, CaseIterable, Sendable {
    case getProtocolVersion = 0xC001
    case getBattery = 0xC007
    case getNoiseControl = 0xC01E
    case getEQPreset = 0xC01F
    case getLowLag = 0xC041
    case getDualConnection = 0xC027
    case getSpatialAudio = 0xC04F
    case setNoiseControl = 0xF00F
    case setEQPreset = 0xF010
    case setLowLag = 0xF040
    case setDualConnection = 0xF01A
    case setSpatialAudio = 0xF052
    case batteryChanged = 0xE001
    case noiseControlChanged = 0xE003
    case lowLagChanged = 0xE005

    public var responseCommand: UInt16 {
        rawValue & 0x7FFF
    }
}

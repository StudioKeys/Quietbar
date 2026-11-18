import HeadphoneKit

@testable import Quietbar

actor FakeController: HeadphoneControlling {
    nonisolated let snapshots: AsyncStream<DeviceSnapshot>
    private let snapshotContinuation: AsyncStream<DeviceSnapshot>.Continuation
    private let holdsApplies: Bool
    private var held: [CheckedContinuation<Void, Never>] = []
    private(set) var applied: [SettingChange] = []
    private(set) var startCount = 0
    private(set) var refreshCount = 0
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var stopCount = 0
    private let holdsStop: Bool
    private var heldStops: [CheckedContinuation<Void, Never>] = []

    init(holdsApplies: Bool = false, holdsStop: Bool = false) {
        self.holdsStop = holdsStop
        (snapshots, snapshotContinuation) = AsyncStream.makeStream()
        self.holdsApplies = holdsApplies
    }

    func start() async { startCount += 1 }
    func stop() async {
        stopCount += 1
        guard holdsStop else { return }
        await withCheckedContinuation { heldStops.append($0) }
    }

    func releaseStop() {
        let waiting = heldStops
        heldStops = []
        for continuation in waiting { continuation.resume() }
    }
    func refresh() async { refreshCount += 1 }
    func userConnect() async { connectCount += 1 }
    func userDisconnect() async { disconnectCount += 1 }

    func apply(_ change: SettingChange) async throws(ApplyError) {
        applied.append(change)
        guard holdsApplies else { return }
        await withCheckedContinuation { held.append($0) }
    }

    func releaseAll() {
        let waiting = held
        held = []
        for continuation in waiting { continuation.resume() }
    }

    func publish(_ snapshot: DeviceSnapshot) {
        snapshotContinuation.yield(snapshot)
    }
}

struct WaitTimedOut: Error {}

func waitUntil(
    within timeout: Duration = .seconds(1),
    _ condition: @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while await !condition() {
        guard ContinuousClock.now < deadline else { throw WaitTimedOut() }
        try await Task.sleep(for: .milliseconds(5))
    }
}

enum Fixtures {
    static let noiseOptions = [
        ChoiceOption(id: "anc", title: "Noise Cancellation", symbol: "headphones"),
        ChoiceOption(id: "ambientAware", title: "Ambient", symbol: "ear.badge.waveform"),
        ChoiceOption(id: "talkThru", title: "Talk-Thru", symbol: "person.wave.2"),
        ChoiceOption(id: "off", title: "Off", symbol: "headphones.slash"),
    ]

    static let model = DeviceModel(
        name: "Test Phones",
        nameFragment: "Test",
        link: .gatt(GattProfile(service: "0", notify: "1", write: "2")),
        settings: [
            SettingDescriptor(
                id: "noiseMode", title: "Noise", kind: .choice(noiseOptions, style: .modeButtons), section: .noise),
            SettingDescriptor(
                id: "adaptiveAnc", title: "Adaptive ANC", kind: .toggle, section: .noise,
                visibleWhen: .equals("noiseMode", .choice("anc"))
            ),
            SettingDescriptor(
                id: "ambientLevel", title: "Ambient level", kind: .level(1...7, style: .slider), section: .noise,
                visibleWhen: .equals("noiseMode", .choice("ambientAware"))
            ),
            SettingDescriptor(id: "lowVolumeEq", title: "Low Volume EQ", kind: .toggle, section: .sound),
            SettingDescriptor(
                id: "balance", title: "Balance", kind: .level(-16...16, style: .balance), section: .sound),
        ]
    )

    static func snapshot(
        _ status: ConnectionStatus = .connected,
        _ updates: [DeviceUpdate] = []
    ) -> DeviceSnapshot {
        DeviceSnapshot(status: status, state: DeviceState.empty.applying(updates), lastError: nil)
    }
}

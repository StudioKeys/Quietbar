import HeadphoneKit
import Testing

@testable import Quietbar

@MainActor
struct HeadphoneViewModelTests {
    private func viewModel(_ controller: FakeController) -> HeadphoneViewModel {
        HeadphoneViewModel(controller: controller, model: Fixtures.model)
    }

    private func observed(_ controller: FakeController, _ snapshot: DeviceSnapshot) async throws -> HeadphoneViewModel {
        let model = viewModel(controller)
        Task { await model.observe() }
        await controller.publish(snapshot)
        try await waitUntil { await model.snapshot == snapshot }
        return model
    }

    @Test func ancShowsAdaptiveToggleOnly() async throws {
        let model = try await observed(
            FakeController(), Fixtures.snapshot(.connected, [.setting("noiseMode", .choice("anc"))]))

        #expect(model.sections.map(\.section) == [.noise, .sound])
        #expect(model.sections[0].settings.map(\.id) == ["noiseMode", "adaptiveAnc"])
    }

    @Test func ambientShowsLevelOnly() async throws {
        let model = try await observed(
            FakeController(),
            Fixtures.snapshot(.connected, [.setting("noiseMode", .choice("ambientAware"))])
        )

        #expect(model.sections[0].settings.map(\.id) == ["noiseMode", "ambientLevel"])
    }

    @Test func sectionsKeepDescriptorOrder() {
        let model = viewModel(FakeController())

        #expect(model.sections.flatMap(\.settings).map(\.id) == ["noiseMode", "lowVolumeEq", "balance"])
    }

    @Test func settingChangeIsPendingUntilApplyReturns() async throws {
        let controller = FakeController(holdsApplies: true)
        let model = viewModel(controller)

        let task = model.set("lowVolumeEq", .bool(true))
        try await waitUntil { await controller.applied.count == 1 }

        #expect(model.pending == ["lowVolumeEq"])
        #expect(model.set("lowVolumeEq", .bool(false)) == nil)
        await controller.releaseAll()
        await task?.value
        #expect(model.pending.isEmpty)
        #expect(await controller.applied == [SettingChange(id: "lowVolumeEq", value: .bool(true))])
    }

    @Test func valueReadsFromSnapshotState() async throws {
        let model = try await observed(
            FakeController(), Fixtures.snapshot(.connected, [.setting("balance", .level(-3))]))

        #expect(model.value(for: "balance") == .level(-3))
        #expect(model.isOn("lowVolumeEq") == false)
    }

    @Test(arguments: [(0, "0"), (-4, "L 4"), (6, "R 6")])
    func balanceBadgeText(offset: Int, text: String) {
        #expect(HeadphoneViewModel.balanceText(offset) == text)
    }

    @Test func runStartsSessionAndMirrorsSnapshots() async throws {
        let controller = FakeController()
        let model = viewModel(controller)
        let running = Task { await model.run() }
        defer { running.cancel() }

        await controller.publish(Fixtures.snapshot(.connected, [.setting("noiseMode", .choice("off"))]))

        try await waitUntil { await model.icon.symbolName == "headphones.slash" }
        #expect(await controller.startCount == 1)
        #expect(model.statusText == "Connected")
        #expect(model.deviceName == "Test Phones")
    }

    @Test func menuOpenedRefreshesOnlyWhenConnected() async throws {
        let controller = FakeController()
        let idle = viewModel(controller)
        #expect(idle.menuOpened() == nil)

        let connected = try await observed(controller, Fixtures.snapshot())
        await connected.menuOpened()?.value

        #expect(await controller.refreshCount == 1)
    }

    @Test func connectAndDisconnectForward() async {
        let controller = FakeController()
        let model = viewModel(controller)

        await model.connect().value
        await model.disconnect().value

        #expect(await controller.connectCount == 1)
        #expect(await controller.disconnectCount == 1)
    }

    @Test func lastValuesStayVisibleButLockedWhileReconnecting() async throws {
        let model = try await observed(
            FakeController(),
            Fixtures.snapshot(.searching, [.setting("noiseMode", .choice("anc"))])
        )

        #expect(model.showsControls)
        #expect(!model.canEdit)
    }

    @Test func controlsHiddenWhenNothingIsKnown() async throws {
        let model = try await observed(FakeController(), Fixtures.snapshot(.searching))

        #expect(!model.showsControls)
    }

    @Test func connectedControlsAreEditable() async throws {
        let model = try await observed(FakeController(), Fixtures.snapshot(.connected))

        #expect(model.showsControls)
        #expect(model.canEdit)
    }
}

import HeadphoneKit
import JBLProtocol
import Testing

@testable import Quietbar

@MainActor
struct HeadphoneViewModelTests {
    @Test func selectingModeMarksPendingUntilApplyReturns() async throws {
        let controller = FakeController(holdsApplies: true)
        let viewModel = HeadphoneViewModel(controller: controller)

        let task = viewModel.select(.ambientAware)
        try await waitUntil { await controller.applied == [.setNoiseMode(.ambientAware)] }

        #expect(viewModel.pending == [.noiseMode])
        await controller.releaseAll()
        await task?.value
        #expect(viewModel.pending.isEmpty)
    }

    @Test func secondChangeOfSameKindIsIgnoredWhilePending() async throws {
        let controller = FakeController(holdsApplies: true)
        let viewModel = HeadphoneViewModel(controller: controller)
        let first = viewModel.select(.anc)

        let second = viewModel.select(.talkThru)

        #expect(second == nil)
        try await waitUntil { await controller.applied.count == 1 }
        await controller.releaseAll()
        await first?.value
        #expect(await controller.applied == [.setNoiseMode(.anc)])
    }

    @Test func forwardsEverySettingAsItsCommand() async {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)

        await viewModel.setAmbientLevel(3)?.value
        await viewModel.select(EqPreset.vocal)?.value
        await viewModel.setSpatial(SpatialSetting(isOn: true, mode: .movie))?.value
        await viewModel.setLowVolumeEq(false)?.value
        await viewModel.setBalance(offset: -2)?.value

        #expect(
            await controller.applied == [
                .setAmbientLevel(AmbientLevel(3)!), .setEqPreset(.vocal),
                .setSpatial(SpatialSetting(isOn: true, mode: .movie)), .setLowVolumeEq(false),
                .setBalance(Balance(offset: -2)!),
            ]
        )
    }

    @Test func outOfRangeValuesAreIgnored() async {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)

        let ambient = viewModel.setAmbientLevel(9)
        let balance = viewModel.setBalance(offset: 40)

        #expect(ambient == nil)
        #expect(balance == nil)
        #expect(await controller.applied.isEmpty)
    }

    @Test func observeMirrorsSessionSnapshots() async throws {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)
        let observing = Task { await viewModel.observe() }
        defer { observing.cancel() }

        await controller.publish(snapshot(noiseMode: .talkThru, battery: 40))

        try await waitUntil { await viewModel.snapshot.state.noiseMode == .talkThru }
        #expect(viewModel.icon.batteryText == "40%")
        #expect(viewModel.statusText == "Connected")
        #expect(viewModel.isConnected)
    }

    @Test func menuOpenedRefreshesWhenConnected() async throws {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)
        let observing = Task { await viewModel.observe() }
        defer { observing.cancel() }
        await controller.publish(snapshot(.connected))
        try await waitUntil { await viewModel.isConnected }

        await viewModel.menuOpened()?.value

        #expect(await controller.refreshCount == 1)
    }

    @Test func menuOpenedSkipsRefreshWhenDisconnected() async {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)

        let task = viewModel.menuOpened()

        #expect(task == nil)
        #expect(await controller.refreshCount == 0)
    }

    @Test func connectAndDisconnectForwardToSession() async {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)

        await viewModel.connect().value
        await viewModel.disconnect().value

        #expect(await controller.connectCount == 1)
        #expect(await controller.disconnectCount == 1)
    }

    @Test func runStartsSessionAndMirrorsSnapshots() async throws {
        let controller = FakeController()
        let viewModel = HeadphoneViewModel(controller: controller)
        let running = Task { await viewModel.run() }
        defer { running.cancel() }

        await controller.publish(snapshot(noiseMode: .off))

        try await waitUntil { await viewModel.snapshot.state.noiseMode == .off }
        #expect(await controller.startCount == 1)
    }
}

import Testing

@testable import HeadphoneKit

struct SettingDescriptorTests {
    private let adaptive = SettingDescriptor(
        id: "adaptiveAnc",
        title: "Adaptive ANC",
        kind: .toggle,
        section: .noise,
        visibleWhen: .equals("noiseMode", .choice("anc"))
    )

    @Test func visibleWhenConditionMatches() {
        let state = DeviceState.empty.applying([.setting("noiseMode", .choice("anc"))])

        #expect(adaptive.isVisible(in: state))
    }

    @Test func hiddenWhenConditionDiffers() {
        let state = DeviceState.empty.applying([.setting("noiseMode", .choice("talkThru"))])

        #expect(!adaptive.isVisible(in: state))
    }

    @Test func hiddenWhenConditionSettingUnknown() {
        #expect(!adaptive.isVisible(in: .empty))
    }

    @Test func descriptorWithoutConditionAlwaysVisible() {
        let eq = SettingDescriptor(
            id: "eqPreset",
            title: "EQ preset",
            symbol: "slider.vertical.3",
            kind: .choice([ChoiceOption(id: "studio", title: "Studio")], style: .menu),
            section: .sound
        )

        #expect(eq.isVisible(in: .empty))
    }

    @Test func settingIdIsStringBacked() {
        let id: SettingID = "balance"

        #expect(id.rawValue == "balance")
    }

    @Test func appliesWithReconnectDefaultsToFalse() {
        #expect(!adaptive.appliesWithReconnect)
    }
}

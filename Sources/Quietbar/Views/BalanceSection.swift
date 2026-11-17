import JBLProtocol
import SwiftUI

struct BalanceSection: View {
    let viewModel: HeadphoneViewModel
    @State private var draft = 0.0

    var body: some View {
        HStack {
            Text("Balance")
            Text("L").foregroundStyle(.secondary)
            Slider(
                value: $draft,
                in: Double(Balance.range.lowerBound)...Double(Balance.range.upperBound),
                step: 1
            ) { isEditing in
                if !isEditing { viewModel.setBalance(offset: Int(draft)) }
            }
            .disabled(viewModel.state.balance == nil || viewModel.pending.contains(.balance))
            .accessibilityLabel("Left right balance")
            .accessibilityValue(Int(draft) == 0 ? "Centre" : "\(Int(draft))")
            Text("R").foregroundStyle(.secondary)
        }
        .onChange(of: viewModel.state.balance, initial: true) { _, balance in
            if let balance { draft = Double(balance.offset) }
        }
    }
}

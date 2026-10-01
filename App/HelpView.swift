import SwiftUI

/// Real in-app documentation — port of HelpActivity.kt, displaying
/// `helpSections` (HelpContent.swift).
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(helpSections.enumerated()), id: \.offset) { sectionIndex, section in
                        VStack(alignment: .leading, spacing: 10) {
                            DesignSystem.sectionLabel(section.label)
                            ForEach(Array(section.cards.enumerated()), id: \.offset) { cardIndex, card in
                                DesignSystem.card {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(card.title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                            .accessibilityIdentifier("helpCardTitle_\(sectionIndex)_\(cardIndex)")
                                        Text(card.body).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

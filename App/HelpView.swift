import SwiftUI

/// Real in-app documentation — port of HelpActivity.kt, displaying
/// `helpSections` (HelpContent.swift).
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.xl) {
                    ForEach(Array(helpSections.enumerated()), id: \.offset) { sectionIndex, section in
                        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                            DesignSystem.sectionLabel(section.label)
                            ForEach(Array(section.cards.enumerated()), id: \.offset) { cardIndex, card in
                                DesignSystem.card {
                                    VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
                                        Text(card.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                            .accessibilityIdentifier("helpCardTitle_\(sectionIndex)_\(cardIndex)")
                                        Text(card.body).font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Space.l)
            }
            .visionScreen()
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

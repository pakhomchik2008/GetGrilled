import SwiftUI

struct CreatePlanView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    TextField("e.g. Backend Engineer", text: $viewModel.newRoleTitle)
                    Picker("Level", selection: $viewModel.newSeniority) {
                        ForEach(Seniority.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    TextField("Company (context/tone only, optional)", text: $viewModel.newCompanyContext)
                    TextField("Focus on (optional)", text: $viewModel.newFocusNotes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Company is used only to flavor the tone/domain — the AI won't claim these are that company's real interview questions.")
                }
            }
            .navigationTitle("New plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isCreating {
                        ProgressView()
                    } else {
                        Button("Generate") {
                            viewModel.createPlan { isPresented = false }
                        }
                        .disabled(viewModel.newRoleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote).padding()
            }
        }
    }
}

#Preview {
    CreatePlanView(viewModel: PlansViewModel(), isPresented: .constant(true))
}

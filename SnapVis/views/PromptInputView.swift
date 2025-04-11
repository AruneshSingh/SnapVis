import SwiftUI

struct PromptInputView: View {
    @State private var userPrompt: String = ""
    // Add callback for when prompt is submitted
    var onSubmit: (String) -> Void
    // Access dismiss action if needed
    @Environment(\.dismiss) var dismiss 

    var body: some View {
        VStack(spacing: 15) {
            Text("Enter Prompt for Screenshot")
                .font(.headline)

            HStack {
                TextField("Type your prompt here...", text: $userPrompt)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .onSubmit {
                        if !userPrompt.isEmpty {
                            onSubmit(userPrompt)
                        }
                    }

                Button {
                    if !userPrompt.isEmpty {
                        onSubmit(userPrompt)
                    }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(userPrompt.isEmpty)
                .keyboardShortcut(.defaultAction) // Allow Enter key to trigger button too
            }
        }
        .padding()
        .background(.regularMaterial) // Add a material background
        .frame(minWidth: 350)
    }
}

#Preview {
    PromptInputView(onSubmit: { prompt in print("Submitted prompt: \(prompt)") })
} 
import SwiftUI

struct ChatResponseView: View {
    // These will be passed in or accessed via the ViewModel
    var image: NSImage?
    var prompt: String
    var response: String?
    var isLoading: Bool
    
    // Access dismiss action
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gemini Vision Prompt")
                    .font(.title2)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                    .frame(maxHeight: 250) 
            }
            
            VStack(alignment: .leading) {
                Text("Your Prompt:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(prompt)
            }
            
            Divider()
            
            VStack(alignment: .leading) {
                 Text("Response:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Waiting for response...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
                } else if let responseText = response {
                    ScrollView {
                        Text(responseText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                } else {
                    Text("No response available.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            Spacer() // Push content to the top
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300, idealHeight: 450) // Adjust size
    }
}

#Preview {
    ChatResponseView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil), 
        prompt: "What is in this image? Explain it in detail.", 
        response: "This is a **placeholder** response describing the image contents. It might contain *formatted* text and `code` snippets.\n\n- Point 1\n- Point 2", 
        isLoading: false
    )
}

#Preview("Loading State") {
    ChatResponseView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil), 
        prompt: "What is in this image?", 
        response: nil, 
        isLoading: true
    )
} 
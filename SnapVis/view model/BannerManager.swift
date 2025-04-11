import SwiftUI
import AppKit

// MARK: - Banner View
fileprivate struct BannerView: View {
    let message: String
    let isLoading: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Use a fixed-size frame for the icon area to ensure consistent sizing
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .frame(width: 16, height: 16)

            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.vertical, 10) // Increased vertical padding for consistent height
        .padding(.horizontal, 16)
        .frame(height: 36) // Fixed height for both states
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(white: 0.1, opacity: 0.9) : Color(white: 0.95, opacity: 0.9))
        )
    }
}

// MARK: - Banner Manager
class BannerWindowController {
    private var window: NSWindow?
    private var isVisible = false
    private var hideTimer: Timer?


    static let shared = BannerWindowController()

    private init() {}

    func showBanner(message: String, isLoading: Bool, duration: TimeInterval = 2.5) {
        hideTimer?.invalidate()

        DispatchQueue.main.async {
            // Create banner content and hosting controller
            let bannerView = BannerView(message: message, isLoading: isLoading)
            let hostingController = NSHostingController(rootView: bannerView)
            let newView = hostingController.view

            // --- Get Active Screen (where mouse is) ---
            let activeScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            guard let screen = activeScreen else {
                return // Cannot proceed without a screen
            }
            // --- End Get Active Screen ---

            // Calculate the optimal size for the view
            let optimalSize = newView.fittingSize
            newView.frame.size = optimalSize // Ensure view knows its size

            // Create window if needed
            if self.window == nil {
                let window = NSWindow(
                    contentRect: NSRect(origin: .zero, size: optimalSize), // Initial size
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
                window.level = .statusBar
                window.collectionBehavior = [.canJoinAllSpaces]
                window.ignoresMouseEvents = true
                window.alphaValue = 0.0
                window.hidesOnDeactivate = false

                self.window = window
            }


            // Assign content controller
            self.window?.contentViewController = hostingController

            // Calculate final frame and position window using setFrame (using active screen)
            if let window = self.window {
                let finalSize = newView.fittingSize // Get size again after assigning?
                let x = screen.frame.origin.x + (screen.frame.width - finalSize.width) / 2 // Center based on active screen frame X and width
                // Calculate Y dynamically based on active screen
                let y = screen.visibleFrame.maxY - finalSize.height - 50 // 50px padding
                let finalFrame = NSRect(x: x, y: y, width: finalSize.width, height: finalSize.height)
                // Set frame without animation for initial show
                window.setFrame(finalFrame, display: true, animate: false)
            }

            // Show window
            self.window?.orderFront(nil)
            self.isVisible = true

            // Animate appearance (alpha fade-in)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.window?.animator().alphaValue = 1.0
            }

            // Schedule hiding
            if !isLoading {
                self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.hideBanner()
                }
            }
        }
    }

    func updateBanner(message: String, isLoading: Bool) {
        DispatchQueue.main.async {
            if self.isVisible, let window = self.window {
                // Create new banner view and hosting controller
                let bannerView = BannerView(message: message, isLoading: isLoading)
                let hostingController = NSHostingController(rootView: bannerView)
                let newView = hostingController.view

                // --- Get Active Screen (where mouse is) ---
                let activeScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
                guard let screen = activeScreen else {
                    return // Cannot proceed without a screen
                }
                // --- End Get Active Screen ---

                // Calculate the optimal size for the new view
                let optimalSize = newView.fittingSize
                newView.frame.size = optimalSize // Ensure view knows its size


                // Assign new content controller
                window.contentViewController = hostingController

                // Calculate final frame and reposition window using setFrame (animated, using active screen)
                let finalSize = newView.fittingSize // Get size again after assigning?
                let x = screen.frame.origin.x + (screen.frame.width - finalSize.width) / 2 // Center based on active screen frame X and width
                // Calculate Y dynamically based on active screen
                let y = screen.visibleFrame.maxY - finalSize.height - 50 // 50px padding
                let finalFrame = NSRect(x: x, y: y, width: finalSize.width, height: finalSize.height)

                // Animate frame change for updates
                window.setFrame(finalFrame, display: true, animate: true)

                // If not loading, (re)start hide timer
                self.hideTimer?.invalidate()
                if !isLoading {
                    self.hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                        self?.hideBanner()
                    }
                }
            } else {
                // If not visible, show it using the updated showBanner logic
                self.showBanner(message: message, isLoading: isLoading)
            }
        }
    }

    func hideBanner() {
        guard isVisible, let window = self.window else { return }

        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            }, completionHandler: {
                window.orderOut(nil)
                self.isVisible = false
            })
        }
    }
} 
import UIKit
import SwiftUI

private class ShakeResponderView: UIView {
    override var canBecomeFirstResponder: Bool { true }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

private struct ShakeView: UIViewRepresentable {
    func makeUIView(context: Context) -> ShakeResponderView {
        let view = ShakeResponderView()
        view.becomeFirstResponder()
        return view
    }
    func updateUIView(_ uiView: ShakeResponderView, context: Context) {}
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeModifier: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content
            .overlay(ShakeView().frame(width: 0, height: 0))
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeModifier(action: action))
    }
}

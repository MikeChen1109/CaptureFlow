import Combine
import SwiftUI
import UIKit

struct DynamicIslandToast: Equatable {
    enum Style: Equatable {
        case success
        case info
        case warning
        case failure

        var tint: Color {
            switch self {
            case .success:
                CFColors.success
            case .info:
                CFColors.info
            case .warning:
                CFColors.warning
            case .failure:
                CFColors.destructive
            }
        }
    }

    var title: String
    var message: String
    var systemImage: String
    var style: Style

    static func success(title: String = "Done", message: String) -> DynamicIslandToast {
        DynamicIslandToast(
            title: title,
            message: message,
            systemImage: "checkmark.circle.fill",
            style: .success
        )
    }
}

extension View {
    func dynamicIslandToastOverlay() -> some View {
        modifier(DynamicIslandToastViewModifier())
    }
}

private struct DynamicIslandToastActionKey: EnvironmentKey {
    static let defaultValue: (DynamicIslandToast) -> Void = { _ in }
}

extension EnvironmentValues {
    var showDynamicIslandToast: (DynamicIslandToast) -> Void {
        get { self[DynamicIslandToastActionKey.self] }
        set { self[DynamicIslandToastActionKey.self] = newValue }
    }
}

private struct WindowExtractor: UIViewRepresentable {
    var result: (UIWindow) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            if let window = view.window {
                result(window)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { }
}

private final class PassThroughWindow: UIWindow, ObservableObject {
    @Published private(set) var toast: DynamicIslandToast?
    @Published private(set) var isPresented = false

    private weak var toastController: DynamicIslandToastHostingController?
    private var dismissTask: Task<Void, Never>?

    func attachController(_ controller: DynamicIslandToastHostingController) {
        toastController = controller
    }

    func present(_ toast: DynamicIslandToast, duration: TimeInterval = 2.4) {
        guard !isPresented else {
            return
        }

        dismissTask?.cancel()
        self.toast = toast
        isHidden = false
        isPresented = true
        toastController?.isStatusBarHidden = true

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        isPresented = false
        toastController?.isStatusBarHidden = false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        if isPresented,
           hitView == rootView,
           point.y <= 160 {
            return rootView
        }

        return hitView == rootView ? nil : hitView
    }
}

private final class DynamicIslandToastHostingController: UIHostingController<DynamicIslandToastOverlayView> {
    var isStatusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        isStatusBarHidden
    }
}

final class DynamicIslandToastCoordinator {
    static let shared = DynamicIslandToastCoordinator()

    private weak var overlayWindow: PassThroughWindow?

    func configure(from mainWindow: UIWindow) {
        guard let windowScene = mainWindow.windowScene else {
            return
        }

        if let existingWindow = windowScene.windows.first(where: { $0.tag == 1009 }) as? PassThroughWindow {
            overlayWindow = existingWindow
            return
        }

        let overlayWindow = PassThroughWindow(windowScene: windowScene)
        let hostingController = DynamicIslandToastHostingController(
            rootView: DynamicIslandToastOverlayView(window: overlayWindow)
        )

        hostingController.view.backgroundColor = .clear
        overlayWindow.attachController(hostingController)
        overlayWindow.rootViewController = hostingController
        overlayWindow.backgroundColor = .clear
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.isHidden = false
        overlayWindow.isUserInteractionEnabled = true
        overlayWindow.tag = 1009

        self.overlayWindow = overlayWindow
    }

    func show(_ toast: DynamicIslandToast) {
        overlayWindow?.present(toast)
    }
}

private struct DynamicIslandToastViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                WindowExtractor { mainWindow in
                    DynamicIslandToastCoordinator.shared.configure(from: mainWindow)
                }
            }
    }
}

private struct DynamicIslandToastOverlayView: View {
    @ObservedObject var window: PassThroughWindow

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let size = proxy.size
            let isExpanded = window.isPresented
            let hasDynamicIsland = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 126
            let dynamicIslandHeight: CGFloat = 37
            let topOffset: CGFloat = 11 + max(safeArea.top - 59, 0)
            let expandedWidth = min(size.width - 20, 380)
            let expandedHeight: CGFloat = hasDynamicIsland ? 112 : 76
            let contentTopInset: CGFloat = hasDynamicIsland ? 18 : 0
            let contentBottomInset: CGFloat = hasDynamicIsland ? 8 : 0
            let scaleX: CGFloat = isExpanded ? 1 : dynamicIslandWidth / expandedWidth
            let scaleY: CGFloat = isExpanded ? 1 : dynamicIslandHeight / expandedHeight
            let hiddenOffset: CGFloat = hasDynamicIsland ? topOffset : -90
            let presentedOffset: CGFloat = hasDynamicIsland ? topOffset : safeArea.top + 10

            ZStack {
                RoundedRectangle(cornerRadius: isExpanded ? 36 : 28, style: .continuous)
                    .fill(.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: isExpanded ? 36 : 28, style: .continuous)
                            .stroke(.white.opacity(isExpanded ? 0.08 : 0), lineWidth: 1)
                    }
                    .shadow(color: toast.style.tint.opacity(isExpanded ? 0.2 : 0), radius: 18, x: 0, y: 8)
                    .overlay {
                        toastContent
                            .frame(width: expandedWidth, height: expandedHeight)
                            .padding(.top, contentTopInset)
                            .padding(.bottom, contentBottomInset)
                            .scaleEffect(x: scaleX, y: scaleY)
                    }
                    .frame(
                        width: isExpanded ? expandedWidth : dynamicIslandWidth,
                        height: isExpanded ? expandedHeight : dynamicIslandHeight
                    )
                    .offset(y: isExpanded ? presentedOffset : hiddenOffset)
                    .opacity(hasDynamicIsland ? 1 : (isExpanded ? 1 : 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .contentShape(.rect)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height < 0 {
                        window.dismiss()
                    }
                }
            )
            .animation(.bouncy(duration: 0.34, extraBounce: 0), value: isExpanded)
        }
    }

    private var toastContent: some View {
        Group {
            if let toast = window.toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(toast.style.tint)
                        .symbolEffect(.wiggle, options: .default.speed(1.5), value: window.isPresented)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(toast.title)
                            .font(CFTypography.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(toast.message)
                            .font(CFTypography.caption)
                            .foregroundStyle(.white.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity, alignment: .center)
                .compositingGroup()
                .blur(radius: window.isPresented ? 0 : 5)
                .opacity(window.isPresented ? 1 : 0)
                .animation(.linear(duration: 0.02).delay(window.isPresented ? 0.08 : 0), value: window.isPresented)
            }
        }
    }

    private var toast: DynamicIslandToast {
        window.toast ?? .success(message: "")
    }
}

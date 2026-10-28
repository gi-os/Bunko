import SwiftUI
import UIKit

/// The pages, turned by UIPageViewController: a curling leaf (or a slide), a two-page spread
/// bound in the middle on a wide screen, bound on the right for a right-to-left book. Three
/// fingers tap for settings; two fingers pinch the book shut.
struct PageTurner: UIViewControllerRepresentable {
    let model: ReaderModel
    let curl: Bool
    // Passed in so SwiftUI updates the pager when the pages are recut or a jump is asked for.
    var version: Int
    var jump: ReaderModel.Jump?

    func makeCoordinator() -> Coordinator { Coordinator(model: model, curl: curl) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let layout = model.layout
        var options: [UIPageViewController.OptionsKey: Any] = [:]
        if curl {
            let spine: UIPageViewController.SpineLocation = layout.spread ? .mid : (layout.bindingOnRight ? .max : .min)
            options[.spineLocation] = NSNumber(value: spine.rawValue)
        } else {
            options[.interPageSpacing] = 0
        }
        let pager = UIPageViewController(transitionStyle: curl ? .pageCurl : .scroll,
                                         navigationOrientation: .horizontal, options: options)
        pager.isDoubleSided = curl && layout.spread
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = model.settings.paper.color

        let settingsTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.threeFingerTap))
        settingsTap.numberOfTouchesRequired = 3
        pager.view.addGestureRecognizer(settingsTap)
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = context.coordinator
        pager.view.addGestureRecognizer(pinch)

        context.coordinator.pager = pager
        context.coordinator.show(page: model.currentPage)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.sync()
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        let model: ReaderModel
        let curl: Bool
        weak var pager: UIPageViewController?
        private var shownVersion = -1
        private var lastJump: UUID?

        init(model: ReaderModel, curl: Bool) {
            self.model = model
            self.curl = curl
        }

        private var layout: SpreadLayout { model.layout }

        /// Curling, each leaf is its own unit (a spread is two, back to back). Sliding, a unit is
        /// a whole spread.
        private var unitCount: Int { curl ? layout.paddedPageCount : layout.spreadCount }

        /// Going right to left, UIKit's "next" is the book's previous page, except for a single
        /// curling page bound on the right, which UIKit already turns the Japanese way.
        private var reversed: Bool { layout.rightToLeft && (layout.spread || !curl) }

        func controller(unit: Int) -> UnitController? {
            guard unit >= 0, unit < unitCount else { return nil }
            if curl {
                let side: PageRender.Side
                if layout.spread {
                    let screen = layout.pages(inSpread: layout.spreadIndex(ofPage: unit))
                    side = screen.first == unit ? .left : .right
                } else {
                    side = .single
                }
                return UnitController(unit: unit, pages: [(unit, side)], model: model)
            }
            let screen = layout.pages(inSpread: unit)
            let sides: [PageRender.Side] = screen.count == 2 ? [.left, .right] : [.single]
            return UnitController(unit: unit, pages: Array(zip(screen, sides)).map { (page: $0.0, side: $0.1) }, model: model)
        }

        func show(page: Int) {
            guard let pager, layout.pageCount > 0 else { return }
            let controllers: [UnitController]
            if curl && layout.spread {
                controllers = layout.pages(inSpread: layout.spreadIndex(ofPage: page)).compactMap { controller(unit: $0) }
            } else {
                controllers = [controller(unit: curl ? page : layout.spreadIndex(ofPage: page))].compactMap { $0 }
            }
            guard !controllers.isEmpty else { return }
            pager.setViewControllers(controllers, direction: .forward, animated: false)
            shownVersion = model.pagesVersion
        }

        /// SwiftUI changed something: new pages, or a jump (ribbon, contents).
        func sync() {
            if let jump = model.jump, jump.id != lastJump {
                lastJump = jump.id
                show(page: jump.page)
            } else if model.pagesVersion != shownVersion {
                show(page: model.currentPage)
            }
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let unit = (vc as? UnitController)?.unit else { return nil }
            return controller(unit: reversed ? unit + 1 : unit - 1)
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let unit = (vc as? UnitController)?.unit else { return nil }
            return controller(unit: reversed ? unit - 1 : unit + 1)
        }

        func pageViewController(_ pager: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed else { return }
            let units = (pager.viewControllers ?? []).compactMap { ($0 as? UnitController)?.unit }
            guard let first = units.min() else { return }
            let page = curl ? first : (layout.pages(inSpread: first).min() ?? 0)
            model.turned(to: min(page, layout.pageCount - 1))
            // The page edges show how far in you are: redraw the leaves now facing up.
            for case let unitController as UnitController in pager.viewControllers ?? [] {
                unitController.refresh(with: model)
            }
        }

        @objc func threeFingerTap() {
            model.showsSettings = true
        }

        @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .changed:
                model.squeeze = min(1, max(0.35, gesture.scale))
            case .ended, .cancelled, .failed:
                if gesture.scale < 0.72 {
                    if model.settings.haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    withAnimation(.easeInOut(duration: 0.35)) { model.close() }
                } else {
                    withAnimation(.spring(duration: 0.3)) { model.squeeze = 1 }
                }
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer.numberOfTouches >= 2
        }
    }
}

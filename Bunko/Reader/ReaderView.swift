import SwiftUI

/// A book, edge to edge: the screen is the page (or the open spread). No buttons. Pinch to shut
/// it, then swipe the closed book away; three fingers for settings.
struct ReaderView: View {
    @State private var model: ReaderModel
    @Environment(SyncStore.self) private var sync
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(model: ReaderModel) {
        _model = State(initialValue: model)
    }

    private struct LayoutKey: Equatable {
        var size: CGSize
        var settings: ReaderSettings
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(uiColor: sync.settings.paper.color)
                if model.isClosed {
                    ClosedBookView(model: model, cover: sync.cover(for: model.book),
                                   original: library.originalCover(for: model.book)) {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { dismiss() }
                    }
                    .transition(.asymmetric(insertion: .scale(scale: 0.6, anchor: .center).combined(with: .opacity), removal: .opacity))
                } else if let error = model.loadError {
                    Text(error).font(.callout).foregroundStyle(.secondary)
                        .onTapGesture { dismiss() }
                } else if !model.pages.isEmpty {
                    openBook(size: geo.size)
                        .transition(.opacity)
                }
            }
            .task(id: LayoutKey(size: geo.size, settings: sync.settings)) {
                await model.layout(size: geo.size, settings: sync.settings)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $model.showsSettings) {
            SettingsView(reader: model)
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
        }
        .onChange(of: scenePhase) { _, phase in
            // Folding the Duo shut (or locking the phone) closes the book.
            if phase == .background, !model.isClosed { model.close() }
        }
    }

    private func openBook(size: CGSize) -> some View {
        let layout = model.layout
        let ribbonX = layout.spread ? size.width / 2 : (layout.bindingOnRight ? size.width - 17 : 17)
        return ZStack(alignment: .topLeading) {
            PageTurner(model: model, curl: model.settings.turn == .curl, version: model.pagesVersion, jump: model.jump)
                .id("\(model.settings.turn)-\(layout.spread)-\(layout.rightToLeft)")
            RibbonView(color: Color(hex: model.settings.ribbonColor), height: size.height - 6)
                .onTapGesture { model.followRibbon() }
                .onLongPressGesture(minimumDuration: 0.5) { model.moveRibbonHere() }
                .position(x: ribbonX, y: (size.height - 6) / 2)
        }
        // Pinching squeezes the pages toward the spine.
        .scaleEffect(x: model.squeeze, y: 1 - (1 - model.squeeze) * 0.1)
        .opacity(0.4 + 0.6 * Double(model.squeeze))
    }
}

/// The ribbon bookmark (スピン), hanging from the head of the spine past the foot of the page.
struct RibbonView: View {
    let color: Color
    let height: CGFloat

    var body: some View {
        RibbonShape()
            .fill(LinearGradient(colors: [color.opacity(0.95), color], startPoint: .leading, endPoint: .trailing))
            .overlay(RibbonShape().stroke(.black.opacity(0.12), lineWidth: 0.5))
            .frame(width: 6, height: height)
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0.5, y: 0.5)
            .frame(width: 34, height: height)
            .contentShape(Rectangle())
            .accessibilityLabel("Ribbon")
            .accessibilityHint("Tap to go back to the ribbon. Hold to move it to this page.")
    }
}

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The shut book: its paper cover fills the screen, the ribbon's tail out of the bottom. Swipe it
/// away to put it back on the shelf, or spread two fingers to open it again.
struct ClosedBookView: View {
    let model: ReaderModel
    let cover: CoverStyle
    let original: UIImage?
    let putAway: () -> Void

    @State private var drag: CGSize = .zero
    @State private var opening: CGFloat = 1
    @State private var showsHint = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CoverView(style: cover, book: model.book, original: original, large: true)
                RibbonView(color: Color(hex: model.settings.ribbonColor), height: 70)
                    .offset(x: model.book.rightToLeft ? geo.size.width * 0.3 : -geo.size.width * 0.3, y: 40)
                if showsHint {
                    Text("Swipe away to put it back · Spread to open")
                        .font(.caption)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 54)
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(drag == .zero ? 0 : 0.35), radius: 24)
            .scaleEffect(opening)
            .rotationEffect(.degrees(Double(drag.width) / 30))
            .offset(drag)
            .gesture(
                DragGesture()
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        let flung = hypot(value.predictedEndTranslation.width, value.predictedEndTranslation.height)
                        if flung > 260 {
                            let scale = max(geo.size.width, geo.size.height) * 1.6 / max(flung, 1)
                            withAnimation(.easeIn(duration: 0.25)) {
                                drag = CGSize(width: value.predictedEndTranslation.width * scale,
                                              height: value.predictedEndTranslation.height * scale)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { putAway() }
                        } else {
                            withAnimation(.spring(duration: 0.35)) { drag = .zero }
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { opening = max(1, min(1.3, $0.magnification)) }
                    .onEnded { value in
                        if value.magnification > 1.12 {
                            withAnimation(.easeInOut(duration: 0.35)) { model.open() }
                        }
                        withAnimation(.spring(duration: 0.3)) { opening = 1 }
                    }
            )
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.6)) { showsHint = false }
        }
    }
}

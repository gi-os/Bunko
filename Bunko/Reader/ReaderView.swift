import SwiftUI

/// A book, edge to edge: the screen is the page (or the open spread). It opens on its cover; tap
/// the cover and it swings open on its spine. No buttons. Pinch to shut it, then swipe the closed
/// book away; three fingers for settings.
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
                // The first page waits under the cover, so opening reveals it.
                if let error = model.loadError, !model.isClosed {
                    Text(error).font(.callout).foregroundStyle(.secondary)
                        .onTapGesture { dismiss() }
                } else if !model.pages.isEmpty {
                    openBook(size: geo.size)
                        .allowsHitTesting(!model.isClosed)
                }
                if model.isClosed {
                    ClosedBookView(model: model, cover: sync.cover(for: model.book),
                                   original: library.originalCover(for: model.book)) {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { dismiss() }
                    }
                    .transition(.asymmetric(insertion: .scale(scale: 0.6, anchor: .center).combined(with: .opacity), removal: .identity))
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
            if model.hasRibbon {
                RibbonView(color: Color(hex: model.settings.ribbonColor), height: size.height - 6)
                    .onTapGesture { model.tapRibbon() }
                    .onLongPressGesture(minimumDuration: 0.5) { model.moveRibbonHere() }
                    .position(x: ribbonX, y: (size.height - 6) / 2)
            } else {
                // Where the ribbon would lie: tap the gutter to lay it in this page.
                Color.clear
                    .frame(width: 34, height: size.height - 6)
                    .contentShape(Rectangle())
                    .onTapGesture { model.layRibbonHere() }
                    .position(x: ribbonX, y: (size.height - 6) / 2)
                    .accessibilityElement()
                    .accessibilityLabel("Ribbon")
                    .accessibilityHint("Tap to lay the ribbon in this page.")
                    .accessibilityAddTraits(.isButton)
            }
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
            .accessibilityHint("Tap to go back to the ribbon, or on its own page to take it out. Hold to move it to this page.")
    }
}

/// The shut book: its paper cover fills the screen but for the page block showing past its
/// fore-edge and foot, the obi round its foot. Tap (or spread two fingers) and the cover board
/// swings open on its spine, the block staying put; swipe the book away to put it back on the shelf.
struct ClosedBookView: View {
    let model: ReaderModel
    let cover: CoverStyle
    let original: UIImage?
    let putAway: () -> Void

    @State private var drag: CGSize = .zero
    @State private var swing: Double = 0
    @State private var showsHint = true

    private var japanese: Bool { model.book.rightToLeft || model.book.language.hasPrefix("ja") }

    /// How much of the page block shows past the cover, in points.
    private let depth: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let spineOnRight = model.book.rightToLeft
            ZStack(alignment: .bottom) {
                PageBlock(spineOnRight: spineOnRight, depth: depth)
                CoverView(style: cover, book: model.book, original: original, large: true,
                          wear: model.progress.wear, obi: Obi.closed(model.progress, japanese: japanese))
                    // The board's own edge, catching the light at the fore-edge as it swings.
                    .overlay(alignment: spineOnRight ? .leading : .trailing) {
                        LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.06)],
                                       startPoint: spineOnRight ? .leading : .trailing, endPoint: spineOnRight ? .trailing : .leading)
                            .frame(width: 3)
                    }
                    .padding(spineOnRight ? .leading : .trailing, depth)
                    .padding(.bottom, depth)
                    // Opening: the cover turns on the spine (the right edge for a Japanese book).
                    .rotation3DEffect(.degrees(swing * (spineOnRight ? 100 : -100)), axis: (x: 0, y: 1, z: 0),
                                      anchor: spineOnRight ? .trailing : .leading, perspective: 0.45)
                if showsHint {
                    Text("Tap to open · Swipe away to put it back")
                        .font(.caption)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .center)
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(drag == .zero && swing == 0 ? 0 : 0.35), radius: 24)
            .rotationEffect(.degrees(Double(drag.width) / 30))
            .offset(drag)
            .contentShape(Rectangle())
            .onTapGesture { openCover() }
            .gesture(
                DragGesture(minimumDistance: 12)
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
                    .onEnded { value in if value.magnification > 1.12 { openCover() } }
            )
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.6)) { showsHint = false }
        }
    }

    private func openCover() {
        guard swing == 0, drag == .zero else { return }
        if model.settings.haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        withAnimation(.easeIn(duration: 0.45)) { swing = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.open() }
        }
    }
}

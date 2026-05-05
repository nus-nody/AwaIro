import AwaIroDomain
import AwaIroPresentation
import SwiftUI

struct RootContentView: View {
  let container: AppContainer
  @State private var path: [AppRoute] = []
  @State private var paletteSheetPresented = false
  @Environment(\.colorScheme) private var systemColorScheme

  var body: some View {
    let theme = SkyTheme(
      palette: container.themeStore.palette,
      mode: container.themeStore.mode,
      systemColorScheme: systemColorScheme
    )

    NavigationStack(path: $path) {
      HomeScreen(
        viewModel: container.makeHomeViewModel(),
        camera: container.camera,
        onCaptured: { url, takenAt in
          path.append(.memo(fileURL: url, takenAt: takenAt))
        },
        onTapGallery: { path.append(.gallery) },
        onTapMenu: { paletteSheetPresented = true }
      )
      .navigationBarHidden(true)
      .navigationDestination(for: AppRoute.self) { route in
        destinationView(for: route)
      }
    }
    .environment(\.skyTheme, theme)
    .preferredColorScheme(
      theme.mode == .system ? nil : (theme.mode == .dark ? .dark : .light)
    )
    .task {
      await container.themeStore.load()
    }
    .sheet(isPresented: $paletteSheetPresented) {
      PaletteSheet(
        selectedPalette: container.themeStore.palette,
        selectedMode: container.themeStore.mode,
        onPickPalette: { p in Task { await container.themeStore.setPalette(p) } },
        onPickMode: { m in Task { await container.themeStore.setMode(m) } }
      )
      .skyTheme(theme)
      .presentationDetents([.medium])
    }
  }

  @ViewBuilder
  private func destinationView(for route: AppRoute) -> some View {
    switch route {
    case .memo(let fileURL, let takenAt):
      MemoScreen(
        viewModel: container.makeMemoViewModel(fileURL: fileURL, takenAt: takenAt),
        onFinished: { path.removeAll() }
      )
      .navigationBarHidden(true)

    case .gallery:
      GalleryScreen(
        viewModel: container.makeGalleryViewModel(),
        onTapPhoto: { id in path.append(.photoDetail(photoId: id)) },
        onTapBack: { path.removeLast() },
        onTapMenu: { paletteSheetPresented = true }
      )
      .navigationBarHidden(true)

    case .photoDetail(let id):
      PhotoDetailRoute(container: container, photoId: id)
        .navigationBarHidden(true)
    }
  }
}

/// Loader view that fetches the developed photo list + opens PhotoDetailScreen at the right initial id.
private struct PhotoDetailRoute: View {
  let container: AppContainer
  let photoId: UUID
  @State private var photos: [Photo] = []
  @State private var loaded = false

  var body: some View {
    Group {
      if loaded, !photos.isEmpty {
        PhotoDetailScreen(
          photos: photos,
          initialPhotoId: photoId,
          updateMemoFactory: { photo in container.makePhotoDetailViewModel(photo: photo) }
        )
      } else {
        ProgressView().tint(.white)
      }
    }
    .task {
      do {
        let all = try await container.developPhotoUseCase.execute()
        // Show only developed photos (G2 — undeveloped should not be reachable, but defensive)
        let now = Date()
        photos = all.filter { $0.isDeveloped(now: now) }
        loaded = true
      } catch {
        loaded = true
      }
    }
  }
}

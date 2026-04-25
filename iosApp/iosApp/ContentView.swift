import SwiftUI
import ComposeApp

#if canImport(UIKit)
import UIKit

struct ContentView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#else
struct ContentView: View {
    var body: some View {
        Text("UIKit is unavailable in this build environment.")
    }
}
#endif

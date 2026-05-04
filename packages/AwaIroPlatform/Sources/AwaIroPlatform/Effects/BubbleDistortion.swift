import SwiftUI

#if canImport(UIKit)
  extension View {
    /// Applies a sphere/bubble distortion to the receiving view, centered
    /// inside a circle of the given radius. Outside the circle, content
    /// passes through unchanged.
    public func bubbleDistortion(radius: CGFloat, strength: Float = 0.4) -> some View {
      self
        .visualEffect { content, proxy in
          content.layerEffect(
            ShaderLibrary.bundle(.module).bubbleDistortion(
              .float2(proxy.size),
              .float(Float(radius)),
              .float(strength)
            ),
            maxSampleOffset: CGSize(width: radius, height: radius)
          )
        }
    }
  }
#endif

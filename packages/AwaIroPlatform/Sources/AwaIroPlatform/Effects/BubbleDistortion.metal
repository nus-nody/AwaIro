#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Sphere distortion: maps a circular region centered at the layer's
/// midpoint with the given radius to a refracted bubble-like view.
/// Outside the circle: passes through unchanged.
/// Inside: applies a barrel distortion proportional to distance from center.
[[ stitchable ]] half4 bubbleDistortion(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float radius,
    float strength
) {
    float2 center = size * 0.5;
    float2 toCenter = position - center;
    float dist = length(toCenter);

    if (dist >= radius) {
        return layer.sample(position);
    }

    // Normalized distance in [0..1]
    float u = dist / radius;
    // Barrel distortion: sample a point closer to center near the rim
    float displaceFactor = strength * (1.0 - u * u);
    float2 sampled = center + toCenter * (1.0 - displaceFactor);

    return layer.sample(sampled);
}

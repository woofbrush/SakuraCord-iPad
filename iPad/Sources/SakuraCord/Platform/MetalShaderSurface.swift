import AppKitShim
import Metal
import MetalKit

/// Draws the app's SwiftUI color-effect shaders. SwiftUI needs them precompiled
/// into a metallib, and this project is built without the Metal compiler, so the
/// same MSL source is compiled on the device and drawn in a Metal view.
struct MetalShaderSurface: UIViewRepresentable {
    let function: String
    let elapsed: TimeInterval
    let colors: [Color]
    let scalar: Double
    var base: Color = .white

    func makeUIView(context _: Context) -> SurfaceView { SurfaceView(function: function) }

    func updateUIView(_ view: SurfaceView, context _: Context) {
        view.update(elapsed: elapsed, colors: colors, scalar: scalar, base: base)
    }

    final class SurfaceView: MTKView {
        private struct Uniforms {
            var size = SIMD2<Float>(1, 1)
            var time: Float = 0
            var scalar: Float = 0
            var base = SIMD4<Float>(1, 1, 1, 1)
            var first = SIMD4<Float>(1, 1, 1, 1)
            var middle = SIMD4<Float>(1, 1, 1, 1)
            var last = SIMD4<Float>(1, 1, 1, 1)
        }

        private var uniforms = Uniforms()
        private var pipeline: (any MTLRenderPipelineState)?
        private var queue: (any MTLCommandQueue)?

        init(function: String) {
            super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
            isPaused = true
            enableSetNeedsDisplay = true
            isOpaque = false
            backgroundColor = .clear
            clearColor = MTLClearColorMake(0, 0, 0, 0)
            colorPixelFormat = .bgra8Unorm
            isUserInteractionEnabled = false
            guard let device else { return }
            let library = try? device.makeLibrary(source: Self.source(for: function), options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library?.makeFunction(name: "surfaceVertex")
            descriptor.fragmentFunction = library?.makeFunction(name: "surfaceFragment")
            descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
            pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
            queue = device.makeCommandQueue()
        }

        required init(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

        private static func source(for function: String) -> String {
            let call = function == "sakuraSignInLight"
                ? "sakuraSignInLight(position, base, bounds, u.time, half4(u.first), half4(u.middle), half4(u.last), u.scalar)"
                : "sakuraAuthenticationLoading(position, base, bounds, u.time, half4(u.first), half4(u.last), u.scalar)"
            return SakuraMetalSources.signInLight + """

            struct SurfaceUniforms { float2 size; float time; float scalar; float4 base; float4 first; float4 middle; float4 last; };
            struct SurfaceVarying { float4 position [[position]]; float2 uv; };

            vertex SurfaceVarying surfaceVertex(uint id [[vertex_id]]) {
                float2 uv = float2((id << 1) & 2, id & 2);
                return { float4(uv * float2(2, -2) + float2(-1, 1), 0, 1), uv };
            }

            fragment half4 surfaceFragment(SurfaceVarying in [[stage_in]], constant SurfaceUniforms &u [[buffer(0)]]) {
                float2 position = in.uv * u.size;
                float4 bounds = float4(0, 0, u.size);
                half4 base = half4(u.base);
                return \(call);
            }
            """
        }

        func update(elapsed: TimeInterval, colors: [Color], scalar: Double, base: Color) {
            uniforms.size = SIMD2(Float(bounds.width), Float(bounds.height))
            uniforms.time = Float(elapsed)
            uniforms.scalar = Float(scalar)
            uniforms.base = components(base)
            uniforms.first = components(colors.first ?? .white)
            uniforms.middle = components(colors[colors.count / 2])
            uniforms.last = components(colors.last ?? .white)
            setNeedsDisplay()
        }

        private func components(_ color: Color) -> SIMD4<Float> {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD4(Float(r), Float(g), Float(b), Float(a))
        }

        override func draw(_: CGRect) {
            guard let pipeline, let queue, let drawable = currentDrawable,
                  let pass = currentRenderPassDescriptor,
                  let buffer = queue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
            else { return }
            uniforms.size = SIMD2(Float(bounds.width), Float(bounds.height))
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }
    }
}

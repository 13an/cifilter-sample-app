//import SwiftUI
//import CoreImage
//import CoreImage.CIFilterBuiltins
//
//struct ContentView: View {
//    @State private var image: UIImage?
//    @State private var showingImagePicker = false
//    @State private var processedImage: UIImage?
//    @State private var filterSettings = FilterSettings()
//
//    let context = CIContext()
//
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 0) {
//                // プレビュー部分（固定）
//                VStack {
//                    if let image = processedImage {
//                        Image(uiImage: image)
//                            .resizable()
//                            .scaledToFit()
//                            .padding()
//                    } else {
//                        Image(systemName: "photo")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(height: 300)
//                            .padding()
//                            .foregroundColor(.gray)
//                    }
//                }
//                .frame(height: UIScreen.main.bounds.height * 0.4)
//                .background(Color(uiColor: .systemBackground))
//
//                // スライダー部分（スクロール可能）
//                ScrollView {
//                    VStack(spacing: 20) {
//                        FilterSlider(value: $filterSettings.brightness, range: -1...1, title: "明るさ")
//                            .onChange(of: filterSettings.brightness) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.contrast, range: 0.5...1.5, title: "コントラスト")
//                            .onChange(of: filterSettings.contrast) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.saturation, range: 0...2, title: "彩度")
//                            .onChange(of: filterSettings.saturation) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.temperature, range: -1...1, title: "色温度")
//                            .onChange(of: filterSettings.temperature) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.tint, range: -1...1, title: "色合い")
//                            .onChange(of: filterSettings.tint) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.grain, range: 0...1, title: "グレイン")
//                            .onChange(of: filterSettings.grain) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.vignette, range: 0...1, title: "ビネット")
//                            .onChange(of: filterSettings.vignette) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.sepia, range: 0...1, title: "セピア")
//                            .onChange(of: filterSettings.sepia) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.chromaticAberration, range: 0...10, title: "色収差")
//                            .onChange(of: filterSettings.chromaticAberration) { _ in processImage() }
//
//                        FilterSlider(value: $filterSettings.blur, range: 0...20, title: "ぼかし")
//                            .onChange(of: filterSettings.blur) { _ in processImage() }
//                    }
//                    .padding()
//                }
//            }
//            .navigationTitle("Film Camera")
//            .toolbar {
//                Button("写真を選択") {
//                    showingImagePicker = true
//                }
//            }
//        }
//        .onChange(of: image) { _ in
//            processImage()
//        }
//        .sheet(isPresented: $showingImagePicker) {
//            ImagePicker(image: $image)
//        }
//    }
//
//    func processImage() {
//        guard let inputImage = image,
//              let ciImage = CIImage(image: inputImage) else { return }
//
//        let filters = ImageProcessor(context: context)
//        if let processedCIImage = filters.applyFilters(to: ciImage, settings: filterSettings) {
//            processedImage = UIImage(cgImage: processedCIImage)
//        }
//    }
//}
//
//// フィルター設定を保持する構造体
//struct FilterSettings {
//    var brightness: Double = 0.0
//    var contrast: Double = 1.0
//    var saturation: Double = 1.0
//    var temperature: Double = 0.0
//    var tint: Double = 0.0
//    var grain: Double = 0.0
//    var vignette: Double = 0.0
//    var sepia: Double = 0.0
//    var chromaticAberration: Double = 0.0
//    var blur: Double = 0.0
//}
//
//// 画像処理を担当するクラス
//class ImageProcessor {
//    let context: CIContext
//
//    init(context: CIContext) {
//        self.context = context
//    }
//
//    func applyFilters(to inputImage: CIImage, settings: FilterSettings) -> CGImage? {
//        var currentImage = inputImage
//
//        // 明るさ、コントラスト、彩度
//        let colorControl = CIFilter.colorControls()
//        colorControl.inputImage = currentImage
//        colorControl.brightness = Float(settings.brightness)
//        colorControl.contrast = Float(settings.contrast)
//        colorControl.saturation = Float(settings.saturation)
//        if let output = colorControl.outputImage {
//            currentImage = output
//        }
//
//        // 色温度と色合い
//        let temperatureAndTint = CIFilter.temperatureAndTint()
//        temperatureAndTint.inputImage = currentImage
//        temperatureAndTint.neutral = CIVector(x: 6500 + (1000 * settings.temperature),
//                                            y: 0 + (500 * settings.tint))
//        temperatureAndTint.targetNeutral = CIVector(x: 6500, y: 0)
//        if let output = temperatureAndTint.outputImage {
//            currentImage = output
//        }
//
//        // 色収差
//        if settings.chromaticAberration > 0 {
//            let offset = settings.chromaticAberration
//
//            // 赤チャンネル
//            let redFilter = CIFilter.colorMatrix()
//            redFilter.inputImage = currentImage
//            redFilter.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
//            redFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            redFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            redFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
//            let redChannel = redFilter.outputImage?.transformed(by: CGAffineTransform(translationX: CGFloat(offset), y: 0))
//
//            // 青チャンネル
//            let blueFilter = CIFilter.colorMatrix()
//            blueFilter.inputImage = currentImage
//            blueFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            blueFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            blueFilter.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
//            blueFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
//            let blueChannel = blueFilter.outputImage?.transformed(by: CGAffineTransform(translationX: CGFloat(-offset), y: 0))
//
//            // 緑チャンネル
//            let greenFilter = CIFilter.colorMatrix()
//            greenFilter.inputImage = currentImage
//            greenFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            greenFilter.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
//            greenFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
//            greenFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
//            let greenChannel = greenFilter.outputImage
//
//            // チャンネルを合成（新しい方法）
//            if let red = redChannel,
//               let green = greenChannel,
//               let blue = blueChannel {
//
//                // RGB チャンネルを個別に合成するためのフィルター
//                let maximumCompositingFilter = CIFilter(name: "CIMaximumCompositing")
//
//                // まず赤と緑を合成
//                maximumCompositingFilter?.setValue(red, forKey: kCIInputImageKey)
//                maximumCompositingFilter?.setValue(green, forKey: kCIInputBackgroundImageKey)
//                let redGreenComposite = maximumCompositingFilter?.outputImage
//
//                // 次に青を合成
//                maximumCompositingFilter?.setValue(blue, forKey: kCIInputImageKey)
//                maximumCompositingFilter?.setValue(redGreenComposite, forKey: kCIInputBackgroundImageKey)
//
//                if let output = maximumCompositingFilter?.outputImage {
//                    // 全体の明るさを適切に調整
//                    let brightnessFilter = CIFilter.colorControls()
//                    brightnessFilter.inputImage = output
//                    brightnessFilter.brightness = -0.1 // わずかに暗めに調整
//                    brightnessFilter.contrast = 1.1    // コントラストをわずかに上げる
//
//                    if let adjustedOutput = brightnessFilter.outputImage {
//                        currentImage = adjustedOutput
//                    }
//                }
//            }
//        }
//
//        // ぼかし
//        if settings.blur > 0 {
//            let gaussianBlur = CIFilter.gaussianBlur()
//            gaussianBlur.inputImage = currentImage
//            gaussianBlur.radius = Float(settings.blur)
//
//            if let output = gaussianBlur.outputImage {
//                // エッジのぼかしを防ぐために、元の画像サイズにクロップ
//                let cropRect = currentImage.extent
//                currentImage = output.cropped(to: cropRect)
//            }
//        }
//
//        // グレイン
//        if settings.grain > 0 {
//            let noise = CIFilter.randomGenerator()
//            guard let noiseImage = noise.outputImage else { return nil }
//
//            let grainImage = noiseImage.applyingFilter("CIColorMatrix", parameters: [
//                "inputRVector": CIVector(x: settings.grain, y: 0, z: 0, w: 0),
//                "inputGVector": CIVector(x: 0, y: settings.grain, z: 0, w: 0),
//                "inputBVector": CIVector(x: 0, y: 0, z: settings.grain, w: 0)
//            ])
//
//            let blend = CIFilter.sourceOverCompositing()
//            blend.inputImage = grainImage
//            blend.backgroundImage = currentImage
//            if let output = blend.outputImage {
//                currentImage = output
//            }
//        }
//
//        // ビネット
//        if settings.vignette > 0 {
//            let vignette = CIFilter.vignette()
//            vignette.inputImage = currentImage
//            vignette.intensity = Float(settings.vignette)
//            vignette.radius = Float(settings.vignette * 2)
//            if let output = vignette.outputImage {
//                currentImage = output
//            }
//        }
//
//        // セピア
//        if settings.sepia > 0 {
//            let sepia = CIFilter.sepiaTone()
//            sepia.inputImage = currentImage
//            sepia.intensity = Float(settings.sepia)
//            if let output = sepia.outputImage {
//                currentImage = output
//            }
//        }
//
//        return context.createCGImage(currentImage, from: currentImage.extent)
//    }
//}
//
//struct FilterSlider: View {
//    @Binding var value: Double
//    let range: ClosedRange<Double>
//    let title: String
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text(title)
//                .font(.headline)
//            HStack {
//                Slider(value: $value, in: range)
//                Text(String(format: "%.2f", value))
//                    .frame(width: 50)
//            }
//        }
//    }
//}
//
//struct ImagePicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    @Environment(\.presentationMode) var presentationMode
//
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//        let parent: ImagePicker
//
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//            if let uiImage = info[.originalImage] as? UIImage {
//                parent.image = uiImage
//            }
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//    }
//}

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var cameraModel = CameraModel()
    @State private var filterSettings = FilterSettings()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // カメラプレビュー部分（固定）
                ZStack {
                    CameraPreview(session: cameraModel.session)
                        .frame(height: UIScreen.main.bounds.height * 0.4)

                    if let processedImage = cameraModel.processedPreview {
                        Image(uiImage: processedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: UIScreen.main.bounds.height * 0.4)
                    }
                }
                .background(Color.black)

                // スライダー部分（スクロール可能）
                ScrollView {
                    VStack(spacing: 20) {
                        FilterSlider(value: $filterSettings.brightness, range: -1...1, title: "明るさ")
                            .onChange(of: filterSettings.brightness) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.contrast, range: 0.5...1.5, title: "コントラスト")
                            .onChange(of: filterSettings.contrast) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.saturation, range: 0...2, title: "彩度")
                            .onChange(of: filterSettings.saturation) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.temperature, range: -1...1, title: "色温度")
                            .onChange(of: filterSettings.temperature) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.tint, range: -1...1, title: "色合い")
                            .onChange(of: filterSettings.tint) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.grain, range: 0...1, title: "グレイン")
                            .onChange(of: filterSettings.grain) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.vignette, range: 0...1, title: "ビネット")
                            .onChange(of: filterSettings.vignette) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.sepia, range: 0...1, title: "セピア")
                            .onChange(of: filterSettings.sepia) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.chromaticAberration, range: 0...10, title: "色収差")
                            .onChange(of: filterSettings.chromaticAberration) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.blur, range: 0...20, title: "ぼかし")
                            .onChange(of: filterSettings.blur) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.sparkle, range: 0...1, title: "キラキラ")
                            .onChange(of: filterSettings.sparkle) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.monoNoise, range: 0...1, title: "モノクロノイズ")
                            .onChange(of: filterSettings.monoNoise) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.colorNoise, range: 0...1, title: "カラーノイズ")
                            .onChange(of: filterSettings.colorNoise) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }

                        FilterSlider(value: $filterSettings.dustNoise, range: 0...1, title: "ダスト＆スクラッチ")
                            .onChange(of: filterSettings.dustNoise) { _ in
                                cameraModel.updateFilter(settings: filterSettings)
                            }
                    }
                    .padding()
                }
            }
            .navigationTitle("Film Camera")
            .toolbar {
                Button(action: {
                    cameraModel.capturePhoto(settings: filterSettings)
                }) {
                    Image(systemName: "camera")
                }
            }
        }
        .onAppear {
            cameraModel.checkPermissions()
        }
    }
}

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var processedPreview: UIImage?
    let context = CIContext()
    let imageProcessor = ImageProcessor(context: CIContext())
    private var videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var currentFilterSettings = FilterSettings()
    private var randomSeed: Double = 0

    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()

            // カメラ入力の設定
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            // ビデオ出力の設定
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            // 写真出力の設定
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func updateFilter(settings: FilterSettings) {
        currentFilterSettings = settings
        randomSeed += Double.random(in: 0.1...0.3)  // ここでも randomSeed を更新

        // スライダー操作時のプレビュー更新でも randomSeed を渡す
        if let currentPreview = processedPreview,
           let ciImage = CIImage(image: currentPreview),
           let processedCGImage = imageProcessor.applyFilters(to: ciImage,
                                                            settings: settings,
                                                            randomSeed: randomSeed) {
            processedPreview = UIImage(cgImage: processedCGImage)
        }
    }

    func capturePhoto(settings: FilterSettings) {
        let photoSettings = AVCapturePhotoSettings()
        // 写真撮影時も randomSeed を渡す
        photoOutput.capturePhoto(with: photoSettings,
                               delegate: PhotoCaptureDelegate(settings: settings,
                                                            randomSeed: randomSeed,
                                                            imageProcessor: imageProcessor))
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        // 毎フレーム randomSeed を更新
        randomSeed += Double.random(in: 0.1...0.3)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let processedCGImage = self.imageProcessor.applyFilters(
                to: ciImage,
                settings: self.currentFilterSettings,
                randomSeed: self.randomSeed  // randomSeed を渡す
            ) {
                self.processedPreview = UIImage(cgImage: processedCGImage)
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let settings: FilterSettings
    let randomSeed: Double
    let imageProcessor: ImageProcessor

    init(settings: FilterSettings, randomSeed: Double, imageProcessor: ImageProcessor) {
        self.settings = settings
        self.randomSeed = randomSeed
        self.imageProcessor = imageProcessor
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData),
              let ciImage = CIImage(image: uiImage) else {
            return
        }

        if let processedCGImage = imageProcessor.applyFilters(to: ciImage,
                                                            settings: settings,
                                                            randomSeed: randomSeed) {
            let processedImage = UIImage(cgImage: processedCGImage)
            UIImageWriteToSavedPhotosAlbum(processedImage, nil, nil, nil)
        }
    }
}

// FilterSettings 構造体と ImageProcessor クラスは前回と同じ

// フィルター設定を保持する構造体
struct FilterSettings {
    var brightness: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var temperature: Double = 0.0
    var tint: Double = 0.0
    var grain: Double = 0.0
    var vignette: Double = 0.0
    var sepia: Double = 0.0
    var chromaticAberration: Double = 0.0
    var blur: Double = 0.0
    var sparkle: Double = 0.0
    var monoNoise: Double = 0.0
    var colorNoise: Double = 0.0
    var dustNoise: Double = 0.0
}

// 画像処理を担当するクラス
class ImageProcessor {
    let context: CIContext
    private var frameCount: UInt64 = 0

    init(context: CIContext) {
        self.context = context
    }

    func applyFilters(to inputImage: CIImage, settings: FilterSettings, randomSeed: Double) -> CGImage? {
        var currentImage = inputImage

        // 明るさ、コントラスト、彩度
        let colorControl = CIFilter.colorControls()
        colorControl.inputImage = currentImage
        colorControl.brightness = Float(settings.brightness)
        colorControl.contrast = Float(settings.contrast)
        colorControl.saturation = Float(settings.saturation)
        if let output = colorControl.outputImage {
            currentImage = output
        }

        // 色温度と色合い
        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = currentImage
        temperatureAndTint.neutral = CIVector(x: 6500 + (1000 * settings.temperature),
                                            y: 0 + (500 * settings.tint))
        temperatureAndTint.targetNeutral = CIVector(x: 6500, y: 0)
        if let output = temperatureAndTint.outputImage {
            currentImage = output
        }

        // 色収差
        if settings.chromaticAberration > 0 {
            let offset = settings.chromaticAberration

            // 赤チャンネル
            let redFilter = CIFilter.colorMatrix()
            redFilter.inputImage = currentImage
            redFilter.rVector = CIVector(x: 1, y: 0, z: 0, w: 0)
            redFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            redFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            redFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            let redChannel = redFilter.outputImage?.transformed(by: CGAffineTransform(translationX: CGFloat(offset), y: 0))

            // 青チャンネル
            let blueFilter = CIFilter.colorMatrix()
            blueFilter.inputImage = currentImage
            blueFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            blueFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            blueFilter.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
            blueFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            let blueChannel = blueFilter.outputImage?.transformed(by: CGAffineTransform(translationX: CGFloat(-offset), y: 0))

            // 緑チャンネル
            let greenFilter = CIFilter.colorMatrix()
            greenFilter.inputImage = currentImage
            greenFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            greenFilter.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
            greenFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            greenFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            let greenChannel = greenFilter.outputImage

            // チャンネルを合成（新しい方法）
            if let red = redChannel,
               let green = greenChannel,
               let blue = blueChannel {

                // RGB チャンネルを個別に合成するためのフィルター
                let maximumCompositingFilter = CIFilter(name: "CIMaximumCompositing")

                // まず赤と緑を合成
                maximumCompositingFilter?.setValue(red, forKey: kCIInputImageKey)
                maximumCompositingFilter?.setValue(green, forKey: kCIInputBackgroundImageKey)
                let redGreenComposite = maximumCompositingFilter?.outputImage

                // 次に青を合成
                maximumCompositingFilter?.setValue(blue, forKey: kCIInputImageKey)
                maximumCompositingFilter?.setValue(redGreenComposite, forKey: kCIInputBackgroundImageKey)

                if let output = maximumCompositingFilter?.outputImage {
                    // 全体の明るさを適切に調整
                    let brightnessFilter = CIFilter.colorControls()
                    brightnessFilter.inputImage = output
                    brightnessFilter.brightness = -0.1 // わずかに暗めに調整
                    brightnessFilter.contrast = 1.1    // コントラストをわずかに上げる

                    if let adjustedOutput = brightnessFilter.outputImage {
                        currentImage = adjustedOutput
                    }
                }
            }
        }

        // ぼかし
        if settings.blur > 0 {
            let gaussianBlur = CIFilter.gaussianBlur()
            gaussianBlur.inputImage = currentImage
            gaussianBlur.radius = Float(settings.blur)

            if let output = gaussianBlur.outputImage {
                // エッジのぼかしを防ぐために、元の画像サイズにクロップ
                let cropRect = currentImage.extent
                currentImage = output.cropped(to: cropRect)
            }
        }

        // グレイン
        if settings.grain > 0 {
            let noise = CIFilter.randomGenerator()
            guard let noiseImage = noise.outputImage else { return nil }

            let grainImage = noiseImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: settings.grain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: settings.grain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: settings.grain, w: 0)
            ])

            let blend = CIFilter.sourceOverCompositing()
            blend.inputImage = grainImage
            blend.backgroundImage = currentImage
            if let output = blend.outputImage {
                currentImage = output
            }
        }

        // ビネット
        if settings.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = currentImage
            vignette.intensity = Float(settings.vignette)
            vignette.radius = Float(settings.vignette * 2)
            if let output = vignette.outputImage {
                currentImage = output
            }
        }

        // セピア
        if settings.sepia > 0 {
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = currentImage
            sepia.intensity = Float(settings.sepia)
            if let output = sepia.outputImage {
                currentImage = output
            }
        }

        // キラキラエフェクト
        // ImageProcessor の applyFilters メソッド内のキラキラエフェクト処理を修正
        if settings.sparkle > 0 {
            let originalImage = currentImage

            // 明るい部分の抽出
            let threshold = CIFilter.colorThreshold()
            threshold.inputImage = currentImage
            threshold.threshold = Float(max(0.7, 1.0 - (settings.sparkle * 0.2)))

            if let thresholdOutput = threshold.outputImage {
                // マスクのブラー範囲を最小限に
                let blur = CIFilter.gaussianBlur()
                blur.inputImage = thresholdOutput
                blur.radius = Float(2 + (settings.sparkle * 2)) // ブラーを控えめに

                if let mask = blur.outputImage {
                    // 明るい部分の強調
                    let highlights = CIFilter.colorControls()
                    highlights.inputImage = originalImage
                    highlights.brightness = Float(settings.sparkle * 0.7) // 明るさを強く
                    highlights.contrast = 1.8 // コントラストを強く
                    highlights.saturation = 1.2

                    if let highlightImage = highlights.outputImage {
                        // キラキラ効果（pixellateを使用）
                        let sparkleFilter = CIFilter.pixellate()
                        sparkleFilter.inputImage = highlightImage
                        sparkleFilter.center = CGPoint(x: highlightImage.extent.midX, y: highlightImage.extent.midY)
                        sparkleFilter.scale = Float(10 + (settings.sparkle * 30))

                        if let sparkleOutput = sparkleFilter.outputImage {
                            // シャープネスを追加
                            let sharpen = CIFilter.sharpenLuminance()
                            sharpen.inputImage = sparkleOutput
                            sharpen.sharpness = Float(settings.sparkle * 0.5)

                            let sharpened = sharpen.outputImage ?? sparkleOutput

                            // マスクを使って効果を制限
                            let blend = CIFilter.blendWithMask()
                            blend.inputImage = sharpened
                            blend.backgroundImage = originalImage
                            blend.maskImage = mask

                            if let maskedOutput = blend.outputImage {
                                // 最終的なブレンド
                                let finalBlend = CIFilter.screenBlendMode()
                                finalBlend.inputImage = maskedOutput
                                finalBlend.backgroundImage = originalImage

                                if let output = finalBlend.outputImage {
                                    currentImage = output
                                }
                            }
                        }
                    }
                }
            }
        }

        // ImageProcessor クラスのノイズ処理部分を修正
        if settings.monoNoise > 0 || settings.colorNoise > 0 || settings.dustNoise > 0 {
            // ノイズのベースとなる画像サイズを制限
            let baseNoiseScale = min(currentImage.extent.width, currentImage.extent.height) / 4
            let baseNoiseRect = CGRect(x: 0, y: 0, width: baseNoiseScale, height: baseNoiseScale)

            // モノクロノイズ
            if settings.monoNoise > 0 {
                let noise = CIFilter.randomGenerator()

                if var noiseOutput = noise.outputImage?.cropped(to: baseNoiseRect) {
                    // ノイズを画像サイズに合わせて拡大
                    let scale = max(currentImage.extent.width, currentImage.extent.height) / baseNoiseScale
                    noiseOutput = noiseOutput.transformed(by: .init(scaleX: scale, y: scale))

                    let monoNoiseImage = noiseOutput.applyingFilter("CIColorMatrix", parameters: [
                        "inputRVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                        "inputGVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                        "inputBVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: settings.monoNoise * 0.05)
                    ])

                    let blend = CIFilter.overlayBlendMode()
                    blend.inputImage = monoNoiseImage.cropped(to: currentImage.extent)
                    blend.backgroundImage = currentImage
                    if let output = blend.outputImage {
                        currentImage = output
                    }
                }
            }

            // カラーノイズ
            if settings.colorNoise > 0 {
                let noiseRect = currentImage.extent

                // 異なるシード値を生成
                let redSeed = randomSeed
                let greenSeed = randomSeed + 1000
                let blueSeed = randomSeed + 2000

                // RGB各色のノイズを個別に生成
                let redDots = generateNoise(rect: noiseRect,
                                          scale: Float(5 + (settings.colorNoise * 5)),
                                          seed: redSeed,
                                          color: CIVector(x: settings.colorNoise * 0.2, y: 0, z: 0, w: 1))

                let greenDots = generateNoise(rect: noiseRect,
                                            scale: Float(5 + (settings.colorNoise * 5)),
                                            seed: greenSeed,
                                            color: CIVector(x: 0, y: settings.colorNoise * 0.2, z: 0, w: 1))

                let blueDots = generateNoise(rect: noiseRect,
                                           scale: Float(5 + (settings.colorNoise * 5)),
                                           seed: blueSeed,
                                           color: CIVector(x: 0, y: 0, z: settings.colorNoise * 0.2, w: 1))

                // RGBドットを合成
                if let redNoise = redDots {
                    var colorNoise = redNoise

                    if let greenNoise = greenDots {
                        let addGreen = CIFilter.additionCompositing()
                        addGreen.inputImage = greenNoise
                        addGreen.backgroundImage = colorNoise
                        if let output = addGreen.outputImage {
                            colorNoise = output
                        }
                    }

                    if let blueNoise = blueDots {
                        let addBlue = CIFilter.additionCompositing()
                        addBlue.inputImage = blueNoise
                        addBlue.backgroundImage = colorNoise
                        if let output = addBlue.outputImage {
                            colorNoise = output
                        }
                    }

                    // 最終的なブレンド
                    let blend = CIFilter.additionCompositing()
                    blend.inputImage = colorNoise
                    blend.backgroundImage = currentImage

                    if let output = blend.outputImage {
                        currentImage = output
                    }
                }
            }

            // ダストとスクラッチ
            if settings.dustNoise > 0 {
                let noise = CIFilter.randomGenerator()

                if var noiseOutput = noise.outputImage?.cropped(to: baseNoiseRect) {
                    let scale = max(currentImage.extent.width, currentImage.extent.height) / baseNoiseScale
                    noiseOutput = noiseOutput.transformed(by: .init(scaleX: scale, y: scale))

                    let thresholdValue = 0.99 - (settings.dustNoise * 0.01) // より多くのダストを生成

                    let dustNoiseImage = noiseOutput
                        .applyingFilter("CIColorMatrix", parameters: [
                            "inputRVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                            "inputGVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                            "inputBVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: settings.dustNoise * 0.03)
                        ])
                        .applyingFilter("CIColorThreshold", parameters: [
                            "inputThreshold": thresholdValue
                        ])

                    let blend = CIFilter.screenBlendMode()
                    blend.inputImage = dustNoiseImage.cropped(to: currentImage.extent)
                    blend.backgroundImage = currentImage
                    if let output = blend.outputImage {
                        currentImage = output
                    }
                }
            }
        }


        return context.createCGImage(currentImage, from: currentImage.extent)
    }

    private func generateNoise(rect: CGRect, scale: Float, seed: Double, color: CIVector) -> CIImage? {
        let noise = CIFilter.randomGenerator()

        guard var noiseOutput = noise.outputImage else { return nil }

        // シード値を使用してパターンを変更
        noiseOutput = noiseOutput.transformed(by: .init(translationX: CGFloat(sin(seed)) * rect.width,
                                                      y: CGFloat(cos(seed)) * rect.height))

        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = noiseOutput
        pixellate.scale = scale

        guard let dots = pixellate.outputImage?.cropped(to: rect) else { return nil }

        return dots.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: color.x, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: color.y, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: color.z, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: color.w)
        ])
    }
}

struct FilterSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let title: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            HStack {
                Slider(value: $value, in: range)
                Text(String(format: "%.2f", value))
                    .frame(width: 50)
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

import UIKit
import SceneKit
import ARKit
import CoreML
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    // ラベル背景
    @IBOutlet weak var labelBack: UIView!
    // 現在のポーズを表示するラベル
    @IBOutlet weak var poseLabel: UILabel!
    // 信頼度表示するラベル
    @IBOutlet weak var confidenceLabel: UILabel!
    
    // モデルの読み込み
    let banzaiClassifier = banzai()
    // モデルを作成した時の予測ウィンドウのサイズ。小さくすると予測頻度が上がる(良いのかはわからない)
    var windowSize = 60
    // 60ポーズ(フレーム)を保存する
    var posewindows: [VNRecognizedPointsObservation?] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        
        labelBack.alpha = 0.5
        labelBack.backgroundColor = UIColor.gray
        
        // 配列の初期化
        posewindows.reserveCapacity(windowSize)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // 現在のフレームを取得
        guard let cuputureImage = self.sceneView.session.currentFrame?.capturedImage else {
            return
        }
        
        // Requestの作成
        let request = VNDetectHumanBodyPoseRequest(completionHandler: estimation)
        // ReqesuHandlerの作成
        let handler = VNImageRequestHandler(cvPixelBuffer: cuputureImage, options: [:])
        
        do {
            // RequestHandlerの実行
            try handler.perform([request])
        } catch {
            print(error)
        }

    }
    
    func estimation(request: VNRequest, error: Error?) {
        // 実行結果を取得
        guard let observations = request.results as? [VNRecognizedPointsObservation] else { return }
        
        if posewindows.count < 60 {
            posewindows.append(contentsOf: observations)
        } else {
            do {
                // フレームを多次元配列に変換する
                let poseMultiArray: [MLMultiArray] = try posewindows.map { person in
                    guard let person = person else {
                        // 人が検出されない場合
                        let zero:MLMultiArray = try! MLMultiArray(shape: [3, 100, 100], dataType: .float)
                        return zero
                    }
                    return try person.keypointsMultiArray()
                }
                // モデルに入力できるようにする。　(単一の配列に連結？)
                let modelInput = MLMultiArray(concatenating: poseMultiArray, axis: 0, dataType: .float)
                // モデルの予測
                let predictions = try banzaiClassifier.prediction(poses: modelInput)
                
                
                DispatchQueue.main.sync {
                    // ラベル名
                    poseLabel.text = predictions.label
                    // 信頼度 (切り捨て)
                    let confidence = floor(predictions.labelProbabilities[predictions.label]! * 100)
                    confidenceLabel.text = "\(confidence)%"
                }
                
                // 配列を初期化
                posewindows.removeFirst(windowSize)
            } catch {
                print(error)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()

        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
}

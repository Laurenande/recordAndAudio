//
//  ViewController.swift
//  AudioKurakin
//
//  Created by Егор Куракин on 25.07.2022.
//

import UIKit
import AVFoundation
//import AudioToolbox
import Speech
import lame

class ViewController: UIViewController {
    //File on document Directory
    var content: [String]? = []

    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var text: UILabel!
    //Main Audio Engine
    var audioEngine : AVAudioEngine!
    
    //Used to play myAduio during recording and Final recording during play
    var audioFile : AVAudioFile!
    
    //Player for playing myAudio
    var audioPlayer : AVAudioPlayerNode!
    
    //Extended Audio File Services to attach to audioFile
    var outref: ExtAudioFileRef?
    
    //Player for playing recorded file
    var audioFilePlayer: AVAudioPlayerNode!
    
    //Mixer to mix myAudio with mic input during recording
    var mixer : AVAudioMixerNode!
    
    //Used to define filepath to save recorded file
    var filePath : String? = nil
    var filePathMP3: String? = nil
    
    //Add now date in name record file
    let mytime = Date()
    let formatDate = DateFormatter()
    var isPlay = false
    var isRec = false
    //let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
    @IBOutlet var play: UIButton!

    //Called On Play Button
    @IBAction func play(_ sender: Any) {
        
        if self.isPlay {
            self.play.setTitle("PLAY", for: .normal)
            self.indicator(value: false)
            self.stopPlay()
            self.rec.isEnabled = true
        } else {
            if self.startPlay() {
                self.rec.isEnabled = false
                self.play.setTitle("STOP", for: .normal)
                self.indicator(value: true)
            }
        }
    }
    
    
    @IBOutlet var rec: UIButton!
    
    //Called On Record Button
    @IBAction func rec(_ sender: Any) {
        
        if self.isRec {
            self.rec.setTitle("RECORDING", for: .normal)
            self.indicator(value: false)
            self.stopRecord()
            self.play.isEnabled = true
        } else {
            self.play.isEnabled = false
            self.rec.setTitle("STOP", for: .normal)
            self.indicator(value: true)
            self.startRecord()
        }
    }
    @IBAction func shareRec(_ sender: Any) {
        

        let fileURL = NSURL(fileURLWithPath: filePathMP3 ?? "nil")

        // Create the Array which includes the files you want to share
        var filesToShare = [Any]()

        // Add the path of the file to the Array
        filesToShare.append(fileURL)

        // Make the activityViewContoller which shows the share-view
        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)

        // Show the share-view
        self.present(activityViewController, animated: true, completion: nil)
        
    }
    
    func openDir() {
       // let fileManager = FileManager.default
        //let filePathName = "\(dir)/temp2022-07-26 12:13:55 +0000.wav"
        /*
        do{
        try fileManager.removeItem(atPath: filePathName)
        }catch{
            print("No ok")
        }*/
        
        //Test my work on File Manager
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
        do {
            self.content = try FileManager.default.contentsOfDirectory(atPath: dir)
            
        } catch  {
            content = []
        }
        print(Date.now)
        for i in 0...content!.count - 1
        {
        print(self.content![i])
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Main AudioEngine
        self.audioEngine = AVAudioEngine()
        
        //Used to play myAudio
        self.audioFilePlayer = AVAudioPlayerNode()
        
        //Mixes two inputs
        self.mixer = AVAudioMixerNode()
        
        //Attaches myAudio input to audio engine
        self.audioEngine.attach(audioFilePlayer)
        
        //Attaches the mixer to the audio engine
        self.audioEngine.attach(mixer)
        
        self.indicator(value: false)
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                return
            default:
                return
            }
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        openDir()
    }
    
    
    func startRecord() {
        
        self.filePath = nil
        
        //is recording = true
        self.isRec = true
        
        //Setup session
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        // Load myAudio to background
        self.audioFile = try! AVAudioFile(forReading: Bundle.main.url(forResource: "myAudio", withExtension: "mp3")!)
        
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
        
        let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
                                   sampleRate: 44100.0,
                                   channels: 1,
                                   interleaved: true)
        
        //Connect microphone to mixer
        self.audioEngine.connect(self.audioEngine.inputNode, to: self.mixer, format: format)
        
        //Connect myAudio to mixer
        self.audioEngine.connect(self.audioFilePlayer, to: self.mixer, format: self.audioFile.processingFormat)
        
        //Connect mixer to mainMixer
        self.audioEngine.connect(self.mixer, to: self.audioEngine.mainMixerNode, format: format)
        
        //Configure 1K.mp3 player settings
         self.audioFilePlayer.scheduleSegment(audioFile,
                                             startingFrame: AVAudioFramePosition(0),
                                             frameCount: AVAudioFrameCount(self.audioFile.length),
                                             at: nil,
                                             completionHandler: self.completion)
        
        //Set up directory for saving recording
        self.formatDate.dateFormat = "yyyy-MM-dd-HH:mm"
        let date = self.formatDate.string(from: mytime)
        self.filePath =  dir.appending("/record-\(String(date)).m4a")
        
        //Create file to save recording
        _ = ExtAudioFileCreateWithURL(URL(fileURLWithPath: self.filePath!) as CFURL,
                                      kAudioFileWAVEType,
                                      (format?.streamDescription)!,
                                      nil,
                                      AudioFileFlags.eraseFile.rawValue,
                                      &outref)
        
        //Tap on the mixer output microphone and myAudio
        self.mixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount((format?.sampleRate)! * 0.4), format: format, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
            
            //Audio Recording Buffer
            let audioBuffer : AVAudioBuffer = buffer
            
            //Write Buffer to File
            _ = ExtAudioFileWrite(self.outref!, buffer.frameLength, audioBuffer.audioBufferList)
        })
        self.audioEngine.inputNode.isVoiceProcessingInputMuted = true
        try! self.audioEngine.start()
        
        self.audioFilePlayer.play()
    
        
        
    }
    
    func stopRecord() {
        self.isRec = false
        
        self.audioFilePlayer.stop()
        
        self.audioEngine.stop()
        
        //Removes tap on Engine Mixer
        self.mixer.removeTap(onBus: 0)
        
        //Removes reference to audio file
        ExtAudioFileDispose(self.outref!)
        
        //Deactivate audio session
        try! AVAudioSession.sharedInstance().setActive(false)
        
        //Parse the audio input received
        ParseAudioFile()
        //print(filePath)
        self.startMP3Rec(path: self.filePath!, rate: 128)
        
    }
    
    func startPlay() -> Bool {
        
        if self.filePath == nil {
            return    false
        }
        
        self.isPlay = true
        
        //Sets up Audio Session to play sound
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        try! AVAudioSession.sharedInstance().setActive(true)
        
        //Loads audio file
        self.audioFile = try! AVAudioFile(forReading: URL(fileURLWithPath: self.filePath!))
        
        //Connect audio player to the main mixer node of the engine
        self.audioEngine.connect(self.audioFilePlayer, to: self.audioEngine.mainMixerNode, format: audioFile.processingFormat)
        
        //Set up audio player and schedule its playing in the audio stream
        self.audioFilePlayer.scheduleSegment(audioFile,
                                             startingFrame: AVAudioFramePosition(0),
                                             frameCount: AVAudioFrameCount(self.audioFile.length),
                                             at: nil,
                                             completionHandler: self.completion)
        try! self.audioEngine.start()
        
        self.audioFilePlayer.play()
        
        return true
        
    }
    
    func ParseAudioFile() {
        
        self.audioFile = try! AVAudioFile(forReading: URL(fileURLWithPath: self.filePath!))
        
        let totSamples = audioFile.length
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audioFile.fileFormat.sampleRate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totSamples))!
        try! audioFile.read(into: buffer)
        
        self.startMP3Rec(path: self.filePath!, rate: 128)
        
    }
    
    func stopPlay() {
        self.isPlay = false
        
        //Stop the player (if it is playing)
        if self.audioFilePlayer != nil && self.audioFilePlayer.isPlaying {
            self.audioFilePlayer.stop()
        }
    
        self.audioEngine.stop()
        
        //Deactivate audio session
        try! AVAudioSession.sharedInstance().setActive(false)
        
        
    }
    
    //Called at the audioplayer.schedule to adjust UI
    func completion() {

        if self.isRec {
            DispatchQueue.main.async {
                self.rec(UIButton())
            }
        } else if self.isPlay {
            DispatchQueue.main.async {
                self.play(UIButton())
            }
        }
    }
    
    // Show/Hide indicator
    func indicator(value: Bool) {
        
        DispatchQueue.main.async {
            if value {
                self.indicatorView.startAnimating()
                self.indicatorView.isHidden = false
            } else {
                self.indicatorView.stopAnimating()
                self.indicatorView.isHidden = true
            }
        }
    }
    //Convert m4a to mp3
    func startMP3Rec(path: String, rate: Int32) {

            let isMP3Active = true
            var total = 0
            var read = 0
            var write: Int32 = 0

            let mp3path = path.replacingOccurrences(of: "m4a", with: "mp3")
        
            var pcm: UnsafeMutablePointer<FILE> = fopen(path, "rb")
            fseek(pcm, 4*1024, SEEK_CUR)
            let mp3: UnsafeMutablePointer<FILE> = fopen(mp3path, "wb")
            let PCM_SIZE: Int = 8192
            let MP3_SIZE: Int32 = 8192
            let pcmbuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(PCM_SIZE*2))
            let mp3buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MP3_SIZE))

            let lame = lame_init()
            lame_set_num_channels(lame, 1)
            lame_set_mode(lame, MONO)
            lame_set_in_samplerate(lame, 44100)
            lame_set_brate(lame, rate)
            lame_set_VBR(lame, vbr_off)
            lame_init_params(lame)

            DispatchQueue.global(qos: .default).async {
                while true {
                    pcm = fopen(path, "rb")
                    fseek(pcm, 4*1024 + total, SEEK_CUR)
                    read = fread(pcmbuffer, MemoryLayout<Int16>.size, PCM_SIZE, pcm)
                    if read != 0 {
                        write = lame_encode_buffer(lame, pcmbuffer, nil, Int32(read), mp3buffer, MP3_SIZE)
                        fwrite(mp3buffer, Int(write), 1, mp3)
                        total += read * MemoryLayout<Int16>.size
                        fclose(pcm)
                        
                    } else if !isMP3Active {
                        _ = lame_encode_flush(lame, mp3buffer, MP3_SIZE)
                        _ = fwrite(mp3buffer, Int(write), 1, mp3)
                        
                        break
                    } else {
                        fclose(pcm)
                        usleep(50)
                    }
                    
                }
                lame_close(lame)
                fclose(mp3)
                fclose(pcm)
                
                
            }
        self.filePathMP3 = mp3path
        }
    
}

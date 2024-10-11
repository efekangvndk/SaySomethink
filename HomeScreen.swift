//
//  HomeScreen.swift
//  SaySomethink
//
//  Created by Efekan Güvendik on 11.10.2024.
//

import AVFoundation
import Combine
import Speech
import SwiftUI

struct HomeScreen: View {
    @State private var isPressed = false
    @State private var timer: AnyCancellable?
    @State private var pressDuration: Double = 0.0
    @StateObject private var audioRecorder = AudioRecorder()

    var body: some View {
        ZStack {
            Header(isPressed: $isPressed, pressDuration: $pressDuration, timer: $timer, audioRecorder: audioRecorder)
        }
    }
}

struct Header: View {
    @Binding var isPressed: Bool
    @Binding var pressDuration: Double
    @Binding var timer: AnyCancellable?
    @ObservedObject var audioRecorder: AudioRecorder

    // Text alanı için bir state
    @State private var recognizedText: String = "Recorded Text Will Appear Here"

    var body: some View {
        VStack {
            Text("Say Somethink")
                .foregroundStyle(.brown)
                .font(.largeTitle)
            Spacer()

            // Kayıttan sonra metin burada görünecek
            Text(recognizedText)
                .font(.body)
                .padding()

            Button(action: {
                // Kayıtlı sesi oynat
                audioRecorder.playRecording()
            }) {
                Text("Play Recording")
                    .foregroundStyle(.cyan)
            }
            Spacer()

            Button {
                print("Recording")
            } label: {
                Text("Record Button")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                if pressing {
                    // Butona basıldığında kayıt başlar.
                    startTimer()
                    audioRecorder.startRecording()
                    isPressed = true
                } else {
                    // Butona bırakıldığında kayıt durur ve sesi metne çevirir.
                    stopTimer()
                    audioRecorder.stopRecording()
                    isPressed = false
                    audioRecorder.recognizeSpeech { result in
                        DispatchQueue.main.async {
                            recognizedText = result ?? "Recognition failed"
                        }
                    }
                }
            }, perform: {
                // Bu closure, butona uzun basıldığında çalışır.
                print("Button long pressed for \(pressDuration) seconds")
            })
            Spacer()
        }
    }

    private func startTimer() {
        // Timer'ı başlat
        pressDuration = 0.0
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                pressDuration += 0.1
                print("Press duration: \(pressDuration) seconds")
            }
    }

    private func stopTimer() {
        // Timer'ı durdur
        timer?.cancel()
        timer = nil
        print("Final press duration: \(pressDuration) seconds")
    }
}

import Foundation
import AVFoundation
import Speech

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    
    // Türkçe tanıma için SFSpeechRecognizer'ı ayarlıyoruz
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR")) // Türkçe locale
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    
    override init() {
        super.init()
        setupRecorder()
        requestSpeechRecognitionPermission()
    }

    func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            audioSession.requestRecordPermission { allowed in
                if !allowed {
                    print("Permission not granted")
                }
            }
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    func startRecording() {
        let fileName = "recording.m4a"
        let filePath = getDocumentsDirectory().appendingPathComponent(fileName)

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            print("Recording started")
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        print("Recording stopped")
    }

    func playRecording() {
        let fileName = "recording.m4a"
        let filePath = getDocumentsDirectory().appendingPathComponent(fileName)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: filePath)
            audioPlayer?.play()
            print("Playing recording")
        } catch {
            print("Failed to play recording: \(error.localizedDescription)")
        }
    }

    func recognizeSpeech(completion: @escaping (String?) -> Void) {
        let fileName = "recording.m4a"
        let filePath = getDocumentsDirectory().appendingPathComponent(fileName)

        recognitionRequest = SFSpeechURLRecognitionRequest(url: filePath)

        speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                print("Transcription: \(result.bestTranscription.formattedString)")
                completion(result.bestTranscription.formattedString)
            } else if let error = error {
                print("Recognition failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            case .denied:
                print("Speech recognition denied")
            case .restricted:
                print("Speech recognition restricted")
            case .notDetermined:
                print("Speech recognition not determined")
            @unknown default:
                fatalError()
            }
        }
    }
}

#Preview {
    HomeScreen()
}

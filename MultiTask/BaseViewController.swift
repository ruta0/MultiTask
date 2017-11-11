//
//  BaseViewController.swift
//  MultiTask
//
//  Created by rightmeow on 11/9/17.
//  Copyright © 2017 Duckensburg. All rights reserved.
//

import UIKit
import AVFoundation

class BaseViewController: UIViewController {

    // MARK: - Application sound notification

    var avaPlayer: AVAudioPlayer?

    enum AlertSoundType: String {
        case error = "Error"
        case success = "Success"
    }

    func playAlertSound(type: AlertSoundType) {
        guard let sound = NSDataAsset(name: type.rawValue) else {
            print(trace(file: #file, function: #function, line: #line))
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            avaPlayer = try AVAudioPlayer(data: sound.data, fileTypeHint: AVFileTypeWAVE)
            DispatchQueue.main.async {
                guard let player = self.avaPlayer else { return }
                player.play()
            }
        } catch let err {
            print(trace(file: #file, function: #function, line: #line))
            print(err.localizedDescription)
        }
    }

    private func setupView() {
        self.view.backgroundColor = Color.inkBlack
    }

    // MARK: - Navigation prompt

    var timer: Timer?

    func scheduleNavigationPrompt(with message: String, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.navigationItem.prompt = message
            self.timer = Timer.scheduledTimer(timeInterval: duration,
                                              target: self,
                                              selector: #selector(self.removePrompt),
                                              userInfo: nil,
                                              repeats: false)
            self.timer?.tolerance = 5
        }
    }

    @objc private func removePrompt() {
        if navigationItem.prompt != nil {
            DispatchQueue.main.async {
                self.navigationItem.prompt = nil
            }
        }
    }

    private func setupNavigationController() {
        navigationController?.navigationBar.barTintColor = Color.midNightBlack
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupNavigationController()
        self.setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

}


















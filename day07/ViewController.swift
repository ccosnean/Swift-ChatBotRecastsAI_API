//
//  ViewController.swift
//  day07
//
//  Created by Cristian Cosneanu on 5/2/17.
//  Copyright © 2017 Cristian Cosneanu. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import RecastAI
import ForecastIO
import Speech
import AVFoundation

struct User {
    let id:String
    let name:String
}

class ViewController: JSQMessagesViewController, SFSpeechRecognizerDelegate {

    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    
    var bot_person: RecastAIClient?

    let client = DarkSkyClient(apiKey: "07a3e7dd36452730afb1106bcff624fa")
    
    var indexPath = IndexPath()
    
    let user1 = User(id: "1", name: "Cristian")
    let user2 = User(id: "2", name: "Bot-Person")
    
    var messages = [JSQMessage]()

    
    
    private var speachRecogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var audioEngine = AVAudioEngine()
    
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    
    
    var access = false
    
    func speakText(myTxt: String)
    {
        DispatchQueue.main.async {
            
            
            self.myUtterance = AVSpeechUtterance(string: myTxt.replacingOccurrences(of: "#", with: " Hashtag "))
            
//            var voiceToUse: AVSpeechSynthesisVoice?
//            for voice in AVSpeechSynthesisVoice.speechVoices() {
//                if #available(iOS 9.0, *) {
//                    if voice.name == "Tessa" {
//                        voiceToUse = voice
//                    }
//                } 
//            }
//            self.myUtterance.voice = voiceToUse
            
            self.myUtterance.rate = 0.5
            self.synth.speak(self.myUtterance)
        }
    }
    
    
    //user images
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.backgroundColor = UIColor(patternImage: UIImage(named: "school")!)
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.access = true
                    print("ok")
                    break
                case .denied:
                    print("Denied")
                    
                case .restricted:
                    print("Restricted")
                    
                    
                case .notDetermined:
                    print("notDetermined")
                    
                }
            }
        }
        
        self.speachRecogniser.delegate = self
        
        self.senderId = self.curentUser.id
        self.senderDisplayName = self.curentUser.name
        
        self.client.units = .si
        self.client.language = .english
        
        let speach = UIButton(frame: CGRect.zero)
        let sendImage = UIImage(named: "micBlack")
        speach.setImage(sendImage, for: [])
        self.inputToolbar.contentView.leftBarButtonItemWidth = CGFloat(15.0)
        self.inputToolbar.contentView.leftBarButtonItem = speach
        
        //recast bot connect
        self.bot_person = RecastAIClient(token : "2582b119449ee135eaaf5f0cc348c0f0", language: "en")
        self.messages.append(JSQMessage(senderId: "1", displayName: "StartMsg", text: "First time here? ask for help, it is nothing to be ashamed of..."))
    }

    
    var curentUser: User{
        return user1
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        if curentUser.id == self.messages[indexPath.row].senderId
        {
            return JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: .blue)
        }
        return JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: .brown)
    }
    
    
    
    //avatar image
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        if self.messages[indexPath.row].senderId == self.curentUser.id
        {
            return JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "monkey"), diameter: 50)
        }
        else
        {
            return JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "bot"), diameter: 50)
        }
    }
    
    
    
    
    
    let audioSession = AVAudioSession.sharedInstance()
    
    
    
    //command check
    
    func checkCommand(msg: String){

        var m = msg.replacingOccurrences(of: "#StopListening", with: "")
        
        if m.lowercased().range(of: "#reply") != nil
        {
            m = m.replacingOccurrences(of: "#Reply", with: "")
            if  !m.isEmpty
            {
                self.didPressSend(UIButton(), withMessageText: m, senderId: self.curentUser.id, senderDisplayName: self.curentUser.name, date: Date())
            }
            return
        }
    }
    
    
    // Start recording
    
    private func StartRecording() throws {
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SfSpeechAudioBufferRecognitionRequest object")}
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speachRecogniser.recognitionTask(with: recognitionRequest) { result, error in var isFinal = false
            var msg:String?
            
            if let result = result {
                msg = result.bestTranscription.formattedString
                if msg?.lowercased().range(of: "#stoplistening") != nil
                {
                    msg = msg?.replacingOccurrences(of: "#StopListening", with: "")
                    self.started = true
                    self.swapBTN()
                }
                self.inputToolbar.contentView.textView.text = msg
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.checkCommand(msg: msg!)
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
            
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    
    var started = false
    
    func swapBTN()
    {
        if started
        {
            let speach = UIButton(frame: CGRect.zero)
            let sendImage = UIImage(named: "micBlack")
            speach.setImage(sendImage, for: [])
            self.inputToolbar.contentView.leftBarButtonItemWidth = CGFloat(15.0)
            self.inputToolbar.contentView.leftBarButtonItem = speach
            
            try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try! audioSession.setMode(AVAudioSessionModeDefault)
            
            audioEngine.inputNode?.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            audioEngine.stop()
            
            started = false
        }
        else
        {
            let speach = UIButton(frame: CGRect.zero)
            let sendImage = UIImage(named: "micRed")
            speach.setImage(sendImage, for: [])
            self.inputToolbar.contentView.leftBarButtonItemWidth = CGFloat(15.0)
            self.inputToolbar.contentView.leftBarButtonItem = speach
            started = true
            try! self.StartRecording()
        }

    }

    override func didPressAccessoryButton(_ sender: UIButton!) {
        // screpka
        if !access
        {
            return
        }
        self.swapBTN()
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let newMsg = JSQMessage(senderId: senderId, displayName: senderDisplayName, text: text)
        self.messages.append(newMsg!)
        collectionView.reloadData()
        makeRequest(curentMsg: text!)
        
        self.inputToolbar.contentView.textView.text = ""
        
        //SCROLL
        self.collectionView?.scrollToItem(at: self.indexPath, at: UICollectionViewScrollPosition.top, animated: false)
        print("Send")
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        return NSAttributedString(string: self.messages[indexPath.row].senderDisplayName!)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return 15
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        self.indexPath = indexPath
        return self.messages[indexPath.row]
    }
    
    func printError()
    {
        self.messages.append(JSQMessage(senderId: "2", displayName: "Bot-Person" , text: "Error in getting weather!"))
        self.collectionView.reloadData()
        self.collectionView?.scrollToItem(at: self.indexPath, at: UICollectionViewScrollPosition.top, animated: false)
    }
    
    func reloadData()
    {
        self.collectionView.reloadData()
        self.collectionView?.scrollToItem(at: self.indexPath, at: UICollectionViewScrollPosition.top, animated: false)
    }
    
    func makeRequest(curentMsg: String)
    {
        //Call makeRequest with string parameter to make a text request
        if !curentMsg.isEmpty
        {
            self.bot_person?.textConverse(curentMsg, successHandler: { (response) in
            
                if let dic = response.entities!["location"] as? [NSDictionary]
                {
                    let lat = dic[0]["lat"]!
                    let lng = dic[0]["lng"]!

                    if !(lat is NSNull) && !(lng is NSNull)
                    {
                        self.client.getForecast(latitude: lat as! Double, longitude: lng as! Double)
                        { result in
                            
                            switch result {
                            case .success(let currentForecast, _):
                                self.messages.append(JSQMessage(senderId: "2", displayName: "Bot-Person" , text: currentForecast.daily?.summary!))
                                
                                
                                self.speakText(myTxt: (currentForecast.daily?.summary!)!)
                                
                                self.reloadData()
                              break
                            case .failure(_):
                                self.printError()
                                break
                            }
                            
                        }
                    }
                    else
                    {
    //                    print("\n\n\n\nLAST\n\n\n\n\n")
                        self.printError()
                    }
                }
                else
                {
                    //request
                    if (response.replies?.count)! > 0
                    {
                        self.messages.append(JSQMessage(senderId: "2", displayName: "Bot-Person" , text: String(describing: response.replies![0])))
                        

                        self.speakText(myTxt: String(describing: response.replies![0]))
                        
                        
                        self.reloadData()
                    }
                    else
                    {
                        self.messages.append(JSQMessage(senderId: "2", displayName: "Bot-Person" , text: "Pardon?..."))
                        
                        
                        self.speakText(myTxt: "Pardon?...")
                        
                        
                        self.reloadData()
                    }
                }
            }, failureHandle: { (error) in
                //error
                print("Error\n\n", error)
            })
        }
    }
    
   
}


//  Created by Michael Kirk on 11/10/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

import Foundation
import WebRTC
import PromiseKit

@objc class CallAudioService: NSObject {
    private let TAG = "[CallAudioService]"
    private var vibrateTimer: Timer?
    private let audioManager = AppAudioManager.sharedInstance()

    // Mark: Vibration config
    private let vibrateRepeatDuration = 1.6

    // Our ring buzz is a pair of vibrations.
    // `pulseDuration` is the small pause between the two vibrations in the pair.
    private let pulseDuration = 0.2

    public var isSpeakerphoneEnabled = false {
        didSet {
            handleUpdatedSpeakerphone()
        }
    }

    public func handleState(_ state: CallState) {
        switch state {
        case .idle: handleIdle()
        case .dialing: handleDialing()
        case .answering: handleAnswering()
        case .remoteRinging: handleRemoteRinging()
        case .localRinging: handleLocalRinging()
        case .connected: handleConnected()
        case .localFailure: handleLocalFailure()
        case .localHangup: handleLocalHangup()
        case .remoteHangup: handleRemoteHangup()
        case .remoteBusy: handleBusy()
        }
    }

    private func handleIdle() {
        Logger.debug("\(TAG) \(#function)")
    }

    private func handleDialing() {
        Logger.debug("\(TAG) \(#function)")
    }

    private func handleAnswering() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
    }

    private func handleRemoteRinging() {
        Logger.debug("\(TAG) \(#function)")
    }

    private func handleLocalRinging() {
        Logger.debug("\(TAG) \(#function)")
        audioManager.setAudioEnabled(true)
        audioManager.handleInboundRing()
        do {
            // Respect silent switch.
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategorySoloAmbient)
            Logger.debug("\(TAG) set audio category to SoloAmbient")
        } catch {
            Logger.error("\(TAG) failed to change audio category to soloAmbient in \(#function)")
        }

        vibrateTimer = Timer.scheduledTimer(timeInterval: vibrateRepeatDuration, target: self, selector: #selector(vibrate), userInfo: nil, repeats: true)
    }

    private func handleConnected() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
        do {
            // Start recording
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            Logger.debug("\(TAG) set audio category to PlayAndRecord")
        } catch {
            Logger.error("\(TAG) failed to change audio category to soloAmbient in \(#function)")
        }
    }

    private func handleLocalFailure() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
    }

    private func handleLocalHangup() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
    }

    private func handleRemoteHangup() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
    }

    private func handleBusy() {
        Logger.debug("\(TAG) \(#function)")
        stopRinging()
    }

    private func handleUpdatedSpeakerphone() {
        audioManager.toggleSpeakerPhone(isEnabled: isSpeakerphoneEnabled)
    }

    // MARK: Helpers

    private func stopRinging() {
        // Disables external speaker used for ringing, unless user enables speakerphone.
        audioManager.setDefaultAudioProfile()
        audioManager.cancelAllAudio()

        vibrateTimer?.invalidate()
        vibrateTimer = nil
    }

    public func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.default.asyncAfter(deadline: DispatchTime.now() + pulseDuration) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}

@objc(OWSCallViewController)
class CallViewController: UIViewController {

    enum CallDirection {
        case unspecified, outgoing, incoming
    }

    let TAG = "[CallViewController]"

    // Dependencies
    let callService: CallService
    let callUIAdapter: CallUIAdapter
    let contactsManager: OWSContactsManager
    let audioService: CallAudioService

    // MARK: Properties

    var peerConnectionClient: PeerConnectionClient?
    var callDirection: CallDirection = .unspecified
    var thread: TSContactThread!
    var call: SignalCall!
    var hasConstraints = false

    // MARK: Contact Views
    
    var contactNameLabel: UILabel!
    var contactAvatarView: AvatarImageView!
    var callStatusLabel: UILabel!

    // MARK: Ongoing Call Controls

    var ongoingCallControlsTopRow: UIView!
    var ongoingCallControlsBottomRow: UIView!
    @IBOutlet var callControls: UIView!
    @IBOutlet var hangUpButton: UIButton!
    @IBOutlet var muteButton: UIButton!
    @IBOutlet var speakerPhoneButton: UIButton!
    // Which call states does this apply to?
    @IBOutlet var textMessageButton: UIButton!

    // MARK: Incoming Call Controls

    var incomingCallControlsRow: UIView!
    @IBOutlet var incomingCallControls: UIView!
    @IBOutlet var acceptIncomingButton: UIButton!
    @IBOutlet var declineIncomingButton: UIButton!
    
    // MARK: Initializers

    required init?(coder aDecoder: NSCoder) {
        contactsManager = Environment.getCurrent().contactsManager
        callService = Environment.getCurrent().callService
        callUIAdapter = callService.callUIAdapter
        audioService = CallAudioService()
        super.init(coder: aDecoder)
    }

    required init() {
        contactsManager = Environment.getCurrent().contactsManager
        callService = Environment.getCurrent().callService
        callUIAdapter = callService.callUIAdapter
        audioService = CallAudioService()
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let thread = self.thread else {
            Logger.error("\(TAG) tried to show call call without specifying thread.")
            showCallFailed(error: OWSErrorMakeAssertionError())
            return
        }
        
        createViews()
        
        contactNameLabel.text = contactsManager.displayName(forPhoneIdentifier: thread.contactIdentifier())
        contactAvatarView.image = OWSAvatarBuilder.buildImage(for: thread, contactsManager: contactsManager)

        switch callDirection {
        case .unspecified:
            Logger.error("\(TAG) must set call direction before call starts.")
            showCallFailed(error: OWSErrorMakeAssertionError())
        case .outgoing:
            self.call = self.callUIAdapter.startOutgoingCall(handle: thread.contactIdentifier())
        case .incoming:
            Logger.error("\(TAG) handling Incoming call")
            // No-op, since call service is already set up at this point, the result of which was presenting this viewController.
        }

        call.stateDidChange = callStateDidChange
        callStateDidChange(call.state)
    }
    
    func createViews() {
        
        // Take a strong reference, since we are about to remove these
        // UIViews from the view hierarchy and this VC only holds weak
        // references to them.
        let allControls = allCallControls()
        for subview in allControls {
            subview.removeFromSuperview()
        }

        for subview in self.view.subviews {
            subview.removeFromSuperview()
        }
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(blurView)
        blurView.autoPinEdgesToSuperviewEdges()

        // Contact views
        contactNameLabel = UILabel()
        contactNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contactNameLabel.font = UIFont.ows_lightFont(withSize:32)
        contactNameLabel.textColor = UIColor.white
        self.view.addSubview(contactNameLabel)

        callStatusLabel = UILabel()
        callStatusLabel.font = UIFont.ows_regularFont(withSize:19)
        callStatusLabel.textColor = UIColor.white
        self.view.addSubview(callStatusLabel)
        
        contactAvatarView = AvatarImageView()
        self.view.addSubview(contactAvatarView)

        // Ongoing call controls
        ongoingCallControlsTopRow = UIView()
        ongoingCallControlsBottomRow = UIView()
        self.view.addSubview(ongoingCallControlsTopRow)
        self.view.addSubview(ongoingCallControlsBottomRow)
        
        ongoingCallControlsTopRow.addSubview(textMessageButton)
        ongoingCallControlsBottomRow.addSubview(muteButton)
        ongoingCallControlsBottomRow.addSubview(hangUpButton)
        ongoingCallControlsBottomRow.addSubview(speakerPhoneButton)
        
        // Incoming call controls
        incomingCallControlsRow = UIView()
        self.view.addSubview(incomingCallControlsRow)
        incomingCallControlsRow.addSubview(acceptIncomingButton)
        incomingCallControlsRow.addSubview(declineIncomingButton)
    }
    
    override func updateViewConstraints() {
        if (!hasConstraints) {
            hasConstraints = true

            let topMargin = CGFloat(40)
            let contactHMargin = CGFloat(30)
            let ongoingHMargin = CGFloat(30)
            let incomingHMargin = CGFloat(60)
            let bottomMargin = CGFloat(40)
            let rowSpacing = CGFloat(40)

            contactNameLabel.autoPinEdge(toSuperviewEdge:.top, withInset:topMargin)
            contactNameLabel.autoPinEdge(toSuperviewEdge:.left, withInset:contactHMargin)
            contactNameLabel.autoPinEdge(toSuperviewEdge:.right, withInset:contactHMargin)
            contactNameLabel.setContentHuggingVerticalHigh()

            callStatusLabel.autoPinEdge(.top, to:.bottom, of:contactNameLabel)
            callStatusLabel.autoPinEdge(toSuperviewEdge:.left, withInset:contactHMargin)
            callStatusLabel.autoPinEdge(toSuperviewEdge:.right, withInset:contactHMargin)
            callStatusLabel.setContentHuggingVerticalHigh()

            contactAvatarView.autoPinEdge(.top, to:.bottom, of:callStatusLabel, withOffset:+50)
            contactAvatarView.autoPinEdge(.bottom, to:.top, of:ongoingCallControlsTopRow, withOffset:-50)
            contactAvatarView.autoAlignAxis(.vertical, toSameAxisOf:self.view)
            // Stretch that avatar to fill the available space.
            contactAvatarView.setContentHuggingVerticalLow()
            // Preserve square aspect ratio of contact avatar.
            contactAvatarView.autoMatch(.width, to:.height, of:contactAvatarView)

            // Ongoing call controls
            ongoingCallControlsTopRow.autoPinEdge(.bottom, to:.top, of:ongoingCallControlsBottomRow, withOffset:-rowSpacing)
            ongoingCallControlsBottomRow.autoPinEdge(toSuperviewEdge:.bottom, withInset:bottomMargin)
            ongoingCallControlsTopRow.autoPinEdge(toSuperviewEdge:.left, withInset:ongoingHMargin)
            ongoingCallControlsBottomRow.autoPinEdge(toSuperviewEdge:.left, withInset:ongoingHMargin)
            ongoingCallControlsTopRow.autoPinEdge(toSuperviewEdge:.right, withInset:ongoingHMargin)
            ongoingCallControlsBottomRow.autoPinEdge(toSuperviewEdge:.right, withInset:ongoingHMargin)

            textMessageButton.autoCenterInSuperview()
            textMessageButton.autoPinEdge(.top, to:.top, of:textMessageButton.superview!)
            textMessageButton.autoPinEdge(.bottom, to:.bottom, of:textMessageButton.superview!)

            muteButton.autoPinEdge(.top, to:.top, of:muteButton.superview!)
            muteButton.autoPinEdge(.bottom, to:.bottom, of:muteButton.superview!)
            hangUpButton.autoCenterInSuperview()
            hangUpButton.autoPinEdge(.top, to:.top, of:hangUpButton.superview!)
            hangUpButton.autoPinEdge(.bottom, to:.bottom, of:hangUpButton.superview!)
            speakerPhoneButton.autoPinEdge(.top, to:.top, of:speakerPhoneButton.superview!)
            speakerPhoneButton.autoPinEdge(.bottom, to:.bottom, of:speakerPhoneButton.superview!)
            muteButton.autoPinEdge(toSuperviewEdge:.left, withInset:0)
            speakerPhoneButton.autoPinEdge(toSuperviewEdge:.right, withInset:0)

            // Incoming call controls
            incomingCallControlsRow.autoPinEdge(toSuperviewEdge:.bottom, withInset:bottomMargin)
            incomingCallControlsRow.autoPinEdge(toSuperviewEdge:.left, withInset:incomingHMargin)
            incomingCallControlsRow.autoPinEdge(toSuperviewEdge:.right, withInset:incomingHMargin)

            acceptIncomingButton.autoPinEdge(.top, to:.top, of:acceptIncomingButton.superview!)
            acceptIncomingButton.autoPinEdge(.bottom, to:.bottom, of:acceptIncomingButton.superview!)
            declineIncomingButton.autoPinEdge(.top, to:.top, of:declineIncomingButton.superview!)
            declineIncomingButton.autoPinEdge(.bottom, to:.bottom, of:declineIncomingButton.superview!)
            acceptIncomingButton.autoPinEdge(toSuperviewEdge:.left, withInset:0)
            declineIncomingButton.autoPinEdge(toSuperviewEdge:.right, withInset:0)
        }
        
        super.updateViewConstraints()
    }
    
    // objc accessible way to set our swift enum.
    func setOutgoingCallDirection() {
        callDirection = .outgoing
    }

    // objc accessible way to set our swift enum.
    func setIncomingCallDirection() {
        callDirection = .incoming
    }

    func showCallFailed(error: Error) {
        // TODO Show something in UI.
        Logger.error("\(TAG) call failed with error: \(error)")
    }

    func localizedTextForCallState(_ callState: CallState) -> String {
        switch callState {
        case .idle, .remoteHangup, .localHangup:
            return NSLocalizedString("IN_CALL_TERMINATED", comment: "Call setup status label")
        case .dialing:
            return NSLocalizedString("IN_CALL_CONNECTING", comment: "Call setup status label")
        case .remoteRinging, .localRinging:
            return NSLocalizedString("IN_CALL_RINGING", comment: "Call setup status label")
        case .answering:
            return NSLocalizedString("IN_CALL_SECURING", comment: "Call setup status label")
        case .connected:
            return NSLocalizedString("IN_CALL_TALKING", comment: "Call setup status label")
        case .remoteBusy:
            return NSLocalizedString("END_CALL_RESPONDER_IS_BUSY", comment: "Call setup status label")
        case .localFailure:
            return NSLocalizedString("END_CALL_UNCATEGORIZED_FAILURE", comment: "Call setup status label")
        }
    }

    func updateCallUI(callState: CallState) {
        let textForState = localizedTextForCallState(callState)
        Logger.info("\(TAG) new call status: \(callState) aka \"\(textForState)\"")

        self.callStatusLabel.text = textForState

        // Show Incoming vs. (Outgoing || Accepted) call controls
        callControls.isHidden = callState == .localRinging
        incomingCallControls.isHidden = callState != .localRinging

        // Dismiss Handling
        switch callState {
        case .remoteHangup, .remoteBusy, .localFailure:
            Logger.debug("\(TAG) dismissing after delay because new state is \(textForState)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.dismiss(animated: true)
            }
        case .localHangup:
            Logger.debug("\(TAG) dismissing immediately from local hangup")
            self.dismiss(animated: true)

        default: break
        }
        
        let isRinging = callState == .localRinging
        for subview in allCallControls() {
            // Hide ongoing controls while ringing and hide incoming controls otherwise.
            let isIncomingCallControl = allIncomingCallControls().contains(subview)
            subview.isHidden = isIncomingCallControl != isRinging
        }
    }
    
    func allCallControls() -> [UIView] {
        return allIncomingCallControls() + allOngoingCallControls()
    }
    
    func allIncomingCallControls() -> [UIView] {
        return [ acceptIncomingButton, declineIncomingButton, ]
    }
    
    func allOngoingCallControls() -> [UIView] {
        return [ muteButton, speakerPhoneButton, textMessageButton, hangUpButton, ]
    }

    // MARK: - Actions

    func callStateDidChange(_ newState: CallState) {
        DispatchQueue.main.async {
            self.updateCallUI(callState: newState)
        }
        self.audioService.handleState(newState)
    }

    /**
     * Ends a connected call. Do not confuse with `didPressDeclineCall`.
     */
    @IBAction func didPressHangup(sender: UIButton) {
        Logger.info("\(TAG) called \(#function)")
        if let call = self.call {
            callUIAdapter.endCall(call)
        } else {
            Logger.warn("\(TAG) hung up, but call was unexpectedly nil")
        }

        self.dismiss(animated: true)
    }

    @IBAction func didPressMute(sender muteButton: UIButton) {
        Logger.info("\(TAG) called \(#function)")
        muteButton.isSelected = !muteButton.isSelected
        CallService.signalingQueue.async {
            self.callService.handleToggledMute(isMuted: muteButton.isSelected)
        }
    }
    
    @IBAction func didPressSpeakerphone(sender speakerphoneButton: UIButton) {
        Logger.info("\(TAG) called \(#function)")
        speakerphoneButton.isSelected = !speakerphoneButton.isSelected
        audioService.isSpeakerphoneEnabled = speakerphoneButton.isSelected
    }
    
    @IBAction func didPressTextMessage(sender speakerphoneButton: UIButton) {
        Logger.info("\(TAG) called \(#function)")
    }

    @IBAction func didPressAnswerCall(sender: UIButton) {
        Logger.info("\(TAG) called \(#function)")

        guard let call = self.call else {
            Logger.error("\(TAG) call was unexpectedly nil. Terminating call.")
            self.callStatusLabel.text = NSLocalizedString("END_CALL_UNCATEGORIZED_FAILURE", comment: "Call setup status label")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.dismiss(animated: true)
            }
            return
        }

        CallService.signalingQueue.async {
            self.callService.handleAnswerCall(call)
        }
    }

    /**
     * Denies an incoming not-yet-connected call, Do not confuse with `didPressHangup`.
     */
    @IBAction func didPressDeclineCall(sender: UIButton) {
        Logger.info("\(TAG) called \(#function)")

        if let call = self.call {
            callUIAdapter.declineCall(call)
        } else {
            Logger.warn("\(TAG) denied call, but call was unexpectedly nil")
        }

        self.dismiss(animated: true)
    }
}

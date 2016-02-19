//
//  PeripheralViewController.swift
//  BLESampler
//

import CoreBluetooth
import UIKit

class PeripheralViewController: UIViewController {

    // generate by uuidgen
    static private let ServiceUUID = CBUUID(string: "A8C7922D-8849-4FBC-8692-4DBB291F99C8")
    static private let CharacteristicsUUID = CBUUID(string: "D2E2C5E2-B0B9-4AF6-9AD9-361A819FB30F")
    
    private let characteristic = CBMutableCharacteristic(
        type: PeripheralViewController.CharacteristicsUUID,
        properties: .Notify, value: nil, permissions: .Readable)
    
    @IBOutlet private weak var peripheralStateLabel: UILabel!
    @IBOutlet private weak var advertisingStateLabel: UILabel!
    @IBOutlet private weak var serviceSwitch: UISwitch!
    @IBOutlet private weak var startButton: UIButton!
    @IBOutlet private weak var fooButton: UIButton!
    @IBOutlet private weak var barButton: UIButton!
    @IBOutlet private weak var bazButton: UIButton!
    
    private var peripheralManager: CBPeripheralManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.peripheralManager = CBPeripheralManager(
            delegate: self, queue: nil,
            options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.peripheralManager?.isAdvertising == true {
            stopAdvertising()
        }
        
        self.peripheralManager = nil
    }
    
    // MARK: - UI Handler
    @IBAction private func serviceSwitchValueChanged(sender: UISwitch) {
        if sender.on {
            let service = CBMutableService(type: PeripheralViewController.ServiceUUID, primary: true)
            service.characteristics = [self.characteristic]
            self.peripheralManager?.addService(service)
        } else {
            self.peripheralManager?.removeAllServices()
        }
    }
    
    @IBAction private func startButtonDidTouchUpInside(sender: UIButton) {
        self.advertisingStateLabel.text = ""
        
        if self.peripheralManager?.isAdvertising == false {
            self.startButton.setTitle(
                NSLocalizedString("Stop Advertising", comment: ""), forState: .Normal)
            startAdvertising()
        } else {
            self.startButton.setTitle(
                NSLocalizedString("Start Advertising", comment: ""), forState: .Normal)
            stopAdvertising()
        }
    }
    
    @IBAction private func fooButtonDidTouchUpInside(sender: UIButton) {
        guard let data = "foo".dataUsingEncoding(NSUTF8StringEncoding) else {
            fatalError("Failed dataUsingEncoding")
        }
        
        self.peripheralManager?.updateValue(
            data,
            forCharacteristic: self.characteristic,
            onSubscribedCentrals: nil)
    }
    
    @IBAction private func barButtonDidTouchUpInside(sender: UIButton) {
        guard let data = "bar".dataUsingEncoding(NSUTF8StringEncoding) else {
            fatalError("Failed dataUsingEncoding")
        }
        
        self.peripheralManager?.updateValue(
            data,
            forCharacteristic: self.characteristic,
            onSubscribedCentrals: nil)
    }
    
    @IBAction private func bazButtonDidTouchUpInside(sender: UIButton) {
        guard let data = "baz".dataUsingEncoding(NSUTF8StringEncoding) else {
            fatalError("Failed dataUsingEncoding")
        }
        
        self.peripheralManager?.updateValue(
            data,
            forCharacteristic: self.characteristic,
            onSubscribedCentrals: nil)
    }
    
    // MARK: - Private
    private func startAdvertising() {
        self.peripheralManager?.startAdvertising(
            [CBAdvertisementDataLocalNameKey: UIDevice.currentDevice().name,
            CBAdvertisementDataServiceUUIDsKey: [PeripheralViewController.ServiceUUID]])
    }
    
    private func stopAdvertising() {
        self.peripheralManager?.stopAdvertising()
    }
}

// MARK: - CBPeripheralManagerDelegate
extension PeripheralViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        var state = ""
        switch peripheral.state {
            case .Unknown :
                state = "Unknown"
            case .Resetting :
                state = "Resetting"
            case .Unsupported :
                state = "Unsupported"
            case .Unauthorized :
                state = "Unauthorized"
            case .PoweredOff :
                state = "PoweredOff"
            case .PoweredOn : ()
                state = "PoweredOn"
        }
        self.peripheralStateLabel.text = "Peripheral state: \(state)"
    }
    
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err) ")
            
            self.advertisingStateLabel.text = NSLocalizedString("Failed to start advertising", comment: "")
            self.startButton.setTitle(
                NSLocalizedString("Start Advertising", comment: ""), forState: .Normal)
        } else {
            self.advertisingStateLabel.text = NSLocalizedString("Start advertising...", comment: "")
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
        self.advertisingStateLabel.text = NSLocalizedString("Subscribe to characteristic", comment: "")
        
        if self.peripheralManager?.isAdvertising == true {
            stopAdvertising()
            self.startButton.setTitle(
                NSLocalizedString("Start Advertising", comment: ""), forState: .Normal)
        }
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
        self.advertisingStateLabel.text = NSLocalizedString("Unsubscribe to characteristic", comment: "")
    }
    
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err) ")
            
            self.serviceSwitch.on = false
        }
    }
}

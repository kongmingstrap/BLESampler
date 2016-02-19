//
//  CentralViewController.swift
//  BLESampler
//

import CoreBluetooth
import UIKit

class CentralViewController: UIViewController {

    // generate by uuidgen
    static private let ServiceUUID = CBUUID(string: "A8C7922D-8849-4FBC-8692-4DBB291F99C8")
    static private let CharacteristicsUUID = CBUUID(string: "D2E2C5E2-B0B9-4AF6-9AD9-361A819FB30F")
    
    static private let CellIdentifier = "FoundPeripheralsCellIdentifier"
    
    private let ScanningTimeInterval: NSTimeInterval = 1.0
    
    @IBOutlet private weak var scanButton: UIButton!
    @IBOutlet private weak var retrieveConnectedButton: UIButton!
    @IBOutlet private weak var centralStateLabel: UILabel!
    @IBOutlet private weak var connectedPeripheralLabel: UILabel!
    @IBOutlet private weak var foundPeripheralsTableView: UITableView!
    
    private var centralManager: CBCentralManager?
    private var scanTimer: NSTimer?
    private var connectedPeripheral: CBPeripheral?
    
    private(set) var foundPeripherals = [CBPeripheral]()
    
    var poweredOn: Bool {
        return self.centralManager?.state == CBCentralManagerState.PoweredOn
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.connectedPeripheralLabel.text = ""
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.centralManager = CBCentralManager(
            delegate: self, queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        disconnect()
        
        self.centralManager = nil
    }
    
    func setNotify(notify: Bool, peripheral: CBPeripheral) {
        if let services = peripheral.services {
            services.filter { service in
                service.UUID.data == CentralViewController.ServiceUUID.data
            }.flatMap { service in
                service.characteristics ?? []
            }.filter { characteristic in
                characteristic.UUID.isEqual(CentralViewController.CharacteristicsUUID) &&
                    (characteristic.properties.intersect(CBCharacteristicProperties.Notify) != [])
            }.forEach { characteristic in
                peripheral.setNotifyValue(notify, forCharacteristic: characteristic)
                peripheral.readRSSI()
            }
        }
    }
    
    func readPeripheral(peripheral: CBPeripheral) {
        if let services = peripheral.services {
            services.filter { service in
                service.UUID.data == CentralViewController.ServiceUUID.data
            }.flatMap { service in
                service.characteristics ?? []
            }.filter { characteristic in
                characteristic.UUID.isEqual(CentralViewController.CharacteristicsUUID) &&
                    (characteristic.properties.intersect(CBCharacteristicProperties.Write) != [])
            }.forEach { characteristic in
                peripheral.readValueForCharacteristic(characteristic)
            }
        }
    }
    
    func writePeripheral(peripheral: CBPeripheral, value: NSData) {
        if let services = peripheral.services {
            services.filter { service in
                service.UUID.data == CentralViewController.ServiceUUID.data
            }.flatMap { service in
                service.characteristics ?? []
            }.filter { characteristic in
                characteristic.UUID.isEqual(CentralViewController.CharacteristicsUUID) &&
                    (characteristic.properties.intersect(CBCharacteristicProperties.Write) != [])
            }.forEach { characteristic in
                peripheral.writeValue(
                    value,
                    forCharacteristic: characteristic,
                    type: .WithResponse
                )
            }
        }
    }
    
    internal func configureForScanningEnd(sender: AnyObject) {
        stopScan()
        self.foundPeripheralsTableView.reloadData()
    }
    
    // MARK: - UI Handler
    @IBAction private func scanButtonDidTouchUpInside(sender: UIButton) {
        startScan()
    }
    
    @IBAction private func retrieveConnectedButtonDidTouchUpInside(sender: UIButton) {
        guard let manager = self.centralManager else {
            return
        }
        
        let identifiers = self.foundPeripherals.map { peripheral in
            peripheral.identifier
        }
        self.foundPeripherals = manager.retrievePeripheralsWithIdentifiers(identifiers)
        self.foundPeripheralsTableView.reloadData()
    }
    
    // MARK: - Private
    private func startScan() {
        clearDevices()
        if self.poweredOn {
            self.centralManager?.scanForPeripheralsWithServices(
                [CentralViewController.ServiceUUID],
                options: nil)
            self.scanTimer = NSTimer.scheduledTimerWithTimeInterval(
                ScanningTimeInterval, target: self, selector: "configureForScanningEnd:",
                userInfo: nil, repeats: false)
        }
    }
    
    private func stopScan() {
        self.centralManager?.stopScan()
    }
    
    private func connectPeripheral(peripheral: CBPeripheral) {
        if peripheral.state != .Connected {
            self.centralManager?.connectPeripheral(peripheral, options: nil)
        }
    }
    
    private func disconnectPeripheral(peripheral: CBPeripheral) {
        self.centralManager?.cancelPeripheralConnection(peripheral)
    }
    
    private func disconnect() {
        self.foundPeripherals.filter { peripheral in
            peripheral.state == .Connected
        }.forEach { [unowned self] peripheral in
            self.disconnectPeripheral(peripheral)
        }
        
        clearDevices()
    }
    
    private func clearDevices() {
        self.foundPeripherals.removeAll(keepCapacity: false)
    }
}

// MARK: - CBCentralManagerDelegate
extension CentralViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(central: CBCentralManager) {
        var state = ""
        switch central.state {
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
        
        self.centralStateLabel.text = "Central state: \(state)"
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let foundIds = self.foundPeripherals.map { peripheral in
            peripheral.identifier.UUIDString
        }
        
        if !foundIds.contains(peripheral.identifier.UUIDString) {
            self.foundPeripherals.append(peripheral)
        }
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.connectedPeripheral = peripheral
        self.connectedPeripheral?.delegate = self
        self.connectedPeripheral?.discoverServices([CentralViewController.ServiceUUID])
        
        self.foundPeripheralsTableView.reloadData()
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err)")
        }
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err)")
            
            switch err.code {
            case 10 :
                connectPeripheral(peripheral)
            default :
                let controller = UIAlertController(
                    title: nil,
                    message: NSLocalizedString("The connection to the device closed.", comment: ""),
                    preferredStyle: .Alert)
                let okAction = UIAlertAction(
                    title: NSLocalizedString("OK", comment:""),
                    style: .Default, handler: nil)
                controller.addAction(okAction)
                self.presentViewController(controller, animated: true, completion: nil)
            }
        }
        
        self.foundPeripheralsTableView.reloadData()
    }
}

// MARK: - CBPeripheralDelegate
extension CentralViewController: CBPeripheralDelegate {
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err)")
            return
        }
        
        if let services = peripheral.services {
            services.filter { service in
                service.UUID.data == CentralViewController.ServiceUUID.data
            }.forEach { service in
                peripheral.discoverCharacteristics(
                    [CentralViewController.CharacteristicsUUID],
                    forService: service
                )
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err)")
            
            return
        }
        
        if service.UUID.data == CentralViewController.ServiceUUID.data, let characteristics = service.characteristics {
            characteristics.filter { characteristic in
                characteristic.UUID.isEqual(CentralViewController.CharacteristicsUUID)
            }.forEach { [unowned self] characteristic in
                self.setNotify(true, peripheral: peripheral)
                self.readPeripheral(peripheral)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let err = error {
            print("\(__FUNCTION__) error: \(err)")
            
            return
        }
        
        if characteristic.UUID.data == CentralViewController.CharacteristicsUUID.data {
            guard let value = characteristic.value else {
                fatalError("invalid characteristic value.")
            }
            
            guard let string = String(data: value, encoding: NSUTF8StringEncoding) else {
                return
            }
            
            self.connectedPeripheralLabel.text = string
        }
    }
}

// MARK: - UITableViewDelegate
extension CentralViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.foundPeripherals.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(
            CentralViewController.CellIdentifier, forIndexPath: indexPath)
        
        let peripheral = self.foundPeripherals[indexPath.row]
        
        cell.textLabel?.text = peripheral.name ?? NSLocalizedString("Unknown Device", comment: "")
        
        if peripheral.state == .Connected {
            cell.accessoryType = .Checkmark
        } else {
            cell.accessoryType = .None
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension CentralViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let peripheral = self.foundPeripherals[indexPath.row]
        
        if let cp = self.connectedPeripheral where cp == peripheral {
            disconnectPeripheral(peripheral)
            self.connectedPeripheral = nil
        } else {
            connectPeripheral(peripheral)
        }
    }
}

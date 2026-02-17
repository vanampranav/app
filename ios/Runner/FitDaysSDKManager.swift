import Flutter
import UIKit
import CoreBluetooth
import FitDaysSDK // Standard import if Framework is added

class FitDaysSDKManager: NSObject, ICDeviceManagerDelegate, ICScanDeviceDelegate {
    
    private var eventSink: FlutterEventSink?
    private var connectedDevice: ICDevice?
    private var isScanning = false
    private var isSdkInitialized = false
    
    override init() {
        super.init()
    }
    
    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    // MARK: - SDK Initialization
    
    func initializeSDK(age: Int, height: Int, sex: String) {
        let userInfo = ICUserInfo()
        userInfo.age = age
        userInfo.height = height
        userInfo.sex = (sex.lowercased() == "female") ? .female : .male
        userInfo.peopleType = .normal
        
        ICDeviceManager.shared.updateUserInfo(userInfo)
        
        if isSdkInitialized {
            return
        }
        
        ICDeviceManager.shared.delegate = self
        ICDeviceManager.shared.initMgr()
        
        // Simulate async init success for consistency with Android flow
        isSdkInitialized = true
        sendEvent("sdkInitialized", data: ["success": true])
    }
    
    func getSDKVersion() -> String {
        return ICDeviceManager.shared.version ?? "Unknown"
    }
    
    // MARK: - Permissions
    
    func checkBluetoothPermissions() -> Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        return true // Fallback/Assumption
    }
    
    // MARK: - App Lifecycle / Scanning
    
    func startScan() {
        if !isSdkInitialized {
            sendEvent("error", data: ["message": "SDK not initialized", "code": "SDK_NOT_INIT"])
            return
        }
        
        if !isScanning {
            isScanning = true
            ICDeviceManager.shared.scanDevice(self)
            sendEvent("scanStarted", data: nil)
        }
    }
    
    func stopScan() {
        if isScanning {
            ICDeviceManager.shared.stopScan()
            isScanning = false
            sendEvent("scanStopped", data: nil)
        }
    }
    
    // MARK: - Connection
    
    func connectDevice(macAddress: String) {
        let device = ICDevice()
        device.macAddr = macAddress
        
        // Demo uses addDevice for connection
        ICDeviceManager.shared.addDevice(device) { (dev, code) in
            if code == .success {
                self.connectedDevice = dev
                self.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "connected"])
            } else {
                self.sendEvent("error", data: ["message": "Connection failed", "code": "CONNECTION_ERROR"])
            }
        }
    }
    
    func disconnectDevice(macAddress: String) {
        if let device = connectedDevice, device.macAddr == macAddress {
            // Demo uses removeDevice for disconnection
            ICDeviceManager.shared.removeDevice(device) { (dev, code) in
                self.connectedDevice = nil
                self.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "disconnected"])
            }
        }
    }
    
    // MARK: - Commands
    
    func sendTareCommand(completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else {
            completion(false)
            return
        }
        
        ICDeviceManager.shared.settingManager.deleteTareWeight(device) { (code) in
            completion(code == .success)
        }
    }
    
    func sendUnitChangeCommand(unit: String, completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else {
            completion(false)
            return
        }
        
        var sdkUnit: ICKitchenScaleUnit = .g
        switch unit {
        case "g": sdkUnit = .g
        case "ml": sdkUnit = .ml
        case "oz": sdkUnit = .oz
        case "lb": sdkUnit = .lb
        case "ml_m": sdkUnit = .mlMilk
        case "fl_oz_m": sdkUnit = .flOzMilk
        case "fl_oz": sdkUnit = .flOzWater
        case "mg": sdkUnit = .mg
        default: sdkUnit = .g
        }
        
        ICDeviceManager.shared.settingManager.setKitchenScaleUnit(device, unit: sdkUnit) { (code) in
            completion(code == .success)
        }
    }
    
    // MARK: - ICScanDeviceDelegate
    
    func onScanResult(_ deviceInfo: ICScanDeviceInfo?) {
        guard let info = deviceInfo else { return }
        
        var data: [String: Any] = [
            "name": info.name ?? "Unknown",
            "macAddress": info.macAddr ?? "",
            "rssi": info.rssi
        ]
        
        sendEvent("deviceFound", data: data)
    }
    
    // MARK: - ICDeviceManagerDelegate
    
    func onDeviceConnectionChanged(_ device: ICDevice?, state: ICDeviceConnectState) {
        guard let device = device else { return }
        
        var status = "connecting"
        if state == .connected {
            status = "connected"
            self.connectedDevice = device
        } else if state == .disconnected {
            status = "disconnected"
            if self.connectedDevice?.macAddr == device.macAddr {
                self.connectedDevice = nil
            }
        }
        
        sendEvent("connectionStateChanged", data: ["macAddress": device.macAddr, "state": status])
    }
    
    func onReceiveKitchenScaleData(_ device: ICDevice?, data: ICKitchenScaleData?) {
        guard let data = data else { return }
        
        // Negative Weight Handling
        var weight = data.value_g // Default to grams for simplicity or map per unit
        // Mapping conceptual logic from Android
        // Need to check specific unit values if implementing full unit support here, 
        // but typically we standardize on one or pass raw values.
        // Let's assume we pass what we get or standard grams.
        // For accurate display, we should respect the unit. 
        
        var unitStr = "g"
        switch data.unit {
            case .g: weight = data.value_g; unitStr = "g"
            case .ml: weight = data.value_ml; unitStr = "ml"
            case .oz: weight = data.value_oz; unitStr = "oz"
            case .lb: weight = data.value_lb_oz; unitStr = "lb" // Assuming double support in Swift SDK
            case .mg: weight = data.value_mg; unitStr = "mg"
            case .mlMilk: weight = data.value_ml_milk; unitStr = "ml_m"
            case .flOzMilk: weight = data.value_fl_oz_milk; unitStr = "fl_oz_m"
            case .flOzWater: weight = data.value_fl_oz; unitStr = "fl_oz"
            default: weight = data.value_g; unitStr = "g"
        }
        
        // CRITICAL FIX: Negative Weight Handling
        if data.isNegative {
            weight = -abs(weight)
        }
        
        let eventData: [String: Any] = [
            "weight": weight,
            "unit": unitStr,
            "isStabilized": true,
            "hasBodyComposition": false
        ]
        
        sendEvent("weightData", data: eventData)
    }
    
    func onReceiveWeightData(_ device: ICDevice?, data: ICWeightData?) {
        guard let data = data else { return }
        
        var eventData: [String: Any] = [
            "weight": data.weight_kg,
            "unit": "kg",
            "isStabilized": data.isStabilized,
        ]
        
        if data.imp != 0 {
             eventData["bmi"] = data.bmi
             eventData["bodyFat"] = data.bodyFatPercent
             eventData["muscle"] = data.musclePercent
             eventData["water"] = data.moisturePercent
             eventData["boneMass"] = data.boneMass
             eventData["protein"] = data.proteinPercent
             eventData["bmr"] = data.bmr
             eventData["visceralFat"] = data.visceralFat
             eventData["skeletalMuscle"] = data.smPercent
             eventData["physicalAge"] = data.physicalAge
        }
        
        sendEvent("weightData", data: eventData)
    }
    
    func onReceiveBattery(_ device: ICDevice?, battery: Int, ext: Any?) {
        guard let device = device else { return }
        sendEvent("batteryLevel", data: ["macAddress": device.macAddr ?? "", "battery": battery])
    }
    
    func onReceiveKitchenScaleUnitChanged(_ device: ICDevice?, unit: ICKitchenScaleUnit) {
        guard let device = device else { return }
        
        var unitStr = "g"
        switch unit {
        case .g: unitStr = "g"
        case .ml: unitStr = "ml"
        case .oz: unitStr = "oz"
        case .lb: unitStr = "lb"
        case .mg: unitStr = "mg"
        case .mlMilk: unitStr = "ml_m"
        case .flOzMilk: unitStr = "fl_oz_m"
        case .flOzWater: unitStr = "fl_oz"
        default: unitStr = "g"
        }
        
        sendEvent("kitchenScaleUnitChanged", data: ["deviceId": device.macAddr ?? "", "unit": unitStr])
    }
    
    // Note: iOS SDK naming for MeasureStep might differ, assuming typical ObjC->Swift mapping
    // If ICMeasureStep is an enum, we bridge it similarly
    /*
    func onReceiveMeasureStepData(_ device: ICDevice?, step: ICMeasureStep, data: Any?) {
         var stepStr = "unknown"
         // Map step enum to string if possible, e.g. .measuring, .finished
         
         // Forwarding logic similar to Android
         if let kitchenData = data as? ICKitchenScaleData {
             onReceiveKitchenScaleData(device, data: kitchenData)
         } else if let weightData = data as? ICWeightData {
             onReceiveWeightData(device, data: weightData)
         }
    }
    */
    
    // MARK: - Helper
    
    private func sendEvent(_ type: String, data: [String: Any]?) {
        guard let sink = eventSink else { return }
        let event: [String: Any] = [
            "type": type,
            "data": data ?? [:]
        ]
        sink(event)
    }
}

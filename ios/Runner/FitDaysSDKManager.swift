import Flutter
import UIKit
import CoreBluetooth

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
        userInfo.age = UInt(age)
        userInfo.height = UInt(height)
        userInfo.sex = (sex.lowercased() == "female") ? ICSexTypeFemal : ICSexTypeMale
        userInfo.peopleType = ICPeopleTypeNormal
        
        ICDeviceManager.shared().updateUserInfo(userInfo)
        
        if isSdkInitialized {
            return
        }
        
        ICDeviceManager.shared().delegate = self
        ICDeviceManager.shared().initMgr()
        
        // Simulate async init success for consistency with Android flow
        isSdkInitialized = true
        sendEvent("sdkInitialized", data: ["success": true])
    }
    
    func getSDKVersion() -> String {
        return ICDeviceManager.version() ?? "Unknown"
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
            ICDeviceManager.shared().scanDevice(self)
            sendEvent("scanStarted", data: nil)
        }
    }
    
    func stopScan() {
        if isScanning {
            ICDeviceManager.shared().stopScan()
            isScanning = false
            sendEvent("scanStopped", data: nil)
        }
    }
    
    // MARK: - Connection
    
    func connectDevice(macAddress: String) {
        let device = ICDevice()
        device.macAddr = macAddress
        
        // Demo uses addDevice for connection
        ICDeviceManager.shared().addDevice(device) { (dev, code) in
            if code == ICAddDeviceCallBackCodeSuccess {
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
            ICDeviceManager.shared().removeDevice(device) { (dev, code) in
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
        
        ICDeviceManager.shared().getSettingManager().deleteTareWeight(device) { (code) in
            completion(code == ICSettingCallBackCodeSuccess)
        }
    }
    
    func sendUnitChangeCommand(unit: String, completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else {
            completion(false)
            return
        }
        
        var sdkUnit: ICKitchenScaleUnit = ICKitchenScaleUnitG
        switch unit {
        case "g": sdkUnit = ICKitchenScaleUnitG
        case "ml": sdkUnit = ICKitchenScaleUnitMl
        case "oz": sdkUnit = ICKitchenScaleUnitOz
        case "lb": sdkUnit = ICKitchenScaleUnitLb
        case "ml_m": sdkUnit = ICKitchenScaleUnitMlMilk
        case "fl_oz_m": sdkUnit = ICKitchenScaleUnitFlOzMilk
        case "fl_oz": sdkUnit = ICKitchenScaleUnitFlOzWater
        case "mg": sdkUnit = ICKitchenScaleUnitMg
        default: sdkUnit = ICKitchenScaleUnitG
        }
        
        ICDeviceManager.shared().getSettingManager().setKitchenScaleUnit(device, unit: sdkUnit) { (code) in
            completion(code == ICSettingCallBackCodeSuccess)
        }
    }
    
    // MARK: - ICScanDeviceDelegate
    
    func onScanResult(_ deviceInfo: ICScanDeviceInfo?) {
        guard let info = deviceInfo else { return }
        
        let data: [String: Any] = [
            "name": info.name ?? "Unknown",
            "macAddress": info.macAddr ?? "",
            "rssi": info.rssi
        ]
        
        sendEvent("deviceFound", data: data)
    }
    
    // MARK: - ICDeviceManagerDelegate
    
    func onDeviceConnectionChanged(_ device: ICDevice!, state: ICDeviceConnectState) {
        guard let device = device else { return }
        
        var status = "connecting"
        if state == ICDeviceConnectStateConnected {
            status = "connected"
            self.connectedDevice = device
        } else if state == ICDeviceConnectStateDisconnected {
            status = "disconnected"
            if self.connectedDevice?.macAddr == device.macAddr {
                self.connectedDevice = nil
            }
        }
        
        sendEvent("connectionStateChanged", data: ["macAddress": device.macAddr, "state": status])
    }
    
    func onReceiveKitchenScaleData(_ device: ICDevice!, data: ICKitchenScaleData!) {
        guard let data = data else { return }
        
        // Negative Weight Handling
        var weight = data.value_g // Default to grams for simplicity or map per unit
        
        var unitStr = "g"
        switch data.unit {
            case ICKitchenScaleUnitG: weight = data.value_g; unitStr = "g"
            case ICKitchenScaleUnitMl: weight = data.value_ml; unitStr = "ml"
            case ICKitchenScaleUnitOz: weight = data.value_oz; unitStr = "oz"
            case ICKitchenScaleUnitLb: weight = data.value_lb_oz; unitStr = "lb"
            case ICKitchenScaleUnitMg: weight = data.value_mg; unitStr = "mg"
            case ICKitchenScaleUnitMlMilk: weight = data.value_ml_milk; unitStr = "ml_m"
            case ICKitchenScaleUnitFlOzMilk: weight = data.value_fl_oz_milk; unitStr = "fl_oz_m"
            case ICKitchenScaleUnitFlOzWater: weight = data.value_fl_oz; unitStr = "fl_oz"
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
    
    func onReceiveWeightData(_ device: ICDevice!, data: ICWeightData!) {
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
    
    func onReceiveBattery(_ device: ICDevice!, battery: Int32, ext: Any!) {
        guard let device = device else { return }
        sendEvent("batteryLevel", data: ["macAddress": device.macAddr ?? "", "battery": Int(battery)])
    }
    
    func onReceiveKitchenScaleUnitChanged(_ device: ICDevice!, unit: ICKitchenScaleUnit) {
        guard let device = device else { return }
        
        var unitStr = "g"
        switch unit {
        case ICKitchenScaleUnitG: unitStr = "g"
        case ICKitchenScaleUnitMl: unitStr = "ml"
        case ICKitchenScaleUnitOz: unitStr = "oz"
        case ICKitchenScaleUnitLb: unitStr = "lb"
        case ICKitchenScaleUnitMg: unitStr = "mg"
        case ICKitchenScaleUnitMlMilk: unitStr = "ml_m"
        case ICKitchenScaleUnitFlOzMilk: unitStr = "fl_oz_m"
        case ICKitchenScaleUnitFlOzWater: unitStr = "fl_oz"
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

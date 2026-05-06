import Flutter
import UIKit
import CoreBluetooth
import os.log

class FitDaysSDKManager: NSObject, ICDeviceManagerDelegate, ICScanDeviceDelegate {
    
    private var eventSink: FlutterEventSink?
    private var connectedDevice: ICDevice?
    private var isScanning = false
    private var isSdkInitialized = false
    private let logger = OSLog(subsystem: "com.theelefit.app", category: "FitDaysSDK")
    
    override init() {
        super.init()
    }
    
    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    // MARK: - SDK Initialization
    
    func initializeSDK(age: Int, height: Int, sex: String) {
        os_log("initializeSDK called with age: %d, height: %d, sex: %@", log: logger, type: .info, age, height, sex)
        
        // Create user info for body composition calculations
        let userInfo = ICUserInfo()
        userInfo.age = UInt(age)
        userInfo.height = UInt(height)
        
        // Set sex type via rawValue (bare ObjC enum names are not in Swift scope from xcframework).
        // ICConstant.h: ICSexTypeUnknown=0, ICSexTypeMale=1, ICSexTypeFemal=2
        // FIXED: old code used rawValue 0 for female → Unknown. Female is rawValue 2.
        if sex.lowercased() == "female" {
            userInfo.sex = ICSexType(rawValue: 2)!  // ICSexTypeFemal
        } else {
            userInfo.sex = ICSexType(rawValue: 1)!  // ICSexTypeMale
        }
        userInfo.peopleType = ICPeopleType(rawValue: 0)  // ICPeopleTypeNormal
        
        // Always update user info
        ICDeviceManager.shared().update(userInfo)
        os_log("User info updated", log: logger, type: .info)
        
        if isSdkInitialized {
            os_log("SDK already initialized, skipping reinit", log: logger, type: .info)
            return
        }
        
        // Set delegate BEFORE initialization
        ICDeviceManager.shared().delegate = self
        
        // Initialize SDK
        ICDeviceManager.shared().initMgr()
        
        os_log("SDK initialization requested - waiting for onInitFinish callback", log: logger, type: .info)
    }
    
    func getSDKVersion() -> String {
        return ICDeviceManager.version() ?? "Unknown"
    }
    
    // MARK: - Permissions
    
    func checkBluetoothPermissions() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = CBCentralManager.authorization
            // Check for allowed states (allowedAlways, restricted)
            return auth == .allowedAlways || auth == .restricted
        }
        return true
    }
    
    // MARK: - Scanning
    
    func startScan() {
        os_log("startScan() called, isScanning=%{public}@, isSdkInitialized=%{public}@", 
               log: logger, type: .debug, String(isScanning), String(isSdkInitialized))
        
        if !isSdkInitialized {
            os_log("Cannot start scan: SDK not initialized", log: logger, type: .error)
            let data: [String: Any] = ["message": "SDK not initialized. Please wait or try again.", "code": "SDK_NOT_INIT"]
            sendEvent("error", data: data)
            return
        }
        
        if !isScanning {
            isScanning = true
            os_log("Calling ICDeviceManager.shared().scanDevice()", log: logger, type: .debug)
            
            ICDeviceManager.shared().scanDevice(self)
            sendEvent("scanStarted", data: nil)
            os_log("Scan started event sent", log: logger, type: .debug)
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
        
        ICDeviceManager.shared().add(device) { [weak self] (dev, code) in
            // ICAddDeviceCallBackCodeSuccess == 0
            if code.rawValue == 0 {
                self?.connectedDevice = dev
                self?.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "connected"])
            } else {
                self?.sendEvent("error", data: ["message": "Connection failed", "code": "CONNECTION_ERROR"])
            }
        }
    }
    
    func disconnectDevice(macAddress: String) {
        guard let device = connectedDevice, device.macAddr == macAddress else {
            return
        }
        
        ICDeviceManager.shared().remove(device) { [weak self] (dev, code) in
            self?.connectedDevice = nil
            self?.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "disconnected"])
        }
    }
    
    // MARK: - Commands
    
    func sendTareCommand(completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else {
            completion(false)
            return
        }
        
        ICDeviceManager.shared().getSettingManager().deleteTareWeight(device) { (code) in
            completion(code.rawValue == 0) // ICSettingCallBackCodeSuccess == 0
        }
    }
    
    func sendUnitChangeCommand(unit: String, completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else {
            completion(false)
            return
        }
        
        // Use rawValue — bare ObjC enum names (ICKitchenScaleUnitG etc.) are not in Swift scope.
        // iOS ICConstant.h ICKitchenScaleUnit order (DIFFERENT from Android):
        //   G=0, Ml=1, Lb=2, Oz=3, Mg=4, MlMilk=5, FlOzWater=6, FlOzMilk=7
        // Android order: G=0, Ml=1, Oz=2, Lb=3, Mg=4, MlMilk=5, FlOzMilk=6, FlOzWater=7
        // The previous code copied Android raw values → oz and lb were SWAPPED on iOS.
        var sdkUnitRaw: UInt = 0
        switch unit {
        case "g":       sdkUnitRaw = 0  // ICKitchenScaleUnitG
        case "ml":      sdkUnitRaw = 1  // ICKitchenScaleUnitMl
        case "lb":      sdkUnitRaw = 2  // ICKitchenScaleUnitLb  (iOS=2, Android=3)
        case "oz":      sdkUnitRaw = 3  // ICKitchenScaleUnitOz  (iOS=3, Android=2)
        case "mg":      sdkUnitRaw = 4  // ICKitchenScaleUnitMg
        case "ml_m":    sdkUnitRaw = 5  // ICKitchenScaleUnitMlMilk
        case "fl_oz":   sdkUnitRaw = 6  // ICKitchenScaleUnitFlOzWater (iOS=6, Android=7)
        case "fl_oz_m": sdkUnitRaw = 7  // ICKitchenScaleUnitFlOzMilk  (iOS=7, Android=6)
        default:        sdkUnitRaw = 0
        }
        
        let sdkUnit = ICKitchenScaleUnit(rawValue: sdkUnitRaw) ?? ICKitchenScaleUnit(rawValue: 0)!
        ICDeviceManager.shared().getSettingManager().setKitchenScaleUnit(device, unit: sdkUnit) { (code) in
            completion(code.rawValue == 0) // ICSettingCallBackCodeSuccess == 0
        }
    }
    
    // MARK: - ICScanDeviceDelegate
    
    @objc func onScanResult(_ deviceInfo: ICScanDeviceInfo?) {
        guard let info = deviceInfo else { return }
        
        os_log("onScanResult: %@ (%@) type=%lu", log: logger, type: .debug,
               info.name ?? "Unknown", info.macAddr ?? "", info.type.rawValue)
        
        // Map ICDeviceType rawValue to a string Flutter FitDaysDevice.fromMap() recognises.
        // Use rawValue — bare ObjC enum names (ICDeviceTypeKitchenScale etc.) not in Swift scope.
        // ICConstant.h: Unknown=0, WeightScale=1, FatScale=2, FatScaleWithTemperature=3,
        //               KitchenScale=4, Ruler=5, Balance=6, Skip=7, HR=8, Sphygmomanometer=9
        let typeRaw = info.type.rawValue
        let typeString: String
        switch typeRaw {
        case 4:    typeString = "KitchenScale"
        case 2, 3: typeString = "FatScale"
        case 1:    typeString = "WeightScale"
        case 5:    typeString = "Ruler"
        case 7:    typeString = "Skip"
        default:   typeString = "Unknown"
        }
        
        let data: [String: Any] = [
            "name": info.name ?? "Unknown",
            "macAddress": info.macAddr ?? "",
            "rssi": info.rssi,
            "type": typeString  // matches Flutter FitDaysDevice.fromMap() parsing
        ]
        
        sendEvent("deviceFound", data: data)
    }
    
    // MARK: - ICDeviceManagerDelegate (exact Objective-C selectors)
    
    @objc func onInitFinish(_ bSuccess: Bool) {
        os_log("onInitFinish called, success=%{public}@", log: logger, type: .debug, String(bSuccess))
        isSdkInitialized = bSuccess
        sendEvent("sdkInitialized", data: ["success": bSuccess])
    }
    
    @objc func onBleState(_ state: ICBleState) {
        os_log("onBleState: %d", log: logger, type: .debug, state.rawValue)
        sendEvent("bluetoothStateChanged", data: ["state": Int(state.rawValue)])
    }
    
    @objc func onDeviceConnectionChanged(_ device: ICDevice!, state: ICDeviceConnectState) {
        os_log("========== onDeviceConnectionChanged ==========", log: logger, type: .info)
        os_log("Device: %@", log: logger, type: .info, device.macAddr ?? "Unknown")
        os_log("State: %d", log: logger, type: .info, state.rawValue)
        
        var status = "connecting"
        
        if state.rawValue == 1 {  // ICDeviceConnectStateDisconnected
            os_log("Device DISCONNECTED - sending event", log: logger, type: .info)
            status = "disconnected"
            if connectedDevice?.macAddr == device.macAddr {
                connectedDevice = nil
            }
        } else if state.rawValue == 0 {  // ICDeviceConnectStateConnected
            os_log("Device CONNECTED - sending event", log: logger, type: .info)
            status = "connected"
            connectedDevice = device // CRITICAL: Keep device reference
        } else {
            os_log("Device CONNECTING - sending event", log: logger, type: .info)
        }
        
        sendEvent("connectionStateChanged", data: ["macAddress": device.macAddr ?? "", "state": status])
        os_log("========== Event sent ==========", log: logger, type: .info)
    }
    
    @objc func onNodeConnectionChanged(_ device: ICDevice!, nodeId: Int, state: ICDeviceConnectState) {
        sendEvent("nodeConnectionChanged", data: [
            "macAddress": device.macAddr ?? "",
            "nodeId": nodeId,
            "state": Int(state.rawValue)
        ])
    }
    
    @objc func onReceiveWeightData(_ device: ICDevice!, data: ICWeightData!) {
        guard let data = data else { return }
        
        os_log("========== onReceiveWeightData ==========", log: logger, type: .debug)
        os_log("Weight: %f kg", log: logger, type: .debug, data.weight_kg)
        os_log("Stabilized: %{public}@", log: logger, type: .debug, String(data.isStabilized))
        os_log("Impedance: %d", log: logger, type: .debug, data.imp)
        
        var weightData: [String: Any] = [
            "weight": data.weight_kg,
            "unit": "kg",
            "isStabilized": data.isStabilized
        ]
        
        // Body composition only available when impedance measured (imp != 0)
        if data.imp != 0 {
            os_log("Body composition data available", log: logger, type: .debug)
            weightData["bmi"] = data.bmi
            weightData["bodyFat"] = data.bodyFatPercent
            weightData["muscle"] = data.musclePercent
            weightData["water"] = data.moisturePercent
            weightData["boneMass"] = data.boneMass
            weightData["protein"] = data.proteinPercent
            weightData["bmr"] = data.bmr
            weightData["visceralFat"] = data.visceralFat
            weightData["skeletalMuscle"] = data.smPercent
            weightData["physicalAge"] = Int(data.physicalAge)
        }
        
        sendEvent("weightData", data: weightData)
        os_log("Weight data event sent", log: logger, type: .debug)
    }
    
    @objc func onReceiveKitchenScaleData(_ device: ICDevice!, data: ICKitchenScaleData!) {
        guard let data = data else { return }
        
        // CRITICAL: Update connectedDevice when receiving kitchen scale data
        // The SDK requires the exact instance currently streaming data for commands
        if device != nil {
            connectedDevice = device
        }
        
        os_log("onReceiveKitchenScaleData unit=%lu", log: logger, type: .debug, data.unit.rawValue)
        
        var weight: Float = 0.0
        var unitStr = "g"
        
        // Use rawValue — bare ObjC enum names (ICKitchenScaleUnitG etc.) are not in Swift scope.
        // iOS ICConstant.h ICKitchenScaleUnit order (DIFFERENT from Android):
        //   G=0, Ml=1, Lb=2, Oz=3, Mg=4, MlMilk=5, FlOzWater=6, FlOzMilk=7
        // Android order: G=0, Ml=1, Oz=2, Lb=3 — DO NOT copy Android raw values here.
        let unitRaw = Int(data.unit.rawValue)
        switch unitRaw {
        case 0: weight = data.value_g;         unitStr = "g"
        case 1: weight = data.value_ml;        unitStr = "ml"
        case 2: weight = data.value_lb_oz;     unitStr = "lb"   // iOS Lb=2 (Android Oz=2)
        case 3: weight = data.value_oz;        unitStr = "oz"   // iOS Oz=3 (Android Lb=3)
        case 4: weight = Float(data.value_mg); unitStr = "mg"
        case 5: weight = data.value_ml_milk;   unitStr = "ml_m"
        case 6: weight = data.value_fl_oz;     unitStr = "fl_oz"   // iOS FlOzWater=6 (Android=7)
        case 7: weight = data.value_fl_oz_milk; unitStr = "fl_oz_m" // iOS FlOzMilk=7 (Android=6)
        default: weight = data.value_g;        unitStr = "g"
        }
        
        // Handle negative weight (tare)
        if data.isNegative {
            weight = -abs(weight)
        }
        
        let eventData: [String: Any] = [
            "weight": weight,
            "unit": unitStr,
            "isStabilized": data.isStabilized,
            "hasBodyComposition": false
        ]
        
        // CRITICAL FIX: Send as "weightData" (NOT "kitchenScaleData").
        // The Flutter layer (fitdays_service.dart _handleEvent) only handles "weightData".
        // Android also sends kitchen scale readings as "weightData" — we must match.
        sendEvent("weightData", data: eventData)
    }
    
    @objc func onReceiveKitchenScaleHistoryData(_ device: ICDevice!, datas: NSArray) {
        sendEvent("kitchenScaleHistory", data: ["count": (datas as? [Any])?.count ?? 0])
    }
    
    @objc func onReceiveKitchenScaleUnitChanged(_ device: ICDevice!, unit: ICKitchenScaleUnit) {
        sendEvent("kitchenScaleUnitChanged", data: [
            "deviceId": device.macAddr ?? "",
            "unit": Int(unit.rawValue)
        ])
    }
    
    @objc func onReceiveKitchenScaleCommonFoods(_ device: ICDevice!, foods: NSArray) {
        sendEvent("kitchenScaleFoods", data: ["count": (foods as? [Any])?.count ?? 0])
    }
    
    @objc func onReceiveCoordData(_ device: ICDevice!, data: ICCoordData!) {
        sendEvent("coordData", data: [:])
    }
    
    @objc func onReceiveRulerData(_ device: ICDevice!, data: ICRulerData!) {
        sendEvent("rulerData", data: [:])
    }
    
    @objc func onReceiveRulerHistoryData(_ device: ICDevice!, data: ICRulerData!) {
        sendEvent("rulerHistoryData", data: [:])
    }
    
    @objc func onReceiveWeightCenterData(_ device: ICDevice!, data: ICWeightCenterData!) {
        sendEvent("weightCenterData", data: [:])
    }
    
    @objc func onReceiveWeightUnitChanged(_ device: ICDevice!, unit: ICWeightUnit) {
        sendEvent("weightUnitChanged", data: ["unit": Int(unit.rawValue)])
    }
    
    @objc func onReceiveRulerUnitChanged(_ device: ICDevice!, unit: ICRulerUnit) {
        sendEvent("rulerUnitChanged", data: ["unit": Int(unit.rawValue)])
    }
    
    @objc func onReceiveRulerMeasureModeChanged(_ device: ICDevice!, mode: ICRulerMeasureMode) {
        sendEvent("rulerMeasureModeChanged", data: ["mode": Int(mode.rawValue)])
    }
    
    @objc func onReceiveElectrodeData(_ device: ICDevice!, data: ICElectrodeData!) {
        sendEvent("electrodeData", data: [:])
    }
    
    @objc func onReceiveMeasureStepData(_ device: ICDevice!, step: ICMeasureStep, data: NSObject!) {
        // Forward depending on data type
        if let kitchen = data as? ICKitchenScaleData {
            onReceiveKitchenScaleData(device, data: kitchen)
        } else if let weight = data as? ICWeightData {
            onReceiveWeightData(device, data: weight)
        } else {
            sendEvent("measureStep", data: ["step": Int(step.rawValue)])
        }
    }
    
    @objc func onReceiveWeightHistoryData(_ device: ICDevice!, data: ICWeightHistoryData!) {
        sendEvent("weightHistory", data: [:])
    }
    
    @objc func onReceiveSkipData(_ device: ICDevice!, data: ICSkipData!) {
        sendEvent("skipData", data: [:])
    }
    
    @objc func onReceiveHistorySkipData(_ device: ICDevice!, data: ICSkipData!) {
        sendEvent("skipHistory", data: [:])
    }
    
    @objc func onReceiveBattery(_ device: ICDevice!, battery: Int, ext: NSObject!) {
        sendEvent("batteryLevel", data: [
            "macAddress": device.macAddr ?? "",
            "battery": battery
        ])
    }
    
    @objc func onReceiveUpgradePercent(_ device: ICDevice!, status: ICUpgradeStatus, percent: Int) {
        sendEvent("upgradePercent", data: [
            "status": Int(status.rawValue),
            "percent": percent
        ])
    }
    
    @objc func onReceiveDeviceInfo(_ device: ICDevice!, deviceInfo: ICDeviceInfo!) {
        sendEvent("deviceInfo", data: ["macAddress": device.macAddr ?? ""])
    }
    
    @objc func onReceiveConfigWifiResult(_ device: ICDevice!, type: ICConfigWifiResultType, obj: NSObject!) {
        sendEvent("configWifiResult", data: [:])
    }
    
    // MARK: - Helper
    
    private func sendEvent(_ type: String, data: [String: Any]?) {
        guard let sink = eventSink else { return }
        let event: [String: Any] = [
            "type": type,
            "data": data ?? [:]
        ]
        DispatchQueue.main.async {
            sink(event)
        }
    }
}

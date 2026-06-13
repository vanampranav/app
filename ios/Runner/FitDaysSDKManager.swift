import Flutter
import UIKit

#if !targetEnvironment(simulator)

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

        let userInfo = ICUserInfo()
        userInfo.age = UInt(age)
        userInfo.height = UInt(height)

        if sex.lowercased() == "female" {
            userInfo.sex = ICSexType(rawValue: 2)!
        } else {
            userInfo.sex = ICSexType(rawValue: 1)!
        }
        userInfo.peopleType = ICPeopleType(rawValue: 0)

        ICDeviceManager.shared().update(userInfo)

        if isSdkInitialized {
            return
        }

        ICDeviceManager.shared().delegate = self
        ICDeviceManager.shared().initMgr()
    }

    func getSDKVersion() -> String {
        return ICDeviceManager.version() ?? "Unknown"
    }

    // MARK: - Permissions

    func checkBluetoothPermissions() -> Bool {
        if #available(iOS 13.1, *) {
            let auth = CBCentralManager.authorization
            return auth == .allowedAlways || auth == .restricted
        }
        return true
    }

    // MARK: - Scanning

    func startScan() {
        if !isSdkInitialized {
            sendEvent("error", data: ["message": "SDK not initialized. Please wait or try again.", "code": "SDK_NOT_INIT"])
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
        ICDeviceManager.shared().add(device) { [weak self] (dev, code) in
            if code.rawValue == 0 {
                self?.connectedDevice = dev
                self?.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "connected"])
            } else {
                self?.sendEvent("error", data: ["message": "Connection failed", "code": "CONNECTION_ERROR"])
            }
        }
    }

    func disconnectDevice(macAddress: String) {
        guard let device = connectedDevice, device.macAddr == macAddress else { return }
        ICDeviceManager.shared().remove(device) { [weak self] (dev, code) in
            self?.connectedDevice = nil
            self?.sendEvent("connectionStateChanged", data: ["macAddress": macAddress, "state": "disconnected"])
        }
    }

    // MARK: - Commands

    func sendTareCommand(completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else { completion(false); return }
        ICDeviceManager.shared().getSettingManager().deleteTareWeight(device) { (code) in
            completion(code.rawValue == 0)
        }
    }

    func sendUnitChangeCommand(unit: String, completion: @escaping (Bool) -> Void) {
        guard let device = connectedDevice else { completion(false); return }
        var sdkUnitRaw: UInt = 0
        switch unit {
        case "g":       sdkUnitRaw = 0
        case "ml":      sdkUnitRaw = 1
        case "lb":      sdkUnitRaw = 2
        case "oz":      sdkUnitRaw = 3
        case "mg":      sdkUnitRaw = 4
        case "ml_m":    sdkUnitRaw = 5
        case "fl_oz":   sdkUnitRaw = 6
        case "fl_oz_m": sdkUnitRaw = 7
        default:        sdkUnitRaw = 0
        }
        let sdkUnit = ICKitchenScaleUnit(rawValue: sdkUnitRaw) ?? ICKitchenScaleUnit(rawValue: 0)!
        ICDeviceManager.shared().getSettingManager().setKitchenScaleUnit(device, unit: sdkUnit) { (code) in
            completion(code.rawValue == 0)
        }
    }

    // MARK: - ICScanDeviceDelegate

    @objc func onScanResult(_ deviceInfo: ICScanDeviceInfo?) {
        guard let info = deviceInfo else { return }
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
        sendEvent("deviceFound", data: [
            "name": info.name ?? "Unknown",
            "macAddress": info.macAddr ?? "",
            "rssi": info.rssi,
            "type": typeString
        ])
    }

    // MARK: - ICDeviceManagerDelegate

    @objc func onInitFinish(_ bSuccess: Bool) {
        isSdkInitialized = bSuccess
        sendEvent("sdkInitialized", data: ["success": bSuccess])
    }

    @objc func onBleState(_ state: ICBleState) {
        sendEvent("bluetoothStateChanged", data: ["state": Int(state.rawValue)])
    }

    @objc func onDeviceConnectionChanged(_ device: ICDevice!, state: ICDeviceConnectState) {
        var status = "connecting"
        if state.rawValue == 1 {
            status = "disconnected"
            if connectedDevice?.macAddr == device.macAddr { connectedDevice = nil }
        } else if state.rawValue == 0 {
            status = "connected"
            connectedDevice = device
        }
        sendEvent("connectionStateChanged", data: ["macAddress": device.macAddr ?? "", "state": status])
    }

    @objc func onNodeConnectionChanged(_ device: ICDevice!, nodeId: Int, state: ICDeviceConnectState) {
        sendEvent("nodeConnectionChanged", data: ["macAddress": device.macAddr ?? "", "nodeId": nodeId, "state": Int(state.rawValue)])
    }

    @objc func onReceiveWeightData(_ device: ICDevice!, data: ICWeightData!) {
        guard let data = data else { return }
        var weightData: [String: Any] = ["weight": data.weight_kg, "unit": "kg", "isStabilized": data.isStabilized]
        if data.imp != 0 {
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
    }

    @objc func onReceiveKitchenScaleData(_ device: ICDevice!, data: ICKitchenScaleData!) {
        guard let data = data else { return }
        if device != nil { connectedDevice = device }
        var weight: Float = 0.0
        var unitStr = "g"
        let unitRaw = Int(data.unit.rawValue)
        switch unitRaw {
        case 0: weight = data.value_g;          unitStr = "g"
        case 1: weight = data.value_ml;         unitStr = "ml"
        case 2: weight = data.value_lb_oz;      unitStr = "lb"
        case 3: weight = data.value_oz;         unitStr = "oz"
        case 4: weight = Float(data.value_mg);  unitStr = "mg"
        case 5: weight = data.value_ml_milk;    unitStr = "ml_m"
        case 6: weight = data.value_fl_oz;      unitStr = "fl_oz"
        case 7: weight = data.value_fl_oz_milk; unitStr = "fl_oz_m"
        default: weight = data.value_g;         unitStr = "g"
        }
        if data.isNegative { weight = -abs(weight) }
        sendEvent("weightData", data: ["weight": weight, "unit": unitStr, "isStabilized": data.isStabilized, "hasBodyComposition": false])
    }

    @objc func onReceiveKitchenScaleHistoryData(_ device: ICDevice!, datas: NSArray) {
        sendEvent("kitchenScaleHistory", data: ["count": (datas as? [Any])?.count ?? 0])
    }

    @objc func onReceiveKitchenScaleUnitChanged(_ device: ICDevice!, unit: ICKitchenScaleUnit) {
        sendEvent("kitchenScaleUnitChanged", data: ["deviceId": device.macAddr ?? "", "unit": Int(unit.rawValue)])
    }

    @objc func onReceiveKitchenScaleCommonFoods(_ device: ICDevice!, foods: NSArray) {
        sendEvent("kitchenScaleFoods", data: ["count": (foods as? [Any])?.count ?? 0])
    }

    @objc func onReceiveCoordData(_ device: ICDevice!, data: ICCoordData!) { sendEvent("coordData", data: [:]) }
    @objc func onReceiveRulerData(_ device: ICDevice!, data: ICRulerData!) { sendEvent("rulerData", data: [:]) }
    @objc func onReceiveRulerHistoryData(_ device: ICDevice!, data: ICRulerData!) { sendEvent("rulerHistoryData", data: [:]) }
    @objc func onReceiveWeightCenterData(_ device: ICDevice!, data: ICWeightCenterData!) { sendEvent("weightCenterData", data: [:]) }
    @objc func onReceiveWeightUnitChanged(_ device: ICDevice!, unit: ICWeightUnit) { sendEvent("weightUnitChanged", data: ["unit": Int(unit.rawValue)]) }
    @objc func onReceiveRulerUnitChanged(_ device: ICDevice!, unit: ICRulerUnit) { sendEvent("rulerUnitChanged", data: ["unit": Int(unit.rawValue)]) }
    @objc func onReceiveRulerMeasureModeChanged(_ device: ICDevice!, mode: ICRulerMeasureMode) { sendEvent("rulerMeasureModeChanged", data: ["mode": Int(mode.rawValue)]) }
    @objc func onReceiveElectrodeData(_ device: ICDevice!, data: ICElectrodeData!) { sendEvent("electrodeData", data: [:]) }

    @objc func onReceiveMeasureStepData(_ device: ICDevice!, step: ICMeasureStep, data: NSObject!) {
        if let kitchen = data as? ICKitchenScaleData {
            onReceiveKitchenScaleData(device, data: kitchen)
        } else if let weight = data as? ICWeightData {
            onReceiveWeightData(device, data: weight)
        } else {
            sendEvent("measureStep", data: ["step": Int(step.rawValue)])
        }
    }

    @objc func onReceiveWeightHistoryData(_ device: ICDevice!, data: ICWeightHistoryData!) { sendEvent("weightHistory", data: [:]) }
    @objc func onReceiveSkipData(_ device: ICDevice!, data: ICSkipData!) { sendEvent("skipData", data: [:]) }
    @objc func onReceiveHistorySkipData(_ device: ICDevice!, data: ICSkipData!) { sendEvent("skipHistory", data: [:]) }

    @objc func onReceiveBattery(_ device: ICDevice!, battery: Int, ext: NSObject!) {
        sendEvent("batteryLevel", data: ["macAddress": device.macAddr ?? "", "battery": battery])
    }

    @objc func onReceiveUpgradePercent(_ device: ICDevice!, status: ICUpgradeStatus, percent: Int) {
        sendEvent("upgradePercent", data: ["status": Int(status.rawValue), "percent": percent])
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
        let event: [String: Any] = ["type": type, "data": data ?? [:]]
        DispatchQueue.main.async { sink(event) }
    }
}

#else

// Simulator stub — FitDays SDK has no simulator slices; Bluetooth is unavailable on simulator anyway.
class FitDaysSDKManager: NSObject {
    func setEventSink(_ sink: FlutterEventSink?) {}
    func initializeSDK(age: Int, height: Int, sex: String) {}
    func getSDKVersion() -> String { return "Simulator - N/A" }
    func checkBluetoothPermissions() -> Bool { return false }
    func startScan() {}
    func stopScan() {}
    func connectDevice(macAddress: String) {}
    func disconnectDevice(macAddress: String) {}
    func sendTareCommand(completion: @escaping (Bool) -> Void) { completion(false) }
    func sendUnitChangeCommand(unit: String, completion: @escaping (Bool) -> Void) { completion(false) }
}

#endif

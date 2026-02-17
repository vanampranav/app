import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
  
  private var sdkManager: FitDaysSDKManager?
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Initialize SDK Manager
    sdkManager = FitDaysSDKManager()
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(name: "com.theelefit.app/fitdays",
                                              binaryMessenger: controller.binaryMessenger)
    
    let eventChannel = FlutterEventChannel(name: "com.theelefit.app/fitdays_events",
                                            binaryMessenger: controller.binaryMessenger)
    eventChannel.setStreamHandler(self)
    
    methodChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      self.handleMethodCall(call, result: result)
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - FlutterStreamHandler
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    self.sdkManager?.setEventSink(events)
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    self.sdkManager?.setEventSink(nil)
    return nil
  }
  
  // MARK: - Method Handling
  
  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let manager = sdkManager else {
      result(FlutterError(code: "NO_MANAGER", message: "SDK Manager not initialized", details: nil))
      return
    }
    
    switch call.method {
    case "initializeSDK":
      if let args = call.arguments as? [String: Any],
         let age = args["age"] as? Int,
         let height = args["height"] as? Int,
         let sex = args["sex"] as? String {
        manager.initializeSDK(age: age, height: height, sex: sex)
        result(true)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
      }
      
    case "checkPermissions":
      result(manager.checkBluetoothPermissions())
      
    case "requestPermissions":
      // iOS requests permissions automatically on first use of CBCentralManager
      // We can trigger a check or init here
      _ = manager.checkBluetoothPermissions()
      result(true)
      
    case "startScan":
      manager.startScan()
      result(nil)
      
    case "stopScan":
      manager.stopScan()
      result(nil)
      
    case "connectDevice":
      if let args = call.arguments as? [String: Any],
         let mac = args["macAddress"] as? String {
        manager.connectDevice(macAddress: mac)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing macAddress", details: nil))
      }
      
    case "disconnectDevice":
      if let args = call.arguments as? [String: Any],
         let mac = args["macAddress"] as? String {
        manager.disconnectDevice(macAddress: mac)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing macAddress", details: nil))
      }
      
    case "getSDKVersion":
      result(manager.getSDKVersion())
      
    case "sendTareCommand":
         manager.sendTareCommand { success in
             result(success)
         }
         
    case "sendUnitChangeCommand":
        if let args = call.arguments as? [String: Any],
           let unit = args["unit"] as? String {
            manager.sendUnitChangeCommand(unit: unit) { success in
                result(success)
            }
        } else {
             result(FlutterError(code: "INVALID_ARGS", message: "Missing unit", details: nil))
        }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

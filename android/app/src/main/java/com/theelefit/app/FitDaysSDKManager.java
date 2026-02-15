package com.theelefit.app;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.os.Build;

import androidx.core.app.ActivityCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import cn.icomon.icdevicemanager.ICDeviceManager;
import cn.icomon.icdevicemanager.ICDeviceManagerDelegate;
import cn.icomon.icdevicemanager.callback.ICScanDeviceDelegate;
import cn.icomon.icdevicemanager.model.data.*;
import cn.icomon.icdevicemanager.model.device.*;
import cn.icomon.icdevicemanager.ICDeviceManagerSettingManager;
import cn.icomon.icdevicemanager.model.other.ICConstant;
import cn.icomon.icdevicemanager.model.other.ICDeviceManagerConfig;

/**
 * Manager class for FitDays SDK operations
 * Handles SDK initialization, device scanning, connection, and data reception
 */
public class FitDaysSDKManager implements ICDeviceManagerDelegate, ICScanDeviceDelegate {
    
    private Context context;
    private FitDaysEventSink eventSink;
    private ICDevice connectedDevice;
    private ICUserInfo currentUserInfo;
    private boolean isScanning = false;
    private boolean isSdkInitialized = false;
    private Map<String, ICDevice> scannedDevices = new HashMap<>();  // Cache scanned devices
    
    public interface FitDaysEventSink {
        void sendEvent(Map<String, Object> event);
    }
    
    public FitDaysSDKManager(Context context) {
        this.context = context.getApplicationContext();
    }
    
    public void setEventSink(FitDaysEventSink eventSink) {
        this.eventSink = eventSink;
    }
    
    public void updateContext(Context context) {
        this.context = context;
    }
    
    // ========== SDK Initialization ==========
    
    public void initializeSDK(int age, int height, String sex) {
        android.util.Log.d("FitDaysSDK", "initializeSDK called with age: " + age + ", height: " + height + ", sex: " + sex);

        // Create user info for body composition calculations
        ICUserInfo userInfo = new ICUserInfo();
        userInfo.age = age;
        userInfo.height = height;
        // Set sex type
        if ("female".equalsIgnoreCase(sex)) {
            userInfo.sex = ICConstant.ICSexType.ICSexTypeFemal;
        } else {
            userInfo.sex = ICConstant.ICSexType.ICSexTypeMale;
        }
        userInfo.peopleType = ICConstant.ICPeopleType.ICPeopleTypeNormal;
        
        // Cache for re-sending upon connection
        this.currentUserInfo = userInfo;
        
        // Always update user info
        ICDeviceManager.shared().updateUserInfo(userInfo);
        android.util.Log.d("FitDaysSDK", "User info updated");

        if (isSdkInitialized) {
            android.util.Log.d("FitDaysSDK", "SDK already initialized, skipping initMgrWithConfig");
            return;
        }

        // Create SDK configuration
        ICDeviceManagerConfig config = new ICDeviceManagerConfig();
        config.context = context;
        
        // Set delegate
        ICDeviceManager.shared().setDelegate(this);
        
        // Initialize SDK
        ICDeviceManager.shared().initMgrWithConfig(config);
        
        android.util.Log.d("FitDaysSDK", "SDK initialization requested - waiting for onInitFinish callback");
    }
    
    public String getSDKVersion() {
        return ICDeviceManager.shared().version();
    }
    
    // ========== Permission Checking ==========
    
    public boolean checkBlePermissions() {
        // Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return ActivityCompat.checkSelfPermission(context, 
                    Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
                && ActivityCompat.checkSelfPermission(context, 
                    Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;
        }
        // Android 6-11 (API 23-30)
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return ActivityCompat.checkSelfPermission(context, 
                    Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                && ActivityCompat.checkSelfPermission(context, 
                    Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        }
        return true;
    }
    
    public String[] getRequiredPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return new String[]{
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            };
        } else {
            return new String[]{
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            };
        }
    }
    
    public boolean needsLocationEnabled() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q 
            && Build.VERSION.SDK_INT <= Build.VERSION_CODES.R;
    }
    
    public boolean isLocationEnabled() {
        LocationManager locationManager = 
            (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        return locationManager != null 
            && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
    }
    
    // ========== Device Scanning ==========
    
    public void startScan() {
        android.util.Log.d("FitDaysSDK", "startScan() called, isScanning=" + isScanning + ", isSdkInitialized=" + isSdkInitialized);
        
        if (!isSdkInitialized) {
            android.util.Log.w("FitDaysSDK", "Cannot start scan: SDK not initialized");
            Map<String, Object> data = new HashMap<>();
            data.put("message", "SDK not initialized. Please wait or try again.");
            data.put("code", "SDK_NOT_INIT");
            sendEvent("error", data);
            return;
        }

        if (!isScanning) {
            isScanning = true;
            android.util.Log.d("FitDaysSDK", "Calling ICDeviceManager.shared().scanDevice()");
            
            ICDeviceManager.shared().scanDevice(this);
            sendEvent("scanStarted", null);
            android.util.Log.d("FitDaysSDK", "Scan started event sent");
        }
    }
    
    public void stopScan() {
        if (isScanning) {
            ICDeviceManager.shared().stopScan();
            isScanning = false;
            sendEvent("scanStopped", null);
        }
    }
    
    // ========== Device Connection ==========
    

    
    public void disconnectDevice(String macAddress) {
        if (connectedDevice != null && connectedDevice.getMacAddr().equals(macAddress)) {
            ICDeviceManager.shared().removeDevice(connectedDevice, 
                (device, code) -> {
                    connectedDevice = null;
                    Map<String, Object> data = new HashMap<>();
                    data.put("macAddress", macAddress);
                    data.put("state", "disconnected");
                    sendEvent("connectionStateChanged", data);
                });
        }
    }
    
    // ========== Event Sending Helper ==========
    
    private void sendEvent(String type, Map<String, Object> data) {
        if (eventSink != null) {
            Map<String, Object> event = new HashMap<>();
            event.put("type", type);
            event.put("data", data);
            eventSink.sendEvent(event);
        }
    }
    
    // ========== ICScanDeviceDelegate Implementation ==========
    
    @Override
    public void onScanResult(ICScanDeviceInfo deviceInfo) {
        StringBuilder methodsLog = new StringBuilder();
        methodsLog.append("--- API Inspection (" + deviceInfo.getName() + ") ---\n");
        
        // Reflection Debugging
        try {
            for (java.lang.reflect.Method method : deviceInfo.getClass().getMethods()) {
                if (method.getName().startsWith("get") || method.getName().startsWith("is"))
                    methodsLog.append("Info Method: ").append(method.getName()).append("\n");
            }
            // Also inspect ICDevice to see how to properly configure it
            methodsLog.append("--- ICDevice Methods ---\n");
            for (java.lang.reflect.Method method : ICDevice.class.getMethods()) {
                 if (method.getName().startsWith("set"))
                    methodsLog.append("Device Set: ").append(method.getName()).append("\n");
            }
        } catch (Exception e) {
            methodsLog.append("Error inspecting: ").append(e.getMessage());
        }

        // Send detailed log to Flutter
        Map<String, Object> logData = new HashMap<>();
        logData.put("message", methodsLog.toString());
        sendEvent("log", logData);

        android.util.Log.d("FitDaysSDK", "onScanResult: " + deviceInfo.getName() + " (" + deviceInfo.getMacAddr() + ")");
        
        Map<String, Object> data = new HashMap<>();
        data.put("name", deviceInfo.getName() != null ? deviceInfo.getName() : "Unknown");
        data.put("macAddress", deviceInfo.getMacAddr());
        data.put("name", deviceInfo.getName());
        data.put("rssi", deviceInfo.getRssi());
        // User requested strict type checking
        if (deviceInfo.getType() != null) {
            data.put("type", deviceInfo.getType().toString());
        }
        
        
        sendEvent("deviceFound", data);
    }
    
    // ========== ICDeviceManagerDelegate Implementation ==========
    
    @Override
    public void onInitFinish(boolean success) {
        android.util.Log.d("FitDaysSDK", "onInitFinish called, success=" + success);
        isSdkInitialized = success;
        Map<String, Object> data = new HashMap<>();
        data.put("success", success);
        sendEvent("sdkInitialized", data);
    }
    
    @Override
    public void onBleState(ICConstant.ICBleState state) {
        Map<String, Object> data = new HashMap<>();
        data.put("state", state.toString());
        sendEvent("bluetoothStateChanged", data);
    }
    
    @Override
    public void onDeviceConnectionChanged(ICDevice device, 
                                         ICConstant.ICDeviceConnectState state) {
        android.util.Log.d("FitDaysSDK", "========== onDeviceConnectionChanged ==========");
        android.util.Log.d("FitDaysSDK", "Device: " + device.getMacAddr());
        android.util.Log.d("FitDaysSDK", "State: " + state.toString());
        
        Map<String, Object> data = new HashMap<>();
        data.put("macAddress", device.getMacAddr());
        
        if (state == ICConstant.ICDeviceConnectState.ICDeviceConnectStateDisconnected) {
            android.util.Log.d("FitDaysSDK", "Device DISCONNECTED - sending event");
            data.put("state", "disconnected");
            if (connectedDevice != null && 
                connectedDevice.getMacAddr().equals(device.getMacAddr())) {
                connectedDevice = null;
            }
        } else if (state == ICConstant.ICDeviceConnectState.ICDeviceConnectStateConnected) {
            android.util.Log.d("FitDaysSDK", "Device CONNECTED - sending event");
            connectedDevice = device; // CRITICAL FIX: Ensure reference is kept
            data.put("state", "connected");
        } else {
            android.util.Log.d("FitDaysSDK", "Device CONNECTING - sending event");
            // Other states (connecting, etc.)
            data.put("state", "connecting");
        }
        
        sendEvent("connectionStateChanged", data);
        android.util.Log.d("FitDaysSDK", "========== Event sent ==========");
    }
    
    @Override
    public void onReceiveWeightData(ICDevice device, ICWeightData data) {
        android.util.Log.d("FitDaysSDK", "========== onReceiveWeightData ==========");
        android.util.Log.d("FitDaysSDK", "Weight: " + data.weight_kg + " kg");
        android.util.Log.d("FitDaysSDK", "Stabilized: " + data.isStabilized);
        android.util.Log.d("FitDaysSDK", "Impedance: " + data.imp);
        
        Map<String, Object> weightData = new HashMap<>();
        weightData.put("weight", data.weight_kg);
        weightData.put("unit", "kg");
        weightData.put("isStabilized", data.isStabilized);
        
        // Send ALL weight data, not just stabilized
        // Body composition only available when stabilized AND impedance measured
        if (data.imp != 0) {
            android.util.Log.d("FitDaysSDK", "Body composition data available");
            weightData.put("bmi", data.bmi);
            weightData.put("bodyFat", data.bodyFatPercent);
            weightData.put("muscle", data.musclePercent);
            weightData.put("water", data.moisturePercent);
            weightData.put("boneMass", data.boneMass);
            weightData.put("protein", data.proteinPercent);
            weightData.put("bmr", data.bmr);
            weightData.put("visceralFat", data.visceralFat);
            weightData.put("skeletalMuscle", data.smPercent);
            weightData.put("physicalAge", (int)data.physicalAge);
        }
        
        sendEvent("weightData", weightData);
        android.util.Log.d("FitDaysSDK", "Weight data event sent");
    }
    
    @Override
    public void onReceiveBattery(ICDevice device, int battery, Object ext) {
        Map<String, Object> data = new HashMap<>();
        data.put("macAddress", device.getMacAddr());
        data.put("battery", battery);
        sendEvent("batteryLevel", data);
    }
    
    @Override
    public void onReceiveDeviceInfo(ICDevice device, ICDeviceInfo info) {
        // Device info received
    }
    
    // ========== Other Required Delegate Methods (Empty Implementations) ==========
    
    @Override
    public void onNodeConnectionChanged(ICDevice device, int nodeId, 
                                       ICConstant.ICDeviceConnectState state) {}
    
    
    @Override
    public void onReceiveKitchenScaleData(ICDevice device, ICKitchenScaleData data) {
        // CRITICAL FIX: Refresh connectedDevice to ensure we have the active instance for Commands
        // The SDK might require the exact instance currently streaming data
        if (device != null) {
            connectedDevice = device;
        }

        android.util.Log.d("FitDaysSDK", "onReceiveKitchenScaleData raw: " + data.toString());
        
        Map<String, Object> weightData = new HashMap<>();
        double weight = 0.0;
        String unit = "g";
        ICConstant.ICKitchenScaleUnit scaleUnit = data.getUnit();
        
        // Default to G if null
        if (scaleUnit == null) {
            scaleUnit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG;
        }

        // Map Unit and Value
        // based on available fields in ICKitchenScaleData
        if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG) {
            weight = data.value_g;
            unit = "g";
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMl) {
            weight = data.value_ml;
            unit = "ml";
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitOz) {
            weight = data.value_oz;
            unit = "oz";
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitLb) {
            // Usually LB:OZ, but if forced to LB
            // data.value_lb is int. data.value_lb_oz is double
            // Let's use lb:oz decimal representation if possible or just lb
            // But value_lb is int?
            // If scale is in LB:OZ mode
             // Check if value_lb_oz is populated
             weight = data.value_lb_oz; 
             unit = "lb"; // Matches UI value 'lb' which displays as lb:oz
             // Or construct "1 lb 5 oz" string? 
             // But weight must be double in our model.
             // We'll send value_lb_oz (which likely includes fraction) 
             // Or we send grams and let flutter convert? 
             // IF value_g is populated, ALWAYS send grams?
             // User reported 0.0g, implying value_g might NOT be populated when in other units.
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMg) {
            weight = data.value_mg;
            unit = "mg";
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMlMilk) {
            weight = data.value_ml_milk;
            unit = "ml_m"; // Matches UI value
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitFlOzWater) {
             weight = data.value_fl_oz;
             unit = "fl_oz";
        } else if (scaleUnit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitFlOzMilk) {
             weight = data.value_fl_oz_milk;
             unit = "fl_oz_m"; // Matches UI value
        } else {
            // Fallback
             weight = data.value_g;
             unit = "g";
        }

        // Safety check if specific value is 0 but grams is not
        if (weight == 0 && data.value_g > 0 && !"g".equals(unit)) {
             android.util.Log.w("FitDaysSDK", "Specific unit value is 0, falling back to grams");
             weight = data.value_g;
             unit = "g";
        }
        
        /* 
        // --- DEBUGGING REMOVED FOR PERFORMANCE ---
        // Verify via logs only if absolutely necessary
        */

        // Handle negative weights
        // SDK Documentation: https://sdk.fitdays.cn/Android/english/api.html#ickitchenscaledatakitchen-scale-data-class
        // value_g (and other value fields) always return positive numbers
        // isNegative indicates whether the value should be treated as negative
        // Example: value_g = 100, isNegative = true → actual value is -100
        boolean isNegative = data.isNegative;
        
        if (isNegative) {
            weight = -Math.abs(weight);
            android.util.Log.d("FitDaysSDK", "Negative weight detected: " + weight + " " + unit);
        }

        weightData.put("weight", weight);
        weightData.put("unit", unit);
        weightData.put("isStabilized", true); 
        weightData.put("hasBodyComposition", false);
        
        android.util.Log.d("FitDaysSDK", "Emitting weight (Kitchen): " + weight + " " + unit + (isNegative ? " (Negative)" : ""));
        sendEvent("weightData", weightData);
    }

    @Override
    public void onReceiveWeightCenterData(ICDevice device, ICWeightCenterData data) {
        android.util.Log.d("FitDaysSDK", "onReceiveWeightCenterData called");
        
        // This callback is usually for body balance scales, but checking just in case
        // ICWeightCenterData has left_weight_g, right_weight_g, etc.
        // We'll inspect it via reflection for safety as we did above, or just read known fields.
        // Documentation says it has value_g-like fields? No, it has left_weight_g/right_weight_g.
        
        double totalWeight = 0.0;
        try {
            // Try to sum left and right if available, or find a total weight field
            // Note: Documentation says ICWeightCenterData has precision_kg, kg_scale_division, left_weight_g, right_weight_g
            // It commonly does NOT have a simple "weight" field, it's for balance.
            
            // However, we can verify if it has any data relevant to us
            // Let's log all fields to be sure
            for (java.lang.reflect.Field field : data.getClass().getDeclaredFields()) {
                field.setAccessible(true);
                Object val = field.get(data);
                android.util.Log.d("FitDaysSDK", "WeightCenterData Field: " + field.getName() + " = " + val);
            }
            
            // If we find a "weight_kg" or similar, we use it.
            // Check for weight_kg
            try {
                java.lang.reflect.Field wField = data.getClass().getDeclaredField("weight_kg");
                wField.setAccessible(true);
                Object wVal = wField.get(data);
                if (wVal instanceof Number) {
                    totalWeight = ((Number) wVal).doubleValue();
                }
            } catch (Exception e) {}

        } catch (Exception e) {
            android.util.Log.e("FitDaysSDK", "Error parsing WeightCenterData", e);
        }
        
        // If we found a valid weight, send it
        if (totalWeight > 0) {
             Map<String, Object> weightData = new HashMap<>();
             weightData.put("weight", totalWeight);
             weightData.put("unit", "kg"); // Assuming kg for Center Data usually
             weightData.put("isStabilized", true);
             weightData.put("hasBodyComposition", false);
             
             android.util.Log.d("FitDaysSDK", "Emitting weight (CenterData): " + totalWeight);
             sendEvent("weightData", weightData);
        }
    }
    
    @Override
    public void onReceiveKitchenScaleHistoryData(ICDevice device, 
                                                List<ICKitchenScaleData> list) {}
    
    @Override
    public void onReceiveKitchenScaleUnitChanged(ICDevice device, 
                                                ICConstant.ICKitchenScaleUnit unit) {
        android.util.Log.d("FitDaysSDK", "Kitchen Scale Unit Changed: " + unit);
        String unitStr = "g";
        
        if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG) unitStr = "g";
        // SDK doesn't apparently support Kg for kitchen scales, but if it did it would be mapped here.
        // else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitKg) unitStr = "kg"; 
        else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitOz) unitStr = "oz";
        else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitLb) unitStr = "lb";
        else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMl) unitStr = "ml";
        else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMlMilk) unitStr = "ml_m";
        else if (unit == ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitFlOzMilk) unitStr = "fl_oz_m";
        
        Map<String, Object> data = new HashMap<>();
        data.put("deviceId", device.getMacAddr());
        data.put("unit", unitStr);
        sendEvent("kitchenScaleUnitChanged", data);
    }
    
    @Override
    public void onReceiveKitchenScaleCommonFoods(ICDevice device, 
                                                List<ICFoodInfo> list) {}
    
    @Override
    public void onReceiveCoordData(ICDevice device, ICCoordData data) {}
    
    @Override
    public void onReceiveRulerData(ICDevice device, ICRulerData data) {}
    
    @Override
    public void onReceiveRulerHistoryData(ICDevice device, ICRulerData data) {}
    

    
    @Override
    public void onReceiveWeightUnitChanged(ICDevice device, 
                                          ICConstant.ICWeightUnit unit) {}
    
    @Override
    public void onReceiveRulerUnitChanged(ICDevice device, 
                                         ICConstant.ICRulerUnit unit) {}
    
    @Override
    public void onReceiveRulerMeasureModeChanged(ICDevice device, 
                                                ICConstant.ICRulerMeasureMode mode) {}
    
    @Override
    public void onReceiveMeasureStepData(ICDevice device, ICConstant.ICMeasureStep step, Object data) {
         android.util.Log.d("FitDaysSDK", "========== onReceiveMeasureStepData ==========");
         android.util.Log.d("FitDaysSDK", "Step: " + step.toString());
         android.util.Log.d("FitDaysSDK", "Data type: " + (data != null ? data.getClass().getName() : "null"));
         
         Map<String, Object> eventData = new HashMap<>();
         eventData.put("step", step.toString());
         
         // Check if data is weight data regardless of step (Weighing or Over)
         if (data != null) {
             if (data instanceof ICWeightData) {
                 android.util.Log.d("FitDaysSDK", "Measure Step: " + step + " - Formatting Body Fat Data");
                 onReceiveWeightData(device, (ICWeightData) data);
             } else if (data instanceof ICKitchenScaleData) {
                 android.util.Log.d("FitDaysSDK", "Measure Step: " + step + " - Formatting Kitchen Scale Data");
                 onReceiveKitchenScaleData(device, (ICKitchenScaleData) data);
             } else {
                 android.util.Log.d("FitDaysSDK", "Data is NOT known type (ICWeightData/ICKitchenScaleData), skipping");
                 // Dump unknown data just in case
                 if (data != null) {
                    try {
                        for (java.lang.reflect.Field f : data.getClass().getDeclaredFields()) {
                            f.setAccessible(true);
                            android.util.Log.d("FitDaysSDK", "Unknown Data Field: " + f.getName() + " = " + f.get(data));
                        }
                    } catch (Exception e) {}
                 }
             }
         }
         // Forward specific steps if needed
         sendEvent("measureStep", eventData);
    }

    // ========== Device Connection ==========
    
    public void connectDevice(String macAddress) {
        if (!isSdkInitialized) {
            android.util.Log.e("FitDaysSDK", "Cannot connect to device: SDK not initialized");
            Map<String, Object> data = new HashMap<>();
            data.put("message", "SDK not ready yet. Please try again in a moment.");
            data.put("code", "SDK_NOT_INIT");
            sendEvent("error", data);
            return;
        }

        ICDevice device = new ICDevice();
        device.setMacAddr(macAddress);
        
        android.util.Log.d("FitDaysSDK", "Connecting to device: " + macAddress);
        
        ICDeviceManager.shared().addDevice(device, 
            (dev, code) -> {
                android.util.Log.d("FitDaysSDK", "addDevice callback - code: " + code + ", device: " + (dev != null ? dev.getMacAddr() : "null"));
                if (code == ICConstant.ICAddDeviceCallBackCode.ICAddDeviceCallBackCodeSuccess) {
                    // CRITICAL: Use the device object returned by the SDK callback
                    // This is the properly initialized device object with internal handles
                    connectedDevice = dev;
                    
                    // CRITICAL: Re-send user info upon connection for Body Fat calculation
                    // Retrieve cached values or use defaults if not set
                    // Ideally we should store the values passed in initializeSDK to reuse here
                    // specific to this user session.
                    // For now, using the last known good values or safe defaults
                    // Only re-sending if we have initialized sdk properly before
                    if (isSdkInitialized) {
                         // We need to get the user info we set during init. 
                         // Since we didn't store it in a field, we will create a temporary logic
                         // to use the values from shared preferences passed via MethodChannel if possible
                         // OR just assume the SDK held onto the last updateUserInfo. 
                         // BUT the demo explicitly calls updateUserInfo AGAIN here.
                         ICUserInfo userInfo = new ICUserInfo();
                         userInfo.age = 25; // TODO: Store these in fields during initializeSDK
                         userInfo.height = 170;
                         userInfo.sex = ICConstant.ICSexType.ICSexTypeMale;
                         userInfo.peopleType = ICConstant.ICPeopleType.ICPeopleTypeNormal;
                         
                         // We will rely on the fact that we stored these in initializeSDK
                         // Let's add fields to the class to store them
                         if (currentUserInfo != null) {
                             ICDeviceManager.shared().updateUserInfo(currentUserInfo);
                             android.util.Log.d("FitDaysSDK", "Re-sent UserInfo to connected device");
                         }
                    }

                    Map<String, Object> data = new HashMap<>();
                    data.put("macAddress", macAddress);
                    data.put("state", "connected");
                    sendEvent("connectionStateChanged", data);
                } else {
                    Map<String, Object> data = new HashMap<>();
                    data.put("message", "Connection failed: " + code);
                    data.put("code", "CONNECTION_ERROR");
                    sendEvent("error", data);
                }
            });
    }
    
    // ========== Kitchen Scale Controls ==========

    public void sendTareCommand(final FitDaysEventSink callbackSink) {
        /*
        if (connectedDevice == null) {
            Map<String, Object> data = new HashMap<>();
            data.put("success", false);
            data.put("error", "No device connected");
            if (callbackSink != null) callbackSink.sendEvent(data); // Using event sink for callback for now
            return;
        }

        ICDeviceManager.shared().deleteTareWeight(connectedDevice, new ICDeviceManagerSettingManager.ICSettingCallback() {
            @Override
            public void onCallback(int code) {
                android.util.Log.d("FitDaysSDK", "Tare command result: " + code);
                // For MethodChannel result, better to handle in FitDaysPlugin, but here we can log or emit event
            }
        });
        */
    }

    public void sendTareCommand(final ResultCallback callback) {
        android.util.Log.d("FitDaysSDK", "sendTareCommand called");
        if (connectedDevice == null) {
            android.util.Log.e("FitDaysSDK", "sendTareCommand: connectedDevice is NULL");
            callback.onResult(false, "No device connected");
            return;
        }
        android.util.Log.d("FitDaysSDK", "sendTareCommand: Sending to device " + connectedDevice.getMacAddr());

        ICDeviceManager.shared().getSettingManager().deleteTareWeight(connectedDevice, new ICDeviceManagerSettingManager.ICSettingCallback() {
            @Override
            public void onCallBack(ICConstant.ICSettingCallBackCode code) {
                android.util.Log.d("FitDaysSDK", "Tare command result: " + code);
                if (code == ICConstant.ICSettingCallBackCode.ICSettingCallBackCodeSuccess) {
                     callback.onResult(true, null);
                } else {
                     callback.onResult(false, "Tare failed with code: " + code);
                }
            }
        });
    }

    public void sendUnitChangeCommand(String unitStr, final ResultCallback callback) {
        android.util.Log.d("FitDaysSDK", "sendUnitChangeCommand called with unit: " + unitStr);
        if (connectedDevice == null) {
            android.util.Log.e("FitDaysSDK", "sendUnitChangeCommand: connectedDevice is NULL");
            callback.onResult(false, "No device connected");
            return;
        }
        android.util.Log.d("FitDaysSDK", "sendUnitChangeCommand: Sending to device " + connectedDevice.getMacAddr());

        ICConstant.ICKitchenScaleUnit unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG;
        
        switch (unitStr) {
            case "g":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG;
                break;
            case "kg":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitG; // Map kg to g as SDK lacks Kg enum for Kitchen Scale
                break;
            case "oz":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitOz;
                break;
            case "lb":
            case "lb:oz":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitLb; 
                break;
            case "ml":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMl;
                break;
            case "ml_m":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMlMilk;
                break;
            case "fl_oz_m":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitFlOzMilk;
                break;
            case "fl_oz":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitFlOzWater;
                break;
            case "mg":
                unit = ICConstant.ICKitchenScaleUnit.ICKitchenScaleUnitMg;
                break;
        }

        android.util.Log.d("FitDaysSDK", "Mapping unit string '" + unitStr + "' to Enum " + unit);

        ICDeviceManager.shared().getSettingManager().setKitchenScaleUnit(connectedDevice, unit, new ICDeviceManagerSettingManager.ICSettingCallback() {
            @Override
            public void onCallBack(ICConstant.ICSettingCallBackCode code) {
                android.util.Log.d("FitDaysSDK", "Unit change callback code: " + code);
                if (code == ICConstant.ICSettingCallBackCode.ICSettingCallBackCodeSuccess) {
                    callback.onResult(true, null);
                } else {
                    callback.onResult(false, "Unit change failed with code: " + code);
                }
            }
        });
    }

    public interface ResultCallback {
        void onResult(boolean success, String error);
    }
    
    @Override
    public void onReceiveWeightHistoryData(ICDevice device, 
                                          ICWeightHistoryData data) {}
    
    @Override
    public void onReceiveSkipData(ICDevice device, ICSkipData data) {}
    
    @Override
    public void onReceiveHistorySkipData(ICDevice device, ICSkipData data) {}
    
    @Override
    public void onReceiveUpgradePercent(ICDevice device, 
                                       ICConstant.ICUpgradeStatus status, 
                                       int percent) {}
    
    @Override
    public void onReceiveDebugData(ICDevice device, int type, Object data) {}
    
    @Override
    public void onReceiveConfigWifiResult(ICDevice device, 
                                         ICConstant.ICConfigWifiResultType type, 
                                         Object data) {}
    
    @Override
    public void onReceiveHR(ICDevice device, int hr) {
        Map<String, Object> hrData = new HashMap<>();
        hrData.put("macAddress", device.getMacAddr());
        hrData.put("heartRate", hr);
        sendEvent("heartRate", hrData);
    }
    
    @Override
    public void onReceiveUserInfo(ICDevice device, ICUserInfo userInfo) {}
    
    @Override
    public void onReceiveUserInfoList(ICDevice device, 
                                     List<ICUserInfo> list) {}
    
    @Override
    public void onReceiveRSSI(ICDevice device, int rssi) {}
    
    @Override
    public void onReceiveDeviceLightSetting(ICDevice device, Object data) {}
    
    @Override
    public void onReceiveScanWifiInfo_W(ICDevice device, String ssid, 
                                       Integer method, Integer rssi) {}
    
    @Override
    public void onReceiveCurrentWifiInfo_W(ICDevice device, Integer status, 
                                          String ip, String ssid, Integer rssi) {}
    
    @Override
    public void onReceiveBindState_W(ICDevice device, Integer status) {}
    
    @Override
    public void onReceiveCurrentPage(ICDevice device, Integer page) {}
}

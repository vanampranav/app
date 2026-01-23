package com.theelefit.app;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Flutter Platform Channel Plugin for FitDays SDK
 * Bridges Flutter (Dart) with native Android FitDays SDK
 */
public class FitDaysPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware,
        PluginRegistry.RequestPermissionsResultListener {
    
    private static final String METHOD_CHANNEL = "com.theelefit.app/fitdays";
    private static final String EVENT_CHANNEL = "com.theelefit.app/fitdays_events";
    private static final int PERMISSION_REQUEST_CODE = 1001;
    
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private Context context;
    private Activity activity;
    private FitDaysSDKManager sdkManager;
    private Result permissionResult;
    
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        
        // Initialize SDK Manager
        sdkManager = new FitDaysSDKManager(context);
        
        // Set up Method Channel
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        
        // Set up Event Channel
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
                sdkManager.setEventSink(event -> {
                    new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                        if (eventSink != null) {
                            eventSink.success(event);
                        }
                    });
                });
            }
            
            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
                sdkManager.setEventSink(null);
            }
        });
    }
    
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);
        methodChannel = null;
        eventChannel.setStreamHandler(null);
        eventChannel = null;
        context = null;
    }
    
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }
    
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }
    
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }
    
    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initializeSDK":
                handleInitializeSDK(call, result);
                break;
            case "startScan":
                handleStartScan(result);
                break;
            case "stopScan":
                handleStopScan(result);
                break;
            case "connectDevice":
                handleConnectDevice(call, result);
                break;
            case "disconnectDevice":
                handleDisconnectDevice(call, result);
                break;
            case "checkPermissions":
                handleCheckPermissions(result);
                break;
            case "requestPermissions":
                handleRequestPermissions(result);
                break;
            case "getSDKVersion":
                handleGetSDKVersion(result);
                break;
            case "sendTareCommand":
                handleSendTareCommand(call, result);
                break;
            case "sendUnitChangeCommand":
                handleSendUnitChangeCommand(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }
    
    private void handleInitializeSDK(MethodCall call, Result result) {
        try {
            int age = call.argument("age");
            int height = call.argument("height");
            String sex = call.argument("sex");
            
            // Use activity context if available, otherwise application context
            Context initContext = (activity != null) ? activity : context;
            
            // Update manager with best available context
            sdkManager.updateContext(initContext);
            
            sdkManager.initializeSDK(age, height, sex);
            result.success(true);
        } catch (Exception e) {
            result.error("INIT_ERROR", "Failed to initialize SDK: " + e.getMessage(), null);
        }
    }
    
    private void handleStartScan(Result result) {
        if (!sdkManager.checkBlePermissions()) {
            result.error("PERMISSION_ERROR", "Bluetooth permissions not granted", null);
            return;
        }
        
        if (sdkManager.needsLocationEnabled() && !sdkManager.isLocationEnabled()) {
            result.error("LOCATION_ERROR", "Location services must be enabled", null);
            return;
        }
        
        sdkManager.startScan();
        result.success(null);
    }
    
    private void handleStopScan(Result result) {
        sdkManager.stopScan();
        result.success(null);
    }
    
    private void handleConnectDevice(MethodCall call, Result result) {
        String macAddress = call.argument("macAddress");
        if (macAddress == null || macAddress.isEmpty()) {
            result.error("INVALID_ARGUMENT", "MAC address is required", null);
            return;
        }
        
        sdkManager.connectDevice(macAddress);
        result.success(null);
    }
    
    private void handleDisconnectDevice(MethodCall call, Result result) {
        String macAddress = call.argument("macAddress");
        if (macAddress == null || macAddress.isEmpty()) {
            result.error("INVALID_ARGUMENT", "MAC address is required", null);
            return;
        }
        
        sdkManager.disconnectDevice(macAddress);
        result.success(null);
    }
    
    private void handleCheckPermissions(Result result) {
        boolean hasPermissions = sdkManager.checkBlePermissions();
        result.success(hasPermissions);
    }
    
    private void handleRequestPermissions(Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null);
            return;
        }
        
        permissionResult = result;
        String[] permissions = sdkManager.getRequiredPermissions();
        ActivityCompat.requestPermissions(activity, permissions, PERMISSION_REQUEST_CODE);
    }
    
    private void handleGetSDKVersion(Result result) {
        String version = sdkManager.getSDKVersion();
        result.success(version);
    }
    
    private void handleSendTareCommand(MethodCall call, final Result result) {
        String deviceId = call.argument("deviceId"); // Not strictly needed as we use connectedDevice in manager, but good for validation
        if (deviceId == null) {
            result.error("INVALID_ARGUMENT", "Device ID is required", null);
            return;
        }

        sdkManager.sendTareCommand(new FitDaysSDKManager.ResultCallback() {
            @Override
            public void onResult(boolean success, String error) {
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    if (success) {
                        result.success(true);
                    } else {
                        // We still return true/false but could error if preferred
                        // result.error("CMD_FAILED", error, null);
                        // For this implementation, return false on failure as per Dart service
                        result.success(false);
                    }
                });
            }
        });
    }

    private void handleSendUnitChangeCommand(MethodCall call, final Result result) {
        String deviceId = call.argument("deviceId");
        String unit = call.argument("unit");
        
        if (deviceId == null || unit == null) {
            result.error("INVALID_ARGUMENT", "Device ID and unit are required", null);
            return;
        }

        sdkManager.sendUnitChangeCommand(unit, new FitDaysSDKManager.ResultCallback() {
            @Override
            public void onResult(boolean success, String error) {
                 new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    if (success) {
                        result.success(true);
                    } else {
                        result.success(false);
                    }
                 });
            }
        });
    }
    
    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == PERMISSION_REQUEST_CODE && permissionResult != null) {
            boolean allGranted = sdkManager.checkBlePermissions();
            permissionResult.success(allGranted);
            permissionResult = null;
            return true;
        }
        return false;
    }
}

# FitDays SDK ProGuard Rules
-keep class cn.icomon.icdevicemanager.ICDeviceManager { *; }
-keep class cn.icomon.icdevicemanager.ICBluetoothSystem { *; }
-keep public interface cn.icomon.icdevicemanager.ICBluetoothSystem$ICBluetoothDelegate { *; }
-keep public class cn.icomon.icdevicemanager.ICBluetoothSystem$ICOPBleCharacteristic { *; }
-keep public enum cn.icomon.icdevicemanager.ICBluetoothSystem$ICOPBleWriteDataType { *; }
-keep class cn.icomon.icdevicemanager.manager.setting.ICSettingManagerImpl { *; }
-keep class cn.icomon.icdevicemanager.manager.algorithms.ICBodyFatAlgorithmsImpl { *; }
-keep class cn.icomon.icdevicemanager.ICDeviceManagerDelegate { *; }
-keep class cn.icomon.icdevicemanager.model.** { *; }
-keep class cn.icomon.icdevicemanager.ICDeviceManagerSettingManager { *; }
-keep public interface cn.icomon.icdevicemanager.ICDeviceManagerSettingManager$ICSettingCallback { *; }
-keep class com.icomon.icbodyfatalgorithms.** { *; }
-keep class cn.icomon.icbleprotocol.** { *; }
-keep class cn.icomon.icdevicemanager.ICBodyFatAlgorithmsManager { *; }
-keep class cn.icomon.icdevicemanager.ICBluetoothSystem.** { *; }
-keep class cn.icomon.icdevicemanager.callback.** { *; }

# ── Health Connect / flutter `health` plugin ────────────────────────────────
# Without these, R8 strips the Health Connect client in release builds, so
# permissions/reads silently fail in the Play Store build but work in debug.
-keep class androidx.health.connect.client.** { *; }
-keep class androidx.health.platform.** { *; }
-keep interface androidx.health.connect.client.** { *; }
-keep class com.google.android.libraries.healthdata.** { *; }
-keep class cachet.plugins.health.** { *; }
-dontwarn androidx.health.**
-dontwarn com.google.android.libraries.healthdata.**

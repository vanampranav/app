#import "GeneratedPluginRegistrant.h"
// ...existing code...
#ifndef Runner_Bridging_Header_h
#define Runner_Bridging_Header_h

#import <Foundation/Foundation.h>

/* Core algorithm/constants (exposes enums like ICSexType, ICKitchenScaleUnit, etc.) */
#if __has_include(<ICDeviceManager/ICAlgDef.h>)
#import <ICDeviceManager/ICAlgDef.h>
#elif __has_include("ICAlgDef.h")
#import "ICAlgDef.h"
#endif

/* Primary umbrella */
#if __has_include(<ICDeviceManager/ICDeviceManager.h>)
#import <ICDeviceManager/ICDeviceManager.h>
#endif

/* Explicit headers (umbrella may omit some) */
#if __has_include(<ICDeviceManager/ICConstant.h>)
#import <ICDeviceManager/ICConstant.h>
#endif
#if __has_include(<ICDeviceManager/ICCallback_Inc.h>)
#import <ICDeviceManager/ICCallback_Inc.h>
#endif
#if __has_include(<ICDeviceManager/ICCrc.h>)
#import <ICDeviceManager/ICCrc.h>
#endif
#if __has_include(<ICDeviceManager/ICDeviceManagerDelegate.h>)
#import <ICDeviceManager/ICDeviceManagerDelegate.h>
#endif
#if __has_include(<ICDeviceManager/ICScanDeviceDelegate.h>)
#import <ICDeviceManager/ICScanDeviceDelegate.h>
#endif
#if __has_include(<ICDeviceManager/ICUserInfo.h>)
#import <ICDeviceManager/ICUserInfo.h>
#endif
#if __has_include(<ICDeviceManager/ICKitchenScaleData.h>)
#import <ICDeviceManager/ICKitchenScaleData.h>
#endif
#if __has_include(<ICDeviceManager/ICWeightData.h>)
#import <ICDeviceManager/ICWeightData.h>
#endif
#if __has_include(<ICDeviceManager/ICDevice.h>)
#import <ICDeviceManager/ICDevice.h>
#endif
#if __has_include(<ICDeviceManager/ICDeviceManagerSettingManager.h>)
#import <ICDeviceManager/ICDeviceManagerSettingManager.h>
#endif
#if __has_include(<ICDeviceManager/ICModels_Inc.h>)
#import <ICDeviceManager/ICModels_Inc.h>
#endif

/* Other related SDK frameworks */
#if __has_include(<ICBleProtocol/ICBleProtocol.h>)
#import <ICBleProtocol/ICBleProtocol.h>
#endif

#if __has_include(<ICBodyFatAlgorithms/ICBodyFatAlgorithms.h>)
#import <ICBodyFatAlgorithms/ICBodyFatAlgorithms.h>
#endif

#if __has_include(<ICLogger/ICLogger.h>)
#import <ICLogger/ICLogger.h>
#endif

#endif /* Runner_Bridging_Header_h */
// ...existing code...

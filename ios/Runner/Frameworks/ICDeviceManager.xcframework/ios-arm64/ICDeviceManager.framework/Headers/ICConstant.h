//
//  ICConstant.h
//  ICDeviceManager
//
//  Created by Symons on 2018/7/28.
//  Copyright © 2018年 Symons. All rights reserved.
//

#ifndef ICConstant_h
#define ICConstant_h

#import "ICAlgDef.h"

@class ICDevice;


/**
 设备类型
 **/
typedef NS_ENUM(NSUInteger, ICDeviceType)
{
    /**
     * 未知
     **/
    ICDeviceTypeUnKnown = 0,
    
    /**
     * 体重秤
     **/
    ICDeviceTypeWeightScale,
    
    /**
     * 脂肪秤
     **/
    ICDeviceTypeFatScale,

    /**
     * 脂肪秤(带温度显示)
     **/
    ICDeviceTypeFatScaleWithTemperature,
    
    /**
     * 厨房秤
     **/
    ICDeviceTypeKitchenScale,

    /**
     * 围尺
     **/
    ICDeviceTypeRuler,

    /**
     * 平衡秤
     **/
    ICDeviceTypeBalance,

    /**
     * 跳绳
     **/
    ICDeviceTypeSkip,

    /**
     * HR(心率带，支持心率等的设备)
     **/
    ICDeviceTypeHR,
    
    /**
     * Sphygmomanometer(血压计)
     **/
    ICDeviceTypeSphygmomanometer,
};

/**
 设备子类型
 **/
typedef NS_ENUM(NSUInteger, ICDeviceSubType)
{
    /**
     * 默认
     **/
    ICDeviceSubTypeDefault = 0,
    
    /**
     * 8电极设备
     **/
    ICDeviceSubTypeEightElectrode,
    
    /**
     * 身高设备
     **/
    ICDeviceSubTypeHeight,
    /**
     * 8电极设备2
     **/
    ICDeviceSubTypeEightElectrode2,
    /**
     * 双模设备
     **/
    ICDeviceSubTypeScaleDual,
    /**
     * 跳绳带灯效
     **/
    ICDeviceSubTypeLightEffect,
    /**
     * 彩屏秤
     **/
    ICDeviceSubTypeColor,
    /**
     * 跳绳带语音
     **/
    ICDeviceSubTypeSound,

    /**
     * 跳绳带灯效和语音
     **/
    ICDeviceSubTypeLightAndSound,
    
    /**
     * 基站
    */
    ICDeviceSubTypeBaseSt,
    
    /**
     * iComon S2
    */
    ICDeviceSubTypeRopeS2,
    
    /**
     * 走新的逻辑的秤
     */
    ICDeviceSubTypeNewScale,
    /**
     * W设备
     */
    ICDeviceSubTypeW
};

/**
 设备通讯方式
 
 */
typedef NS_ENUM(NSUInteger, ICDeviceCommunicationType) {
    /**
     未知
     */
    ICDeviceCommunicationTypeUnknown,
    
    /**
     连接式
     */
    ICDeviceCommunicationTypeConnect,
    
    /**
     广播式
     */
    ICDeviceCommunicationTypeBroadcast,
};

/**
 蓝牙状态
 */
typedef NS_ENUM(NSUInteger, ICBleState)
{
    /**
     * 未知状态
     **/
    ICBleStateUnknown = 0,
    
    /**
     * 手机不支持BLE
     **/
    ICBleStateUnsupported,
    
    /**
     * 应用未获取蓝牙授权
     **/
    ICBleStateUnauthorized,
    
    /**
     * 蓝牙关闭
     **/
    ICBleStatePoweredOff,
    
    /**
     * 蓝牙打开
     **/
    ICBleStatePoweredOn,
};


/**
 设备连接状态
 
 */
typedef NS_ENUM(NSUInteger, ICDeviceConnectState)
{
    /**
     * 已连接
     **/
    ICDeviceConnectStateConnected,
    
    /**
     * 已断开
     **/
    ICDeviceConnectStateDisconnected,
};



/**
 * 添加设备回调代码
 */
typedef NS_ENUM(NSUInteger, ICAddDeviceCallBackCode)
{
    /**
     * 添加成功
     */
    ICAddDeviceCallBackCodeSuccess,
    
    /**
     * 添加失败,SDK未初始化
     */
    ICAddDeviceCallBackCodeFailedAndSDKNotInit,
    
    /**
     * 添加失败，设备已存在
     */
    ICAddDeviceCallBackCodeFailedAndExist,
    
    /**
     * 添加失败，设备参数有错
     */
    ICAddDeviceCallBackCodeFailedAndDeviceParamError,
};

/**
 添加设备回调
 */
typedef void(^ICAddDeviceCallBack)(ICDevice *device, ICAddDeviceCallBackCode code);


/**
 * 删除设备回调代码
 */
typedef NS_ENUM(NSUInteger, ICRemoveDeviceCallBackCode)
{
    /**
     * 删除成功
     */
    ICRemoveDeviceCallBackCodeSuccess,
    
    /**
     * 删除失败,SDK未初始化
     */
    ICRemoveDeviceCallBackCodeFailedAndSDKNotInit,
    
    /**
     * 删除失败，设备不存在
     */
    ICRemoveDeviceCallBackCodeFailedAndNotExist,
    
    /**
     * 删除失败，设备参数有错
     */
    ICRemoveDeviceCallBackCodeFailedAndDeviceParamError,
};

/**
 删除设备回调
 */
typedef void(^ICRemoveDeviceCallBack)(ICDevice *device, ICRemoveDeviceCallBackCode code);



/**
 设置回调错误代码
 
 */
typedef NS_ENUM(NSUInteger, ICSettingCallBackCode)
{
    /**
     * 设置成功
     **/
    ICSettingCallBackCodeSuccess = 0,
    
    /**
     * 设置失败，SDK没有初始化
     **/
    ICSettingCallBackCodeSDKNotInit,
    
    /**
     * 设置失败，SDK没有启动
     **/
    ICSettingCallBackCodeSDKNotStart,
    
    /**
     * 设置失败，找不到设备或者设备未连接，请等待设备连接上后再设置
     **/
    ICSettingCallBackCodeDeviceNotFound,
    
    /**
     * 设置失败，设备不支持该功能
     **/
    ICSettingCallBackCodeFunctionIsNotSupport,
    
    /**
     * 设置失败，设备已断开
     **/
    ICSettingCallBackCodeDeviceDisConnected,
    
    /**
     * 设置失败，无效参数
     **/
    ICSettingCallBackCodeInvalidParameter,

    /**
     * 设置失败,请等待上一个任务结束
     **/
    ICSettingCallBackCodeWaitLastTaskOver,

    /**
     * 设置失败
     **/
    ICSettingCallBackCodeFailed,
};

/**
 体重秤单位
 */
typedef NS_ENUM(NSUInteger, ICWeightUnit)
{
    
    /**
     * 公斤
     */
    ICWeightUnitKg = 0,
    
    /**
     * 磅
     */
    ICWeightUnitLb,
    
    /**
     * 英石
     */
    ICWeightUnitSt,
    
    /**
     * 斤
     */
    ICWeightUnitJin
};


/**
 围尺单位
 */
typedef NS_ENUM(NSUInteger, ICRulerUnit)
{
    
    /**
     * 厘米cm
     */
    ICRulerUnitCM = 1,
    
    /**
     * 英寸inch
     */
    ICRulerUnitInch,
    /**
     * 英尺'英寸
     */
    ICRulerUnitFtInch,

};


/**
 围尺测量模式
 */
typedef NS_ENUM(NSUInteger, ICRulerMeasureMode)
{
    
    /**
     * 长度模式
     */
    ICRulerMeasureModeLength = 0,
    
    /**
     * 围度模式
     */
    ICRulerMeasureModeGirth,
    
};



/**
 厨房秤单位
 */
typedef NS_ENUM(NSUInteger, ICKitchenScaleUnit)
{
    
    /**
     * 克
     */
    ICKitchenScaleUnitG,

    /**
     * ml
     */
    ICKitchenScaleUnitMl,

    /**
     * 磅
     */
    ICKitchenScaleUnitLb,
    
    /**
     * 盎司
     */
    ICKitchenScaleUnitOz,
    /**
     * 毫克
     */
    ICKitchenScaleUnitMg,
    /**
     * ml(牛奶)
     */
    ICKitchenScaleUnitMlMilk,
    /**
     * 盎司(水)
     */
    ICKitchenScaleUnitFlOzWater,
    /**
     * 盎司(牛奶)
     */
    ICKitchenScaleUnitFlOzMilk
};


/**
 围尺设置的部位类型
 */
typedef NS_ENUM(NSUInteger, ICRulerBodyPartsType)
{
    /**
     * 肩膀
     */
    ICRulerPartsTypeShoulder = 1,
    
    /**
     * 手臂
     */
    ICRulerPartsTypeBicep,
    
    /**
     * 胸
     */
    ICRulerPartsTypeChest,

    /**
     * 腰
     */
    ICRulerPartsTypeWaist,
    
    /**
     * 臀
     */
    ICRulerPartsTypeHip,
    
    /**
     * 大腿
     */
    ICRulerPartsTypeThigh,
    
    /**
     * 小腿
     */
    ICRulerPartsTypeCalf,
    

};

/**
 性别
 */
typedef NS_ENUM(NSInteger,ICSexType)
{
    /**
     * 未知/保密
     */
    ICSexTypeUnknown = 0,

    /**
     * 男
     */
    ICSexTypeMale = 1,
    
    /**
     * 女
     */
    ICSexTypeFemal
};

/**
 厨房秤营养成分类型
 */
typedef NS_ENUM(NSUInteger, ICKitchenScaleNutritionFactType) {
    /*
     *  卡路里, 最大不超过4294967295
     */
    ICKitchenScaleNutritionFactTypeCalorie,
    
    /*
     *  总卡路里, 最大不超过4294967295
     */
    ICKitchenScaleNutritionFactTypeTotalCalorie,
    
    /*
     *  总脂肪
     */
    ICKitchenScaleNutritionFactTypeTotalFat,
    
    /*
     *  总蛋白质
     */
    ICKitchenScaleNutritionFactTypeTotalProtein,
    
    /*
     *  总碳水化合物
     */
    ICKitchenScaleNutritionFactTypeTotalCarbohydrates,
    
    /*
     *  总脂肪纤维
     */
    ICKitchenScaleNutritionFactTypeTotalFiber,
    
    /*
     *  总胆固醇
     */
    ICKitchenScaleNutritionFactTypeTotalCholesterd,
    
    /*
     *  总钠含量
     */
    ICKitchenScaleNutritionFactTypeTotalSodium,
    
    /*
     *  总糖含量
     */
    ICKitchenScaleNutritionFactTypeTotalSugar,
    
    /*
     * 脂肪
     */
    ICKitchenScaleNutritionFactTypeFat,
    
    /*
     * 蛋白质
     */
    ICKitchenScaleNutritionFactTypeProtein,
    
    /*
     * 碳水化合物
     */
    ICKitchenScaleNutritionFactTypeCarbohydrates,
    
    /*
     * 膳食纤维
     */
    ICKitchenScaleNutritionFactTypeFiber,
    
    /*
     * 胆固醇
     */
    ICKitchenScaleNutritionFactTypeCholesterd,
    
    /*
     * 钠含量
     */
    ICKitchenScaleNutritionFactTypeSodium,
    
    /*
     * 糖含量
     */
    ICKitchenScaleNutritionFactTypeSugar,
};

/**
 算法版本
 */
typedef enum : NSUInteger {
#if ENABLE_WLA01
    /*
     * 含水肌肉率
     */
    ICBFATypeWLA01 = 0,
#endif
#if ENABLE_WLA02
    /*
     * 不含水肌肉率
     */
    ICBFATypeWLA02 = 1,
#endif
#if ENABLE_WLA03
    /*
     * 新算法1
     */
    ICBFATypeWLA03 = 2,
#endif
#if ENABLE_WLA04
    /*
     * 新算法2
     */
    ICBFATypeWLA04 = 3,
#endif
#if ENABLE_WLA05
    /*
     * 新算法3
     */
    ICBFATypeWLA05 = 4,
#endif
#if ENABLE_WLA06
    /*
     * 新算法4
     */
    ICBFATypeWLA06 = 5,
#endif
#if ENABLE_WLA07
    /*
     * 新算法WLA07
     */
    ICBFATypeWLA07 = 6,
#endif
#if ENABLE_WLA08
    /*
     * 新算法WLA08
     */
    ICBFATypeWLA08 = 7,
#endif
#if ENABLE_WLA09
    /*
     * 新算法WLA09
     */
    ICBFATypeWLA09 = 8,
#endif
#if ENABLE_WLA10
    /*
     * 新算法WLA10
     */
    ICBFATypeWLA10 = 9,
#endif
#if ENABLE_WLA11
    /*
     * 新算法WLA11
     */
    ICBFATypeWLA11 = 10,
#endif
#if ENABLE_WLA12
    /*
     * 新算法WLA12
     */
    ICBFATypeWLA12 = 11,
#endif
#if ENABLE_WLA13
    /*
     * 新算法WLA13
     */
    ICBFATypeWLA13 = 12,
#endif
#if ENABLE_WLA14
    /*
     * 新算法WLA14
     */
    ICBFATypeWLA14 = 13,
#endif
#if ENABLE_WLA15
    /*
     * 新算法WLA15
     */
    ICBFATypeWLA15 = 14,
#endif
#if ENABLE_WLA16
    /*
     * 新算法WLA16
     */
    ICBFATypeWLA16 = 15,
#endif
#if ENABLE_WLA17
    /*
     * 新算法WLA17
     */
    ICBFATypeWLA17 = 16,
#endif
#if ENABLE_WLA18
    /*
     * 新算法WLA18
     */
    ICBFATypeWLA18 = 17,
#endif
#if ENABLE_WLA19
    /*
     * 新算法WLA19
     */
    ICBFATypeWLA19 = 18,
#endif
#if ENABLE_WLA20
    /*
     * 新算法WLA20
     */
    ICBFATypeWLA20 = 19,
#endif
#if ENABLE_WLA22
    /*
     * 新算法WLA22
     */
    ICBFATypeWLA22 = 21,
#endif
#if ENABLE_WLA23
    /*
     * 新算法WLA23
     */
    ICBFATypeWLA23 = 22,
#endif
#if ENABLE_WLA24
    /*
     * 新算法WLA24
     */
    ICBFATypeWLA24 = 23,
#endif
#if ENABLE_WLA25
    /*
     * 新算法WLA25
     */
    ICBFATypeWLA25 = 24,
#endif
#if ENABLE_WLA26
    /*
     * 新算法WLA26
     */
    ICBFATypeWLA26 = 25,
#endif
#if ENABLE_WLA27
    /*
     * 新算法WLA27
     */
    ICBFATypeWLA27 = 26,
#endif
#if ENABLE_WLA28
    /*
     * 新算法WLA28
     */
    ICBFATypeWLA28 = 27,
#endif
#if ENABLE_WLA29
    /*
     * 新算法WLA29
     */
    ICBFATypeWLA29 = 28,
#endif
#if ENABLE_WLA30
    /*
     * 新算法WLA30
     */
    ICBFATypeWLA30 = 29,
#endif
#if ENABLE_WLA31
    /*
     * 新算法WLA31
     */
    ICBFATypeWLA31 = 30,
#endif
#if ENABLE_WLA32
    /*
     * 新算法WLA32
     */
    ICBFATypeWLA32 = 31,
#endif
#if ENABLE_WLA33
    /*
     * 新算法WLA33
     */
    ICBFATypeWLA33 = 32,
#endif
#if ENABLE_WLA34
    /*
     * 新算法WLA34
     */
    ICBFATypeWLA34 = 33,
#endif
#if ENABLE_WLA35
    /*
     * 新算法WLA35
     */
    ICBFATypeWLA35 = 34,
#endif
#if ENABLE_WLA36
    /*
     * 新算法WLA36
     */
    ICBFATypeWLA36 = 35,
#endif

#if ENABLE_WLA37
    /*
     * 新算法WLA37
     */
    ICBFATypeWLA37 = 36,
#endif
    
#if ENABLE_WLA38
    /*
     * 新算法WLA38
     */
    ICBFATypeWLA38 = 37,
#endif
    
#if ENABLE_WLA39
    /*
     * 新算法WLA39
     */
    ICBFATypeWLA39 = 38,
#endif
    
#if ENABLE_WLA40
    /*
     * 新算法WLA40
     */
    ICBFATypeWLA40 = 39,
#endif
    
    
#if ENABLE_WLA1001
    /*
     * 新算法WLA1001
     */
    ICBFATypeWLA1001 = 1000,
#endif

    ICBFATypeUnknown = 100,
    ICBFATypeRev = 101

} ICBFAType;

/**
 用户类型
 */
typedef enum : NSUInteger {
    /*
     * 普通人
     */
    ICPeopleTypeNormal,

    /*
     * 运动员
     */
    ICPeopleTypeSportman,
} ICPeopleType;

/**
 数据类型
 */
typedef enum : NSUInteger {
    /*
     * 测量体重 (ICWeightData)
     */
    ICMeasureStepMeasureWeightData,
    
    /*
     * 测量平衡 (ICWeightCenterData)
     */
    ICMeasureStepMeasureCenterData,
    
    /*
     * 开始测量阻抗
     */
    ICMeasureStepAdcStart,

    /*
     * 测量阻抗结束 (ICWeightData)
     */
    ICMeasureStepAdcResult,
    
    /*
     * 开始测量心率
     */
    ICMeasureStepHrStart,
    
    /*
     * 测量心率结束 (ICWeightData)
     */
    ICMeasureStepHrResult,
    
    /*
     * 测量结束
     */
    ICMeasureStepMeasureOver,

} ICMeasureStep;



/**
 * 跳绳模式
 */
typedef enum : NSUInteger {
    /**
     * 自由跳
     */
    ICSkipModeFreedom = 0,
    
    /**
     * 计时跳
     */
    ICSkipModeTiming,
    
    /**
     * 计次跳
     */
    ICSkipModeCount,

    /**
     * 计时间歇跳
     */
    ICSkipModeInterruptTime,
    
    /**
     * 计次间歇跳
     */
    ICSkipModeInterruptCount,

} ICSkipMode;

/**
 * 升级状态
 */
typedef NS_ENUM(NSUInteger, ICUpgradeStatus) {
    /**
     * 升级成功
     */
    ICUpgradeStatusSuccess,
    /**
     * 升级中
     */
    ICUpgradeStatusUpgrading,
    /**
     * 升级失败
     */
    ICUpgradeStatusFail,
    /**
     * 升级失败，文件无效
     */
    ICUpgradeStatusFailFileInvalid,
    /**
     * 升级失败，设备不支持升级
     */
    ICUpgradeStatusFailNotSupport,
    /**
     * 文件下载中(WiFi升级下载文件)
     */
    ICUpgradeStatusFileDownloading,

};


/**
 * Wifi配网模式
 */
typedef NS_ENUM(NSUInteger, ICConfigWifiMode) {
    /*
     * 发送ssid和密码
     */
    ICConfigWifiModeDefault,
    /*
     * 告诉秤进入配网模式，延长亮屏时间
     */
    ICConfigWifiModeEnter,
    /*
     * 告诉秤app退出配网模式
     */
    ICConfigWifiModeExit,
    /*
     * 开始扫描Wifi
     */
    ICConfigWifiModeStartScan,
    /*
     * 停止扫描Wifi
     */
    ICConfigWifiModeStopScan,
};

/**
 * Wifi配网状态
 */
typedef NS_ENUM(NSUInteger, ICConfigWifiState) {
    ICConfigWifiStateSuccess,
    ICConfigWifiStateWifiConnecting,
    ICConfigWifiStateServerConnecting,
    ICConfigWifiStateWifiConnectFail,
    ICConfigWifiStateServerConnectFail,
    ICConfigWifiStatePasswordFail,
    ICConfigWifiStateFail,
};

/**
 * Wifi回调结果数据类型
 */
typedef NS_ENUM(NSUInteger,ICConfigWifiResultType){
    ICConfigWifiResultTypeState,
    ICConfigWifiResultTypeCurrentWifiInfo,
    ICConfigWifiResultTypeScanWifiInfo,
};

/*
 * 跳绳灯效模式
 */
typedef NS_ENUM(NSUInteger, ICSkipLightMode) {
    /*
     * 无
     */
    ICSkipLightModeNone,
    /*
     * 速度模式
     */
    ICSkipLightModeRPM,
    /*
     * 计时模式
     */
    ICSkipLightModeTimer,
    /*
     * 计次模式
     */
    ICSkipLightModeCount,
    /*
     * 百分比模式
     */
    ICSkipLightModePercent,
    /*
     * 绊绳次数模式
     */
    ICSkipLightModeTripRope,
    /*
     * 测量模式模式
     */
    ICSkipLightModeMeasuring,
};

/*
 * 语音类型
 */
typedef NS_ENUM(NSUInteger, ICSkipSoundType) {
    /*
     * 无
     */
    ICSkipSoundTypeNone,
    /*
     * 标准中文女声
     */
    ICSkipSoundTypeFemale,
    /*
     * 标准中文男声
     */
    ICSkipSoundTypeMale,
};

/*
 * 语音模式
 */
typedef NS_ENUM(NSUInteger, ICSkipSoundMode) {
    /*
     * 无
     */
    ICSkipSoundModeNone,
    /*
     * 按间隔时长
     */
    ICSkipSoundModeTime,
    /*
     * 按间隔个数
     */
    ICSkipSoundModeCount,
};

/*
 * 升级模式
 */
typedef NS_ENUM(NSUInteger, ICOTAMode) {
    /*
     * 自动模式
     */
    ICOTAModeAuto,
    /*
     * 模式1
     */
    ICOTAMode1,
    /*
     * 模式2
     */
    ICOTAMode2,
    /*
     * 模式3
     */
    ICOTAMode3,
    /*
     * 模式4，WiFi OTA。filePath设置为固件版本号
     */
    ICOTAMode4,
};

/*
 * 跳绳状态
 */

typedef NS_ENUM(NSUInteger, ICSkipStatus) {
    /*
     * 跳绳中
     */
    ICSkipStatusJumping,
    /*
     * 跳绳结束
     */
    ICSkipStatusJumpOver,
    /*
     * 跳绳休息中
     */
    ICSkipStatusRest,
};

/*
 * SDK模式
 */

typedef NS_ENUM(NSUInteger, ICSDKMode) {
    /*
     * 默认模式
     */
    ICSDKModeDefault,
    /*
     * 竞技模式
     */
    ICSDKModeCompetitive,
};



/*
 * bpm类型
 */

typedef NS_ENUM(NSUInteger, ICBPMType) {
    /*
     * default
     */
    ICBPMTypeDefault,

};



/*
 * bmi标准
 */

typedef NS_ENUM(NSUInteger, ICBMIStandard) {
    // WHO
    ICBMIStandard1,
    // Asia
    ICBMIStandard2,
    // Europe
    ICBMIStandard3,
    // ZH_CN
    ICBMIStandard4,
    // ZH_TW
    ICBMIStandard5,
};


typedef NS_ENUM(NSInteger , ICScaleUIItem) {
    /*
    * 体重
    */
    ICScaleUIItemWeight,
    /*
    * BMI
    */
    ICScaleUIItemBMI,
    /*
    * 体脂率
    */
    ICScaleUIItemBodyFatPercent,
    /*
    * 含水率
    */
    ICScaleUIItemMoisturePercent,
    /*
    * 肌肉率
    */
    ICScaleUIItemMusclePercent,
    /*
    * 骨量
    */
    ICScaleUIItemBoneMass,
    /*
    * 心率
    */
    ICScaleUIItemHR,
    /*
    * 骨骼肌率
    */
    ICScaleUIItemSmPercent,
    /*
    * 内脏脂肪
    */
    ICScaleUIItemVisceralFat,
    /*
    * 皮下脂肪率
    */
    ICScaleUIItemSubcutaneousFatPercent,
    /*
    * 蛋白率
    */
    ICScaleUIItemProteinPercent,
    /*
    * 体型
    */
    ICScaleUIItemBodyType,
    /*
    * 节段肌肉分析
    */
    ICScaleUIItemStageMuscle,
    /*
    * 节段脂肪分析
    */
    ICScaleUIItemStageFat,
    /*
    * 体重趋势
    */
    ICScaleUIItemWeightTrends,
    /*
    * bmi趋势
    */
    ICScaleUIItemBMITrends,
    /*
    * 体脂趋势
    */
    ICScaleUIItemBodyFatTrends,
    /*
    * 肌肉趋势
    */
    ICScaleUIItemMuscleTrends,
    /*
     * 抱婴界面
     */
    ICScaleUIItemBaby,
    /*
     * 孕妇界面
     */
    ICScaleUIItemPregnant,

    ICScaleUIItemRev = 32,
};

/*
 * 设备功能支持
 */

typedef NS_ENUM(NSUInteger, ICDeviceFunction) {
    /*
     * WIFI个能
     */
    ICDeviceFunctionWiFi,
    /*
     * 语音助手
     */
    ICDeviceFunctionVoiceAssistant,
    /*
     * 音效
     */
    ICDeviceFunctionSoundEffect,
    /*
     * 音量
     */
    ICDeviceFunctionVolume,
    /*
     * 语音语言
     */
    ICDeviceFunctionVoiceLanguage,
    /*
     * 设备上报体脂率(内部使用，外部不要使用)
     */
    ICDeviceFunctionSupportUploadBodyfat,
    /*
     * 天气
     */
    ICDeviceFunctionSupportWeather,
    /*
     * 重启
     */
    ICDeviceFunctionSupportRestart,
    /*
     * 恢复出厂设置
     */
    ICDeviceFunctionSupportFactory,

    /*
     * 配置服务器地址
     */
    ICDeviceFunctionSupportServerUrl,
    /*
     * 支持昵称
     */
    ICDeviceFunctionSupportNickName,
    /*
     * 支持昵称图片
     */
    ICDeviceFunctionSupportNickNameImg,
    /*
     * 支持设置秤的ui显示项
     */
    ICDeviceFunctionSupportSetUIItem,
    /*
     * 支持设置秤的灯光
     */
    ICDeviceFunctionSupportScaleLightSetting,
    /*
     * 支持婴儿模式
     */
    ICDeviceFunctionSupportBabyMode,
    /*
     * 支持身高单位下发
     */
    ICDeviceFunctionSupportHeightUnit,
    /*
     * 支持阻抗开关
     */
    ICDeviceFunctionSupportImpedance,
    /*
     * WIFI功能(是否支持扫描wifi)
     */
    ICDeviceFunctionSupportScanWiFi,
    /*
     * 支持小物模式
     */
    ICDeviceFunctionSupportSmartMode,
    /*
     * 支持电量
     */
    ICDeviceFunctionSupportBattery,

    /*
     * 是否支持新的用户管理，AC2C下，都是1
     */
    ICDeviceFunctionSupportNewUserManager,
    /*
     * 是否支持显示UserIndex
     */
    ICDeviceFunctionSupportShowUserIndex,
    /*
     * 是否支持下发Https证书
     */
    ICDeviceFunctionSupportHttpsCertificate,
    /*
     * 是否支持待机唤醒
     */
    ICDeviceFunctionSupportWakeUp,
    /*
     * 是否支持预设头像
     */
    ICDeviceFunctionSupportAvatar,
 
    /*
     * 八电极
     */
    ICDeviceFunctionEightElectrode = 32,
    /*
     * 预留
     */
    ICDeviceFunctionRev = 33,
};

/**
    发送的文件类型
 */
typedef NS_ENUM(NSUInteger, ICSendDataType) {
    /*
     * 头像，传入NSData
     */
    ICSendDataTypeHeadImg,
    /*
     * 头像，传入ICUserInfo
     */
    ICSendDataTypeNickName,
    /*
     * 开机动画，传入NSData
     */
    ICSendDataTypePowerOnImg,
    /*
     * 关机动画，传入NSData
     */
    ICSendDataTypePowerOffImg,
    /*
     * 食物图标，传入NSData
     */
    ICSendDataTypeFoodIcon,
};


/**
 * 均衡评估
 */
typedef NS_ENUM(NSUInteger, ICBodyBalanceEvaluation) {
    /*
     * 不支持
     */
    ICBodyBalanceEvaluationNotSuppport,
    /*
     * 均衡
     */
    ICBodyBalanceEvaluationBalanced,
    /*
     * 轻度失衡
     */
    ICBodyBalanceEvaluationSlightlyUnbalanced,
    /*
     * 不均衡
     */
    ICBodyBalanceEvaluationExtremelyUnbalanced,
};

/**
 * 体脂秤测量模式
 */
typedef NS_ENUM(NSUInteger, ICScaleMeasureMode) {
    /**
     * 普通模式
     */
    ICScaleMeasureModeNormal,

    /**
     * 孕妇模式
     */
    ICScaleMeasureModePregnant,

    /**
     * 抱婴模式
     */
    ICScaleMeasureModeBaby,
};


#endif /* ICConstant_h */

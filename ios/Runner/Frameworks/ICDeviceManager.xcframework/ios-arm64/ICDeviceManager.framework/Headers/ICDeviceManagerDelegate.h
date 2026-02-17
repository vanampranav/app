//
//  ICDeviceManagerDelegate.h
//  ICDeviceManager
//
//  Created by Symons on 2018/7/28.
//  Copyright © 2018年 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICModels_Inc.h"

@protocol ICDeviceManagerDelegate <NSObject>

@required
/**
 SDKc初始化完成回调
 
 @param bSuccess 初始化是否成功
 */
- (void)onInitFinish:(BOOL)bSuccess;

@optional

/**
 蓝牙改变状态回调
 
 @param state 蓝牙状态
 */
- (void)onBleState:(ICBleState)state;

/**
 设备连接状态回调
 
 @param device 设备
 @param state 连接状态
 */
- (void)onDeviceConnectionChanged:(ICDevice *)device state:(ICDeviceConnectState)state;

/**
 节点设备连接状态回调
 
 @param device 设备
 @param nodeId 设备
 @param state 连接状态
 */
- (void)onNodeConnectionChanged:(ICDevice *)device nodeId:(NSUInteger)nodeId state:(ICDeviceConnectState)state;


/**
 体重秤数据回调
 
 @param device 设备
 @param data 测量数据
 */
- (void)onReceiveWeightData:(ICDevice *)device data:(ICWeightData *)data;


/**
 厨房秤数据回调
 
 @param device 设备
 @param data 测量数据
 */
- (void)onReceiveKitchenScaleData:(ICDevice *)device data:(ICKitchenScaleData *)data;


/**
 厨房秤历史数据回调
 
 @param device 设备
 @param datas 历史数据列表
 */
- (void)onReceiveKitchenScaleHistoryData:(ICDevice *)device datas:(NSArray<ICKitchenScaleData *> *)datas;


/**
 厨房秤单位改变

 @param device 设备
 @param unit 改变后的单位
 */
- (void)onReceiveKitchenScaleUnitChanged:(ICDevice *)device unit:(ICKitchenScaleUnit)unit;

/**
 厨房秤食物列表

 @param device 设备
 @param foods 食物列表
 */
- (void)onReceiveKitchenScaleCommonFoods:(ICDevice *)device foods:(NSArray<ICFoodInfo *> *)foods;


/**
 平衡秤坐标数据回调
 
 @param device 设备
 @param data 测量坐标数据
 */
- (void)onReceiveCoordData:(ICDevice *)device data:(ICCoordData *)data;

/**
 围尺数据回调
 
 @param device 设备
 @param data 测量数据
 */
- (void)onReceiveRulerData:(ICDevice *)device data:(ICRulerData *)data;

/**
 围尺历史数据回调
 
 @param device 设备
 @param data 测量数据
 */
- (void)onReceiveRulerHistoryData:(ICDevice *)device data:(ICRulerData *)data;

/**
 平衡数据回调
 
 @param device 设备
 @param data 平衡数据
 */
- (void)onReceiveWeightCenterData:(ICDevice *)device data:(ICWeightCenterData *)data;

/**
 设备单位改变回调

 @param device  设备
 @param unit    设备当前单位
 */
- (void)onReceiveWeightUnitChanged:(ICDevice *)device unit:(ICWeightUnit)unit;


/**
 围尺单位改变回调
 
 @param device 设备
 @param unit 设备当前单位
 */
- (void)onReceiveRulerUnitChanged:(ICDevice *)device unit:(ICRulerUnit)unit;

/**
 围尺测量模式改变回调
 
 @param device 设备
 @param mode 设备当前测量模式
 */
- (void)onReceiveRulerMeasureModeChanged:(ICDevice *)device mode:(ICRulerMeasureMode)mode;


/**
 4个传感器数据回调
 
 @param device 设备
 @param data 传感器数据
 */
- (void)onReceiveElectrodeData:(ICDevice *)device data:(ICElectrodeData *)data;

/**
 分步骤体重、平衡、阻抗、心率数据回调
 
 @param device  设备
 @param step    当前处于的步骤
 @param data    数据
 */
- (void)onReceiveMeasureStepData:(ICDevice *)device step:(ICMeasureStep)step data:(NSObject *)data;

/**
 体重历史数据回调
 
 @param device 设备
 @param data 体重历史数据
 */
- (void)onReceiveWeightHistoryData:(ICDevice *)device data:(ICWeightHistoryData *)data;


/**
 跳绳实时数据回调
 
 @param device 设备
 @param data 体重历史数据
 */
- (void)onReceiveSkipData:(ICDevice *)device data:(ICSkipData *)data;


/**
 跳绳历史数据回调
 
 @param device 设备
 @param data 跳绳历史数据
 */
- (void)onReceiveHistorySkipData:(ICDevice *)device data:(ICSkipData *)data;

/**
 跳绳电量,后续使用onReceiveBattery
 
 @param device 设备
 @param battery 电量，范围:0~100
 */
//- (void)onReceiveSkipBattery:(ICDevice *)device battery:(NSUInteger)battery;

/**
 电量
 
 @param device 设备
 @param battery 电量，范围:0~100
 @param ext 扩展字段，如是基站跳绳，则该字段的值表示节点ID，类型：NSNumber
 */
- (void)onReceiveBattery:(ICDevice *)device battery:(NSUInteger)battery ext:(NSObject *)ext;

/**
 设备升级状态回调
 @param device 设备
 @param status 升级状态
 @param percent 升级进度,范围:0~100
 */
- (void)onReceiveUpgradePercent:(ICDevice *)device status:(ICUpgradeStatus)status percent:(NSUInteger)percent;

/**
 设备信息回调

 @param device 设备
 @param deviceInfo 设备信息
 */
- (void)onReceiveDeviceInfo:(ICDevice *)device deviceInfo:(ICDeviceInfo *)deviceInfo;

/**
 * 配网结果回调
 * @param device 设备
 * @param type 配网数据类型
 * @param obj 数据
 */
- (void)onReceiveConfigWifiResult:(ICDevice *)device type:(ICConfigWifiResultType)type obj:(NSObject *)obj;


/**
 心率

 @param device 设备
 @param hr 心率，范围:0~255
 */
- (void)onReceiveHR:(ICDevice *)device hr:(int)hr;


/**
 收到设备上报的用户信息，竞技款跳绳

 @param device 设备
 @param userInfo 用户信息
 */
- (void)onReceiveUserInfo:(ICDevice *)device userInfo:(ICUserInfo *)userInfo;

/**
 收到设备上报的用户信息列表，用户信息并不完整，只包含一部分

 @param device 设备
 @param userInfos 用户信息
 */
- (void)onReceiveUserInfoList:(ICDevice *)device userInfos:(NSArray<ICUserInfo *> *)userInfos;

/**
 设备信号强度回调

 @param device 设备
 @param rssi 信号强度
 */
- (void)onReceiveRSSI:(ICDevice *)device rssi:(int)rssi;


/**
   调试数据回调

   @param device 设备
   @param type 类型
   @param obj 数据
   */
- (void)onReceiveDebugData:(ICDevice *)device type:(int)type obj:(NSObject *)obj;

/**
   收到设备上报的设备灯光配置信息
 
   @param device 设备
   @param obj 灯光参数
 */
- (void)onReceiveDeviceLightSetting:(ICDevice *)device obj:(NSObject *)obj;


/**
 * 收到W扫描的WiFi列表
 * @param device 设备
 * @param ssid   WiFi SSID
 * @param method 加密方式
 * @param rssi   信号
 */
- (void)onReceiveScanWifiInfo_W:(ICDevice *)device ssid:(NSString *)ssid method:(NSInteger)method rssi:(NSUInteger)rssi;

/**
 * 收到W当前连接WiFi信息
 * @param device 设备
 * @param status 状态，0:未配网，1:未连接wifi，2:已连接wifi未连接服务器，3:已连接服务器,4:wifi模块未上电
 * @param ip     IP
 * @param ssid   SSID
 * @param rssi   信号
 */
- (void)onReceiveCurrentWifiInfo_W:(ICDevice *)device status:(NSUInteger)status ip:(NSString *)ip ssid:(NSString *)ssid  rssi:(NSInteger)rssi;
/**
 * 绑定状态
 * @param device 设备
 * @param status 绑定状态，1已绑定，0未绑定
 */
- (void)onReceiveBindState_W:(ICDevice *)device status:(NSUInteger)status;
/**
  * 当前界面ID切换
  * @param device 设备
  * @param pageId 界面ID
  */
- (void)onReceiveCurrentPage:(ICDevice *)device pageId:(NSUInteger)pageId;

@end

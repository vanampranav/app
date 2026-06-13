//
//  LSSettingManager.h
//  ICDeviceManager
//
//  Created by lifesense－mac on 17/3/20.
//  Copyright © 2017年 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICModels_Inc.h"

@class ICDevice;


/**
 设置回调

 @param code 设置回调代码
 */
typedef void(^ICSettingCallback)(ICSettingCallBackCode code);

/**
 设备设置
 */
@protocol ICDeviceManagerSettingManager <NSObject>

/**
 设置称单位
 
 @param device          设备
 @param unit            单位
 @param callback        回调
 */
- (void)setScaleUnit:(ICDevice *)device unit:(ICWeightUnit)unit callback:(ICSettingCallback)callback;

/**
 设置围尺单位
 
 @param device      设备
 @param unit        单位
 @param callback    回调
 */
- (void)setRulerUnit:(ICDevice *)device unit:(ICRulerUnit)unit callback:(ICSettingCallback)callback;

/**
 设置当前围尺身体部位
 
 @param device      设备
 @param type        身体部位
 @param callback    回调
 */
- (void)setRulerBodyPartsType:(ICDevice *)device type:(ICRulerBodyPartsType)type callback:(ICSettingCallback)callback;

/**
 设置重量到厨房秤，单位:毫克

 @param device 设备
 @param weight 重量，单位:毫克，最大不能超过65535毫克
 @param callback 回调
 */
- (void)setWeight:(ICDevice *)device weight:(NSInteger)weight callback:(ICSettingCallback)callback;

/**
 设置厨房秤去皮重量

 @param device 设备
 @param callback 回调
 */
- (void)deleteTareWeight:(ICDevice *)device callback:(ICSettingCallback)callback;
/**
设置厨房秤关机

@param device 设备
@param callback 回调
*/
- (void)powerOffKitchenScale:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 设置厨房秤计量单位

 @param device 设备
 @param unit 单位，注:如果秤不支持该单位，将不会生效
 @param callback 回调
 */
- (void)setKitchenScaleUnit:(ICDevice *)device unit:(ICKitchenScaleUnit)unit callback:(ICSettingCallback)callback;

/**
 设置营养成分值到厨房秤

 @param device 设备
 @param type 营养类型
 @param value 营养值
 @param callback 回调
 */
//- (void)setNutritionFacts:(ICDevice *)device type:(ICKitchenScaleNutritionFactType)type value:(NSInteger)value callback:(ICSettingCallback)callback;

/**
 设置围尺测量模式
 
 @param device      设备
 @param mode        测量模式
 @param callback    回调
 */
- (void)setRulerMeasureMode:(ICDevice *)device mode:(ICRulerMeasureMode)mode callback:(ICSettingCallback)callback;


/**
 * 开始跳绳
 * @param device 设备
 * @param mode   跳绳模式
 * @param param  模式参数
 * @param callback 回调
 */
- (void)startSkip:(ICDevice *)device mode:(ICSkipMode)mode param:(NSUInteger)param callback:(ICSettingCallback)callback;


/**
 * 开始跳绳
 * @param device 设备
 * @param param  模式参数
 * @param callback 回调
 */
- (void)startSkipExt:(ICDevice *)device param:(ICSkipParam *)param callback:(ICSettingCallback)callback;


/**
 * 暂停跳绳
 * @param device 设备
 * @param callback 回调
 */
//- (void)pauseSkip:(ICDevice *)device callback:(ICSettingCallback)callback;



/**
 * 恢复跳绳
 * @param device 设备
 * @param callback 回调
 */
//- (void)resumeSkip:(ICDevice *)device callback:(ICSettingCallback)callback;



/**
 * 停止跳绳
 * @param device 设备
 * @param callback 回调
 */
- (void)stopSkip:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 设置用户信息给设备
 注意:目前仅跳绳和部分秤设备支持

@param device       设备
@param userInfo  用户信息
@param callback  回调
*/
- (void)setUserInfo:(ICDevice *)device userInfo:(ICUserInfo *)userInfo callback:(ICSettingCallback)callback;


/**
 设置用户列表给设备
 注意:目前仅跳绳和部分秤设备支持

@param device       设备
@param userInfos  用户信息列表
@param callback  回调
*/
- (void)setUserList:(ICDevice *)device userInfos:(NSArray<ICUserInfo *> *)userInfos callback:(ICSettingCallback)callback;


/**
 设备配网

@param device        设备
@param mode             配置模式
@param ssid             WIFI SSID
@param password    WIFI Password
@param method        加密方式
*/
- (void)configWifi:(ICDevice *)device mode:(ICConfigWifiMode)mode ssid:(NSString *)ssid password:(NSString *)password method:(int)method callback:(ICSettingCallback)callback;

/**
 设置厂商特定参数

 @param device      设备
 @param type        根据客户意思不一样
 */
- (void)setOtherParams:(ICDevice *)device type:(NSUInteger)type param:(NSObject *)param callback:(ICSettingCallback)callback;


/**
 * 设置跳绳设备灯效
 * @param device 设备
 * @param param 参数
 * @param callback 回调
 */
- (void)setDeviceLightSetting:(ICDevice *)device param:(NSObject *)param callback:(ICSettingCallback)callback;


/**
 * 设置设备显示的项
 * @param device 设备
 * @param items UI项
 * @param callback 回调
 */
- (void)setScaleUIItems:(ICDevice *)device items:(NSArray<NSNumber *> *)items callback:(ICSettingCallback)callback;

/*
 * 下发准备
 * @param device    基站设备
 * @param callback  回调
 */
- (void)lockStSkip:(ICDevice *)device callback:(ICSettingCallback)callback;


/*
 * 下发准备(仅部分型号支持)
 * @param device    基站设备
 * @param param    指定参数锁定
 * @param callback  回调
 */
- (void)lockStSkipEx:(ICDevice *)device param:(ICSkipParam *)param callback:(ICSettingCallback)callback;

/*
 * 查询在线状态
 * @param device    基站设备
 * @param callback  回调
 */
- (void)queryStAllNode:(ICDevice *)device callback:(ICSettingCallback)callback;

/*
 * 改变广播名
 * @param device    基站设备
 * @param name      广播名
 * @param callback  回调
 */
- (void)changeStName:(ICDevice *)device name:(NSString *)name callback:(ICSettingCallback)callback;

/*
 * 改变节点ID
 * @param device    基站设备
 * @param dstId     节点设备更改后ID
 * @param callback  回调
 */
- (void)changeStNo:(ICDevice *)device dstId:(NSUInteger)dstId  st_no:(NSUInteger)st_no callback:(ICSettingCallback)callback;

/**
 * 设置跳绳设备音效
 * @param device 设备
 * @param config 音效设置
 * @param callback 回调
 */
- (void)setSkipSoundSetting:(ICDevice *)device config:(ICSkipSoundSettingData *)config callback:(ICSettingCallback)callback;


/**
* 设置跳绳心率上限
 * @param device 设备
 * @param hr 心率上限
 * @param callback 回调
 */
- (void)setHRMax:(ICDevice *)device hr:(int)hr callback:(ICSettingCallback)callback;


/**
 * 设置跳绳BPM
 * @param device 设备
 * @param type 节拍类型
 * @param bpm 节拍设置
 * @param callback 回调
 */
- (void)setBPM:(ICDevice *)device type:(ICBPMType)type bpm:(int)bpm callback:(ICSettingCallback)callback;


/**
 * 设置声音大小
 * @param device 设备
 * @param volume 声音大小: 0~100
 * @param callback 回调
 */
- (void)setVolume:(ICDevice *)device volume:(int)volume callback:(ICSettingCallback)callback;


/**
 * 设置跳绳播报频率
 * @param device 设备
 * @param freq  每跳多少个就播报一次，固定50、100、150、200
 * @param callback 回调
 */
- (void)setSkipPlayFreq:(ICDevice *)device freq:(int)freq callback:(ICSettingCallback)callback;



/**
 * 设置HR
 * @param device 设备
 * @param hr 当前心率
 * @param callback 回调
 */
- (void)setHR:(ICDevice *)device hr:(int)hr callback:(ICSettingCallback)callback;





/*
 * 改变指定节点的昵称
 * @param device    基站设备
 * @param nodeId     节点ID
 * @param nickName    昵称
 * @param headType     头像序号
 * @param callback  回调
 */
- (void)setNickNameInfo:(ICDevice *)device nodeId:(NSUInteger)nodeId nickName:(NSString *)nickName headType:(NSUInteger)headType  sclass:(NSUInteger)sclass grade:(NSUInteger)grade studentNo:(NSUInteger)studentNo callback:(ICSettingCallback)callback;


/*
 * 解散基站网络
 * @param device    基站设备
 * @param callback  回调
 */
- (void)exitNetwork:(ICDevice *)device callback:(ICSettingCallback)callback;


/*
 * 移除指定节点
 * @param device    基站设备
 * @param nodeIds     节点ID列表
 * @param callback  回调
 */
- (void)removeNodeIds:(ICDevice *)device nodeIds:(NSArray<NSNumber *> *)nodeIds callback:(ICSettingCallback)callback;



/*
 * 设置根节点
 * @param device    基站设备
 * @param matchMode 基站运行模式
 * @param callback  回调
 */
- (void)setRootNodeId:(ICDevice *)device matchMode:(NSUInteger)matchMode callback:(ICSettingCallback)callback;

/*
 * 设置从节点
 * @param device    基站设备
 * @param callback  回调
 */
- (void)setClientNodeId:(ICDevice *)device callback:(ICSettingCallback)callback;


/*
 * 读取昵称和头像
 * @param device    基站设备
 * @param callback  回调
 */
- (void)readUserInfo:(ICDevice *)device callback:(ICSettingCallback)callback;


/*
 * 绑定HR设备(仅基站跳绳，3合一固件)
 * @param device            基站设备
 * @param nodeId            需要绑定心率设备的节点ID
 * @param hrDeviceMac       心率设备
 * @param callback          回调
 */
- (void)bindHRDevice:(ICDevice *)device nodeId:(NSUInteger)nodeId hrDeviceMac:(NSString *)hrDeviceMac callback:(ICSettingCallback)callback;



/*
 * 设置秤的语音类型
 * @param device
 * @param config 音效设置参数
 * @param callback
 */
- (void)setScaleSoundSetting:(ICDevice *)device config:(ICScaleSoundSettingData *)config callback:(ICSettingCallback)callback;


/*
 * 设置秤的解密密钥
 * @param device
 * @param key 密钥
 * @param callback
 */
- (void)setDeviceKey:(ICDevice *)device key:(NSString *)key callback:(ICSettingCallback)callback;

/*
 * 发送数据到秤
 * @notice 注: 同一个设备，同一时间仅能调用一次，必须等上一个发送完成才能调用下一个
 * @param device
 * @param type 数据类型
 * @param userId 数据对应的用户ID，有些数据类型是不需要的，则填0就可以了
 * @param obj 数据，根据type来确定obj的类型，具体可以查看type的类型描述
 * @param callback
 */
- (void)sendData:(ICDevice *)device type:(ICSendDataType)type userId:(NSUInteger)userId obj:(NSObject *)obj  callback:(ICSettingCallback)callback;

/*
 * 发送数据到秤
 * @notice 注: 同一个设备，同一时间仅能调用一次，必须等上一个发送完成才能调用下一个
 * @param device
 * @param type 数据类型
 * @param userId 数据对应的用户ID，有些数据类型是不需要的，则填0就可以了
 * @param foodId 数据对应的食物ID
 * @param foodIndex 数据对应的食物序号
 * @param obj 数据，根据type来确定obj的类型，具体可以查看type的类型描述
 * @param callback
 */
- (void)sendKitchenScaleData:(ICDevice *)device type:(ICSendDataType)type userId:(NSUInteger)userId foodId:(NSUInteger)foodId foodIndex:(NSUInteger)foodIndex obj:(NSObject *)obj  callback:(ICSettingCallback)callback;

/*
 * 发送https证书
 * cerVersion 证书版本号
 * filePath 文件路径
 * @param callback
 */
- (void)sendHttpsCertificateData:(ICDevice *)device cerVersion:(NSUInteger)cerVersion filePath:(NSString *)filePath callback:(ICSettingCallback)callback;

/*
 * 取消发送数据
 * @param device
 * @param callback
 */
- (void)cancelSendData:(ICDevice *)device callback:(ICSettingCallback)callback;

/*
 * 下发工程设置指令
 * @param device
 * @param param 参数
 * @param callback
 */
- (void)setCommand:(ICDevice *)device cmd:(NSUInteger)cmd param:(NSObject *)param callback:(ICSettingCallback)callback;


/**
 * 更新或添加W用户信息
 * @param device 设备
 * @param userInfo 用户信息
 * @param callback 回调
 */
- (void)updateUserInfo_W:(ICDevice *)device userInfo:(ICUserInfo *)userInfo callback:(ICSettingCallback)callback;

/**
 * 设置W当前用户信息
 * @param device 设备
 * @param userInfo 当前用户信息
 * @param callback 回调
 */
- (void)setCurrentUserInfo_W:(ICDevice *)device userInfo:(ICUserInfo *)userInfo callback:(ICSettingCallback)callback;

/**
 * 删除W用户
 * @param device 设备
 * @param userId 用户ID
 * @param callback 回调
 */
- (void)deleteUser_W:(ICDevice *)device userId:(NSUInteger)userId callback:(ICSettingCallback)callback;

/**
 * 获取W用户列表，列表从onReceiveUserInfoList回调回来
 * @param device 设备
 * @param callback 回调
 */
- (void)getUserList_W:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 * 发起W扫描WiFi列表， WiFi列表将从onReceiveScanWifiInfo_W上来
 * @param device 设备
 * @param callback 回调
 */
- (void)startScanWifi_W:(ICDevice *)device callback:(ICSettingCallback)callback;
/**
  * 停止W扫描WiFi列表
  * @param device 设备
  * @param callback 回调
  */
- (void)stopScanWifi_W:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 * 配置W WiFi，配网状态将从onReceiveCurrentWifiInfo_W上来
 * @param device    设备
 * @param ssid      连接的SSID
 * @param password  密码
 * @param method    加密方法，根据onReceiveScanWifiInfo_W里面的method
 * @param callback  回调
 */
- (void)configWifi_W:(ICDevice *)device ssid:(NSString *)ssid password:(NSString *)password method:(NSInteger)method callback:(ICSettingCallback)callback;

/**
 * 设置W开机时的欢迎页
 * @param device 设备
 * @param enable 是否显示
 * @param callback 回调
 */
- (void)setHello_W:(ICDevice *)device enable:(BOOL)enable callback:(ICSettingCallback)callback;
/**
 * 设置W电源模式
 * @param device 设备
 * @param isNormal 是否低功耗
 * @param callback 回调
 */
- (void)setPowerMode_W:(ICDevice *)device isNormal:(BOOL)isNormal callback:(ICSettingCallback)callback;
/**
 * 设置W屏幕显示项
 * @param device 设备
 * @param items 显示项
 * @param callback 回调
 */
- (void)setScreen_W:(ICDevice *)device items:(NSArray<NSNumber *> *)items callback:(ICSettingCallback)callback;
/**
 * 唤醒W设备
 * @param device 设备
 * @param callback 回调
 */
- (void)wakeupScreen_W:(ICDevice *)device callback:(ICSettingCallback)callback;
/**
 * 设置W设备屏幕显示时间
 * @param device 设备
 * @param time   时间,秒
 * @param callback 回调
 */
- (void)setScreenTime_W:(ICDevice *)device time:(NSUInteger)time callback:(ICSettingCallback)callback;
/**
 * 设置W绑定，将会将会更新绑定标识，扫描时bindStatus和调用queryBindStatus_W能看到设备已绑定
 * @param device 设备
 * @param callback 回调
 */
- (void)bindDevice_W:(ICDevice *)device callback:(ICSettingCallback)callback;
/**
* 查询W绑定状态，onReceiveBindState_W回调绑定状态
* @param device 设备
* @param callback 回调
*/
- (void)queryBindStatus_W:(ICDevice *)device callback:(ICSettingCallback)callback;
/**
 * 重置W设备
 * @param device 设备
 * @param callback 回调
 */
- (void)reset_W:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 * 删除W设备所有用户数据
 * @param device 设备
 * @param callback 回调
 */
- (void)deleteAllUser_W:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 * 开始W设备升级
 * @param device 设备
 * @param currentVersion 当前版本
 * @param newVersion 新版本
 * @param callback 回调
 */
- (void)startUpgrade_W:(ICDevice *)device currentVersion:(NSString *)currentVersion newVersion:(NSString *)newVersion callback:(ICSettingCallback)callback;

/**
 * 读取历史数据，根据DeviceInfo判断是否支持
 * @param device 设备
 */
- (void)readHistoryData:(ICDevice *)device callback:(ICSettingCallback)callback;

/**
 * 设置营养数据
 * @param device 设备
 * @param foodId 食物ID
 * @param facts 营养数据列表
 * @param callback 回调
 */
- (void)setNutritionFacts:(ICDevice *)device foodId:(NSUInteger)foodId facts:(NSArray<ICNutritionFact *> *)facts callback:(ICSettingCallback)callback;

/**
 * 设置食物每个多少g对应的营养数据
 * @param device 设备
 * @param foodId 食物ID
 * @param name 食物名
 * @param icon 食物图片
 * @param weight 重量g
 * @param facts 营养数据列表
 * @param callback 回调
 */
- (void)setNutritionFactsInUnit:(ICDevice *)device foodId:(NSUInteger)foodId name:(NSString *)name icon:(NSString *)icon weight:(NSUInteger)weight facts:(NSArray<ICNutritionFact *> *)facts callback:(ICSettingCallback)callback;

/**
 * 更新常用食物每个多少g对应的营养数据
 * @param device 设备
 * @param foodIndex 食物索引
 * @param foodId 食物ID
 * @param name 食物名
 * @param icon 食物图片
 * @param weight 重量g
 * @param facts 营养数据列表
 * @param callback 回调
 */
- (void)setCommonNutritionFacts:(ICDevice *)device foodIndex:(NSUInteger)foodIndex foodId:(NSUInteger)foodId name:(NSString *)name icon:(NSString *)icon weight:(NSUInteger)weight facts:(NSArray<ICNutritionFact *> *)facts callback:(ICSettingCallback)callback;

/**
 * 删除常用食物
 * @param device 设备
 * @param foods 要删除的食物
 * @param callback 回调
 */
- (void)deleteCommonNutritionFacts:(ICDevice *)device foods:(NSArray<ICFoodInfo *> *)foods callback:(ICSettingCallback)callback;

/**
 * 设置常用食物顺序
 * @param device 设备
 * @param foods 食物顺序
 * @param callback 回调
 */
- (void)setCommonNutritionFactsOrder:(ICDevice *)device foods:(NSArray<ICFoodInfo *> *)foods callback:(ICSettingCallback)callback;

/**
 * 设置历史摄入列表
 * @param device 设备
 * @param rniList 摄入列表
 * @param callback 回调
 */
- (void)setRNIHistory:(ICDevice *)device userId:(NSUInteger)userId rniList:(NSArray<ICRNIHistoryData *> *)rniList callback:(ICSettingCallback)callback;

/**
 * 确认食物
 * @param device 设备
 * @param callback 回调
 */
- (void)confirmFood:(ICDevice *)device  callback:(ICSettingCallback)callback;

/**
 * 读取常用食物列表
 * @param device 设备
 * @param callback 回调
 */
- (void)readCommonFoods:(ICDevice *)device  callback:(ICSettingCallback)callback;

/**
 * 设置发送食物数量
 * @param device 设备
 * @param count 食物数量
 * @param callback 回调
 */
- (void)setSendFoodsCount:(ICDevice *) device count:(NSUInteger)count callback:(ICSettingCallback)callback;

/**
 * 设置设备当前的界面
 * @param device 设备
 * @param page 页面
 * @param callback 回调
 */
- (void)setCurrentPage:(ICDevice *)device page:(NSUInteger)page callback:(ICSettingCallback)callback;

/**
 * 唤醒设备
 * @param device 设备
 * @param callback 回调
 */
- (void)wakeupScreen:(ICDevice *)device callback:(ICSettingCallback)callback;

@end

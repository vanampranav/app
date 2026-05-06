//
//  ICWifiInfoData.h
//  ICDeviceManager
//
//  Created by Guobin Zheng on 2025/2/27.
//  Copyright © 2025 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 Wifi信息数据
 */
@interface ICWifiInfoData : NSObject

/**
 Wifi ssid
 */
@property (nonatomic, strong) NSString *ssid;
/**
 信号
 */
@property (nonatomic, assign) NSInteger rssi;
/**
 加密方式
 (扫描Wifi信息)
 */
@property (nonatomic, assign) NSUInteger method;
/**
状态，0:未配网，1:未连接wifi，2:已连接wifi未连接服务器，3:已连接服务器,4:wifi模块未上电
(当前Wifi信息)
 */
@property (nonatomic, assign) NSInteger status;
/**
ip
(当前Wifi信息)
 */
@property (nonatomic, strong) NSString *ip;

@end

NS_ASSUME_NONNULL_END

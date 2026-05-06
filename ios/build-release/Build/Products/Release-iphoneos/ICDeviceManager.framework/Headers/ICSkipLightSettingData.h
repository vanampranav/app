//
//  ICSkipLightSettingData.h
//  ICDeviceManager
//
//  Created by Guobin Zheng on 2024/5/27.
//  Copyright © 2024 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"


@interface ICSkipLightSettingParam : NSObject

/**
 红色(0~255)
 */
@property (nonatomic, assign) NSUInteger r;

/**
 绿色(0~255)
 */
@property (nonatomic, assign) NSUInteger g;

/**
 蓝色(0~255)
 */
@property (nonatomic, assign) NSUInteger b;

/**
 速度(0~255)
 */
@property (nonatomic, assign) NSUInteger modeValue;

@end

@interface ICSkipLightSettingData : NSObject

@property (nonatomic, assign) NSArray<ICSkipLightSettingParam *> *list;
@property (nonatomic, assign) ICSkipLightMode mode;

@end


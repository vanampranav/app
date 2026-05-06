//
//  ICDeviceMangerMIDeviceMap.h
//  ICDeviceManager
//
//  Created by symons on 2023/7/17.
//  Copyright © 2023 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICDeviceMangerMIDeviceMap : NSObject

/**
 设备类型
 */
@property (nonatomic, assign) ICDeviceType type;

/**
 设备通讯方式
 */
@property (nonatomic, assign) ICDeviceCommunicationType communicationType;

/**
设备子类型
 */
@property (nonatomic, assign) int subType;

/**
 其他标志
 */
@property (nonatomic, assign) NSUInteger otherFlag;

/**
 米家产品ID
 */
@property (nonatomic, assign) NSUInteger productId;



@end

NS_ASSUME_NONNULL_END

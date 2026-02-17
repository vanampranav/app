//
//  ICRNIHistoryData.h
//  ICDeviceManager
//
//  Created by icomon on 2025/1/20.
//  Copyright © 2025 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICRNIData.h"

NS_ASSUME_NONNULL_BEGIN
/**
 RNI历史数据
 */
@interface ICRNIHistoryData : NSObject

/**
 月
 */
@property (nonatomic, assign) NSUInteger month;
/**
 日
 */
@property (nonatomic, assign) NSUInteger day;

/**
 营养摄入列表
 */
@property (nonatomic, strong) NSArray<ICRNIData *> *rnis;

@end

NS_ASSUME_NONNULL_END

//
//  ICKitchenDeviceInfo.h
//  ICDeviceManager
//
//  Created by Symons on 2020/4/29.
//  Copyright © 2020 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICKitchenDeviceInfo : ICDeviceInfo

/**
 秤支持的功能
 */
@property(nonatomic, strong) NSArray<NSNumber *> *supportFuns;

/**
 支持秤上显示的营养数据类型
 */
@property(nonatomic, strong) NSArray<NSNumber *> *supportDataTypes;

/**
 当前秤上的历史数据数量
 */
@property(nonatomic, assign) NSUInteger historyCount;

/**
 图片大小端
 */
@property(nonatomic, assign) NSInteger imageEndian;

/**
 图片方向
 */
@property(nonatomic, assign) NSInteger imageDirection;

/**
 图片色彩深度
 */
@property(nonatomic, assign) NSInteger imageColorDepth;


/**
 当前语音识别开关：0关，1开
 */
@property(nonatomic, assign) BOOL isSoundSwitch;
/**
 食物图片分辨率-宽
 */
@property(nonatomic, assign) NSInteger foodImageWidth;
/**
 食物图片分辨率-高
 */
@property(nonatomic, assign) NSInteger foodImageHeight;
/**
 食物名称分辨率-高
 */
@property(nonatomic, assign) NSInteger foodNameHeight;



@end

NS_ASSUME_NONNULL_END

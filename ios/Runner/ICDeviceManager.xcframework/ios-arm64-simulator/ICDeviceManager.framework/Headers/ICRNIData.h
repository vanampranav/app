//
//  ICRNIData.h
//  ICDeviceManager
//
//  Created by icomon on 2025/1/20.
//  Copyright © 2025 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 RNI数据
 */
@interface ICRNIData : NSObject

/**
 数据类型
 */
@property (nonatomic, assign) NSUInteger type;

/**
 当前摄入量
 */
@property (nonatomic, assign) float current;

/**
 最大摄入量或目标摄入量
 */
@property (nonatomic, assign) float max;

/**
 进度,范围: 0~100%
 */
@property (nonatomic, assign) float progress;

@end

NS_ASSUME_NONNULL_END

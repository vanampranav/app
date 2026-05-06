//
//  ICNutritionFact.h
//  ICDeviceManager
//
//  Created by icomon on 2025/1/20.
//  Copyright © 2025 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 营养成份
 */
@interface ICNutritionFact : NSObject

///**
// 食物ID，如不需要填0
// */
//@property (nonatomic, assign) NSUInteger foodId;
/**
 营养数据类型
 */
@property (nonatomic, assign) NSUInteger type;
/**
 营养数值
 */
@property (nonatomic, assign) float value;


+ (instancetype)create:(NSUInteger)type value:(float)value;

@end

NS_ASSUME_NONNULL_END

//
//  ICFoodInfo.h
//  ICDeviceManager
//
//  Created by icomon on 2025/4/23.
//  Copyright © 2025 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 食物信息
 */
@interface ICFoodInfo : NSObject

/**
 食物序号
 */
@property (nonatomic, assign) NSUInteger foodIndex;
/**
 食物ID
 */
@property (nonatomic, assign) NSInteger foodId;

@end

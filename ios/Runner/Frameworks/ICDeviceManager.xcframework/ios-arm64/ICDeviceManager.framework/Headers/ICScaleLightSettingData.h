//
//  ICScaleLightSettingData.h
//  ICDeviceManager
//
//  Created by Guobin Zheng on 2024/5/27.
//  Copyright © 2024 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICScaleLightSettingData : NSObject

/*
 秤的灯光操作类型，0:灯光设置，1:获取灯光设置。
*/
@property (nonatomic, assign) NSInteger operateType;
/*
 秤的灯光编号 默认0
*/
@property (nonatomic, assign) NSInteger lightNum;
/*
 秤的灯光开关
*/
@property (nonatomic, assign) BOOL lightOn;
/*
  秤的灯光亮度 (暂时秤支持 50、100)
*/
@property (nonatomic, assign) NSInteger brightness;

/*
 秤的灯光 rgb。红色（255,0,0），橙色（255,165,0），黄色（255,255,0），绿色（0,255,0），蓝色（0,0,255），青色（0,255,255），深紫色（139,0,255）
*/
@property (nonatomic, assign) NSUInteger r;

@property (nonatomic, assign) NSUInteger g;

@property (nonatomic, assign) NSUInteger b;

@end

NS_ASSUME_NONNULL_END

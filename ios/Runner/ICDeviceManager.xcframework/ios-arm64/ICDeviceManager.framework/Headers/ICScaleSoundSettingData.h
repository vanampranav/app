//
//  ICScaleSoundSettingData.h
//  ICDeviceManager
//
//  Created by Guobin Zheng on 2023/4/20.
//  Copyright © 2023 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICScaleSoundSettingData : NSObject

/// 秤的语言类型 根据设备返回的支持列表来选择。
@property (nonatomic, assign) NSUInteger soundLanguageCode;
/// 秤的音量大小 0:静音 1~30:小 31~70:中 71~100:大
@property (nonatomic, assign) NSUInteger soundVolume;
/// 秤的语音播报开关
@property (nonatomic, assign) BOOL soundBroadcastOn;
/// 秤的音效开关
@property (nonatomic, assign) BOOL soundEffectsOn;
/// 秤支持的语言列表
@property (nonatomic, strong) NSArray<NSNumber *> *listSoundSupportLanguage;

@end

NS_ASSUME_NONNULL_END

//
//  ICSkipSoundSettingData.h
//  ICDeviceManager
//
//  Created by icomon on 2022/3/16.
//  Copyright © 2022 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICSkipSoundSettingData : NSObject

/// 是否开启语音开关
@property (nonatomic, assign) BOOL soundOn;
/// 语音类型
@property (nonatomic, assign) ICSkipSoundType soundType;
/// 声音大小
@property (nonatomic, assign) NSUInteger soundVolume;
/// 满分开关
@property (nonatomic, assign) BOOL fullScoreOn;
/// 满分速率
@property (nonatomic, assign) NSUInteger fullScoreBPM;
/// 语音间隔模式
@property (nonatomic, assign) ICSkipSoundMode soundMode;
/// 模式参数
@property (nonatomic, assign) NSUInteger modeParam;
/// 是否自动停止播放，YES:APP下发开始后，跳绳不会播放语音 ，NO:跳绳和APP都会播放语音
@property (nonatomic, assign) BOOL isAutoStop;

/// 语音助手开关，仅S2支持
@property (nonatomic, assign) BOOL assistantOn;
/// 节拍器开关，仅S2支持
@property (nonatomic, assign) BOOL bpmOn;
/// 震动开关，仅S2支持
@property (nonatomic, assign) BOOL vibrationOn;
/// 心率上限报警开关，仅S2支持
@property (nonatomic, assign) BOOL hrMonitorOn;






@end

NS_ASSUME_NONNULL_END

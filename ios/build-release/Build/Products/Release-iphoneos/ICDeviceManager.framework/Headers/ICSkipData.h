//
//  ICSkipData.h
//  ICDeviceManager
//
//  Created by Symons on 2019/10/19.
//  Copyright © 2019 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"

NS_ASSUME_NONNULL_BEGIN



/**
 * 间歇跳数据
 */
@interface ICSkipInterruptData : NSObject

/**
 * 序号
 */
@property (nonatomic, assign) NSUInteger index;

/**
 * 休息时间
 */
@property (nonatomic, assign) NSUInteger rest_time;


/**
 * 时长
 */
@property (nonatomic, assign) NSUInteger time;

/**
 * 跳的个数
 */
@property (nonatomic, assign) NSUInteger skip_count;


/**
 * 热量消耗
 */
@property (nonatomic, assign) double calories_burned;

/**
 * 平均速度
 */
@property (nonatomic, assign) NSUInteger avg_freq;

/**
 * 绊绳次数
 */
@property (nonatomic, assign) NSUInteger freq_count;

@end



/**
 * 跳绳频次
 */
@interface ICSkipFreqData : NSObject

/**
 * 持续时间
 */
@property (nonatomic, assign) NSUInteger duration;

/**
 * 次数
 */
@property (nonatomic, assign) NSUInteger skip_count;

@end



/**
 * 跳绳数据
 */
@interface ICSkipData : NSObject


    /**
     是否稳定
     */
    @property (nonatomic, assign) BOOL isStabilized;

    /**
     节点ID
     */
    @property (nonatomic, assign) NSUInteger nodeId;
    /**
     节点电量
     */
    @property (nonatomic, assign) NSUInteger battery;
    /**
     节点信息
     */
    @property (nonatomic, assign) NSUInteger nodeInfo;

    /**
     跳绳状态,非所有设备都有，目前仅S2有
     */
    @property (nonatomic, assign) ICSkipStatus status;

    /**
     节点Mac
     */
    @property (nonatomic, strong) NSString* nodeMac;


    /**
     * 组数,仅S2有
     */
    @property (nonatomic, assign) NSUInteger setting_group;

    /**
     * 设置休息时间,仅S2有
     */
    @property (nonatomic, assign) NSUInteger setting_rest_time;
    
    /**
     * 测量时间，单位:秒
     */
    @property (nonatomic, assign) NSUInteger time;
    
    /**
     * 跳绳模式
     */
    @property (nonatomic, assign) ICSkipMode mode;
    
    /**
     * 设置的参数
     */
    @property (nonatomic, assign) NSUInteger  setting;
    
    /**
     * 跳绳使用的时间
     */
    @property (nonatomic, assign) NSUInteger elapsed_time;

    /**
     * 跳绳实际使用的时间，不是所有都支持
     */
    @property (nonatomic, assign) NSUInteger actual_time;


    /**
     * 跳的次数
     */
    @property (nonatomic, assign) NSUInteger skip_count;
    
    /**
     * 平均频次
     */
    @property (nonatomic, assign) NSUInteger  avg_freq;

    /**
     * 当前速度,仅S2有
     */
    @property (nonatomic, assign) NSUInteger  cur_speed;

    /**
     * 最快频次
     */
    @property (nonatomic, assign) NSUInteger fastest_freq;

    /**
     * 热量消耗
     */
    @property (nonatomic, assign) double calories_burned;

    /**
     * 燃脂效率
     */
    @property (nonatomic, assign) double fat_burn_efficiency;

    /**
     * 绊绳总数
     */
    @property (nonatomic, assign) NSUInteger freq_count;

    /**
     * 最多连跳
     */
    @property (nonatomic, assign) NSUInteger most_jump;

    /**
     * 心率
     */
    @property (nonatomic, assign) NSUInteger hr;

    /**
     * 跳绳频次数据
     */
    @property (nonatomic, strong) NSArray<ICSkipFreqData *> *freqs;

    /**
     * 间歇跳数据
     */
    @property (nonatomic, strong) NSArray<ICSkipInterruptData *> *interrupts;

@end

NS_ASSUME_NONNULL_END

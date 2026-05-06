//
//  ICScaleDeviceInfo.h
//  ICDeviceManager
//
//  Created by Symons on 2020/4/29.
//  Copyright © 2020 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"
#import "ICDeviceInfo.h"
#import "ICScaleSoundSettingData.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICScaleDeviceInfo : ICDeviceInfo

@property(nonatomic, assign) NSUInteger   kg_scale_division;

@property(nonatomic, assign) NSUInteger   lb_scale_division;

@property(nonatomic, assign) BOOL isSupportHr;

@property(nonatomic, assign) BOOL isSupportGravity;

@property(nonatomic, assign) BOOL isSupportBalance;

@property(nonatomic, assign) BOOL isSupportOTA;

@property(nonatomic, assign) BOOL isSupportOffline;

@property(nonatomic, assign) NSUInteger   bfDataCalcType;

@property(nonatomic, assign) BOOL isSupportUserInfo;

@property(nonatomic, assign) NSUInteger  maxUserCount;

@property(nonatomic, assign) NSUInteger  batteryType;

@property(nonatomic, assign) ICBFAType bfaType;

@property(nonatomic, assign) ICBFAType bfaType2;

@property(nonatomic, assign) BOOL isSupportUnitKg;

@property(nonatomic, assign) BOOL isSupportUnitLb;

@property(nonatomic, assign) BOOL isSupportUnitStLb;

@property(nonatomic, assign) BOOL isSupportUnitJin;

@property(nonatomic, assign) NSUInteger   pole;

@property(nonatomic, assign) NSUInteger   isSupportChangePole;

@property(nonatomic, assign) NSUInteger   impendenceType;

@property(nonatomic, assign) NSUInteger   impendenceProperty;

@property(nonatomic, assign) NSUInteger   impendencePrecision;

@property(nonatomic, assign) NSUInteger   impendenceCount;

@property(nonatomic, assign) BOOL enableMeasureImpendence;

@property(nonatomic, assign) BOOL enableMeasureHr;

@property(nonatomic, assign) BOOL enableMeasureBalance;

@property(nonatomic, assign) BOOL enableMeasureGravity;

/**
 * 是否启动婴儿模式，默认:NO，仅支持的设备有效
 */
@property(nonatomic, assign) BOOL enableBabyMode;

@property(nonatomic, strong) ICScaleSoundSettingData *icScaleSoundSettingData;

@property(nonatomic, strong) NSArray<NSNumber *> *supportFuns;

@property(nonatomic, strong) NSArray<NSNumber *> *listSupportUIItem;

/**
 * 是否支持通过setting更新用户信息。
 */
@property(nonatomic, assign) BOOL isSettingUpdateUsers;

/**
 * http证书版本
 */
@property(nonatomic, assign) NSUInteger httpsCertificateVer;

@end

NS_ASSUME_NONNULL_END

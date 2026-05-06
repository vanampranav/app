//
//  ICUserInfo.h
//  ICleDevice
//
//  Created by lifesense－mac on 17/4/18.
//  Copyright © 2017年 lifesense. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ICConstant.h"

@class ICRNIData;

/**
 用户信息
 */
@interface ICUserInfo : NSObject

/**
 用户编号,默认:1
 */
@property (nonatomic, assign) NSUInteger userIndex;

/**
 用户ID,默认:0
 */
@property (nonatomic, assign) NSUInteger userId;


/**
 用户呢称,默认:"icomon"
 */
@property (nonatomic, strong) NSString *nickName;
/**
 用户呢称校验码,默认0
 */
@property (nonatomic, assign) NSUInteger nickNameCS;
/**
 用户头像序列
 */
@property (nonatomic, assign) NSUInteger headTypeSequence;

/**
 用户头像索引
 */
@property (nonatomic, assign) NSUInteger headType;


/**
 语言,默认:1
 */
@property (nonatomic, assign) NSUInteger lang;

/**
 节点ID,竞技款
 */
@property (nonatomic, assign) NSUInteger nodeId;


/**
 年级竞技款头像
 */
@property (nonatomic, assign) NSUInteger sclass;

/**
 班级,竞技款
 */
@property (nonatomic, assign) NSUInteger grade;

/**
 学号,竞技款
 */
@property (nonatomic, assign) NSUInteger studentNo;

/**
 身高(cm),默认:172cm
 */
@property (nonatomic, assign) NSUInteger height;

/**
 体重(kg),默认:60.0kg
 */
@property (nonatomic, assign) float weight;

/**
 年龄,默认:24
 */
@property (nonatomic, assign) NSUInteger age;

/**
 性别,默认:ICSexTypeMale
 */
@property (nonatomic, assign) ICSexType sex;

/**
 上次的阻抗
 */
@property (nonatomic, assign) float lastImpedance;
/**
 目标类型: 1:体重，2:BMI，3:体脂率
 */
@property (nonatomic, assign) int targetType;

/**
 起始体重(kg),默认:50.0kg
 */
@property (nonatomic, assign) float startWeight;
/**
 目标体重(kg),默认:50.0kg
 */
@property (nonatomic, assign) float targetWeight;

/**
 体重方向,默认:0 减重，1:增重
 */
@property (nonatomic, assign) NSUInteger weightDirection;

/**
 使用体脂算法版本,默认:ICBFATypeWLA01
 */
@property (nonatomic, assign) ICBFAType bfaType;


/**
 锁定使用体脂算法版本,设置以后，设备上传上来的算法版本将不生效,默认:ICBFATypeWLA01
 */
@property (nonatomic, assign) ICBFAType lockBfaType;

/**
 用户类型,默认:ICPeopleTypeNormal
 */
@property (nonatomic, assign) ICPeopleType peopleType;

/**
 用户默认的体重单位,默认:ICWeightUnitKg
 */
@property (nonatomic, assign) ICWeightUnit weightUnit;

/**
 用户默认的围尺单位,默认:ICRulerUnitCM
 */
@property (nonatomic, assign) ICRulerUnit rulerUnit;

/**
 用户默认的围尺测量模式,默认:ICRulerMeasureModeLength
 */
@property (nonatomic, assign) ICRulerMeasureMode rulerMode;

/**
 厨房秤默认单位,默认:ICKitchenScaleUnitG
 */
@property (nonatomic, assign) ICKitchenScaleUnit kitchenUnit;

/**
 BMI标准,默认:ICBMIStandard1
 */
@property (nonatomic, assign) ICBMIStandard stanard;

/**
 * 是否启用测量阻抗,默认:YES,仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableMeasureImpendence;
/**
 * 是否启用测量HR,默认:YES,仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableMeasureHr;
/**
 * 是否启用测量平衡,默认:YES,仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableMeasureBalance;
/**
 * 是否启用测量重心,默认:YES,仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableMeasureGravity;
/**
 * 是否启用小物模式,默认:YES,仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableSmallThing;
/**
 * 是否启动婴儿模式，默认:NO，仅支持的设备有效
 */
@property (nonatomic, assign)  BOOL enableBabyMode;

/**
 * 是否开启体围计算,对于37算法，默认是不支持的
 */
@property (nonatomic, assign)  BOOL enableGirth;

/**
 营养数据摄入列表
 */
@property (nonatomic, strong) NSArray<ICRNIData *> *rniList;


@end

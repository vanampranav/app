//
//  ICBodyFatAlgorithms.h
//  ICDeviceManager
//
//  Created by Symons on 2018/9/26.
//  Copyright © 2018年 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>


@class ICUserInfo;
@class ICWeightData;

/**
 体脂算法接口
 */
@protocol ICBodyFatAlgorithmsManager <NSObject>

/**
 重算体脂数据

 @param weightData 体重数据(原来sdk回调出去的数据)
 @param userInfo 用户信息
 @return 重算后的数据
 */
- (ICWeightData *)reCalcBodyFatWithWeightData:(ICWeightData *)weightData userInfo:(ICUserInfo *)userInfo;

@end

//
//  ICCrc.h
//  ICDeviceManager
//
//  Created by icomon on 2023/10/11.
//  Copyright © 2023 Symons. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ICCrc : NSObject

+ (NSUInteger)crc_modbus:(NSData *)data;

@end

NS_ASSUME_NONNULL_END

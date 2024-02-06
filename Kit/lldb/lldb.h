//
//  lldb.h
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 03/02/2024
//  Using Swift 5.0
//  Running on macOS 14.3
//
//  Copyright © 2024 Serhiy Mytrovtsiy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLDB:NSObject
-(instancetype)init:(NSString *) path;

-(NSArray *)keys:(NSString *)key;

-(bool)insert:(NSString *)key value:(NSString *)value;

-(NSString *)findOne:(NSString *)key;
-(NSString *)findLast:(NSString *)prefix;
-(NSArray *)findMany:(NSString *)prefix;

-(bool)deleteOne:(NSString *)key;
-(bool)deleteMany:(NSArray*)keys;

-(void)close;

@end

//
//  bridge.h
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 30/03/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//
//  Based on https://github.com/yujitach/MenuMeters/blob/master/hardware_reader/applesilicon_hardware_reader.m
//

#include <IOKit/hidsystem/IOHIDEventSystemClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

#define IOHIDEventFieldBase(type)   (type << 16)
#define kIOHIDEventTypeTemperature  15
#define kIOHIDEventTypePower        25

typedef enum AppleSiliconSensorType: NSUInteger {
    temperature=1,
    current=2,
    voltage=3,
} AppleSiliconSensorType;

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t , int32_t, int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

NSDictionary*AppleSiliconSensors(int page, int usage, int32_t type);

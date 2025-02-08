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
#include <CoreFoundation/CoreFoundation.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

#define IOHIDEventFieldBase(type)   (type << 16)
#define kIOHIDEventTypeTemperature  15
#define kIOHIDEventTypePower        25

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t , int32_t, int64_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

NSDictionary*AppleSiliconSensors(int page, int usage, int32_t type);

CFDictionaryRef IOReportCopyChannelsInGroup(CFStringRef a, CFStringRef b, uint64_t c, uint64_t d, uint64_t e);
void IOReportMergeChannels(CFDictionaryRef a, CFDictionaryRef b, CFTypeRef null);
IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef b, CFMutableDictionaryRef* c, uint64_t d, CFTypeRef e);
CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef a, CFMutableDictionaryRef b, CFTypeRef c);
CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef a, CFDictionaryRef b, CFTypeRef c);
CFStringRef IOReportChannelGetGroup(CFDictionaryRef a);
CFStringRef IOReportChannelGetSubGroup(CFDictionaryRef a);
CFStringRef IOReportChannelGetChannelName(CFDictionaryRef a);
CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef a);
int32_t IOReportStateGetCount(CFDictionaryRef a);
CFStringRef IOReportStateGetNameForIndex(CFDictionaryRef a, int32_t b);
int64_t IOReportStateGetResidency(CFDictionaryRef a, int32_t b);
int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef a, int32_t b);

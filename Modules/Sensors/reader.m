//
//  reader.m
//  Sensors
//
//  Created by Serhiy Mytrovtsiy on 06/05/2021.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2021 Serhiy Mytrovtsiy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "bridge.h"

@interface StatsHIDSensorSource : NSObject {
    IOHIDEventSystemClientRef _client;
    CFArrayRef _services;
    NSTimeInterval _lastDiscovery;
    BOOL _missingEvents;
}
- (NSDictionary *)readPage:(int32_t)page usage:(int32_t)usage type:(int32_t)type;
- (void)reset;
@end

@implementation StatsHIDSensorSource

- (void)reset {
    if (_services) { CFRelease(_services); _services = NULL; }
    if (_client) { CFRelease(_client); _client = NULL; }
    _lastDiscovery = 0;
    _missingEvents = NO;
}

- (void)dealloc {
    [self reset];
}

- (NSDictionary *)readPage:(int32_t)page usage:(int32_t)usage type:(int32_t)type {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (!_client) {
        _client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (!_client) { return @{}; }
        NSDictionary *matching = @{@"PrimaryUsagePage": @(page), @"PrimaryUsage": @(usage)};
        IOHIDEventSystemClientSetMatching(_client, (__bridge CFDictionaryRef)matching);
    }
    
    // Rediscover occasionally for topology changes; retry missing events sooner.
    NSTimeInterval discoveryInterval = _missingEvents ? 5 : 60;
    if (!_services || now - _lastDiscovery >= discoveryInterval) {
        if (_services) { CFRelease(_services); }
        _services = IOHIDEventSystemClientCopyServices(_client);
        _lastDiscovery = now;
        if (!_services || CFArrayGetCount(_services) == 0) {
            [self reset];
            return @{};
        }
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    _missingEvents = NO;
    for (CFIndex i = 0; i < CFArrayGetCount(_services); i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(_services, i);
        NSString* name = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("Product")));
        
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, type, 0, 0);
        if (event == nil) {
            _missingEvents = YES;
            continue;
        }
        
        if (name && event) {
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(type));
            dict[name]=@(value);
        }
        
        CFRelease(event);
    }
    
    if (dict.count == 0) { [self reset]; }
    return dict;
}

@end

static NSMutableDictionary<NSString *, StatsHIDSensorSource *> *sensorSources(void) {
    static NSMutableDictionary *sources;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sources = [NSMutableDictionary dictionary]; });
    return sources;
}

NSDictionary*AppleSiliconSensors(int32_t page, int32_t usage, int32_t type) {
    NSMutableDictionary *sources = sensorSources();
    @synchronized (sources) {
        NSString *key = [NSString stringWithFormat:@"%d:%d", page, usage];
        StatsHIDSensorSource *source = sources[key];
        if (!source) {
            source = [[StatsHIDSensorSource alloc] init];
            sources[key] = source;
        }
        return [source readPage:page usage:usage type:type];
    }
}

void AppleSiliconSensorsReset(void) {
    NSMutableDictionary *sources = sensorSources();
    @synchronized (sources) {
        [sources removeAllObjects];
    }
}

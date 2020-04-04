//
//  SystemKit.c
//  Stats
//
// SMC code borrowed from https://github.com/lavoiesl/osx-cpu-temp.
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>

#include "SystemKit.h"

static io_connect_t conn;

UInt32 _strtoul(char* str, int size, int base) {
    UInt32 total = 0;
    int i;

    for (i = 0; i < size; i++) {
        if (base == 16)
            total += str[i] << (size - 1 - i) * 8;
        else
            total += (unsigned char)(str[i] << (size - 1 - i) * 8);
    }
    return total;
}

void _ultostr(char* str, UInt32 val) {
    str[0] = '\0';
    sprintf(str, "%c%c%c%c",
        (unsigned int)val >> 24,
        (unsigned int)val >> 16,
        (unsigned int)val >> 8,
        (unsigned int)val);
}

void t(void *            refcon,
io_service_t        service,
uint32_t        messageType,
void *            messageArgument) {
    printf("Hmmmm");
}

kern_return_t SMCOpen(void) {
    kern_return_t result;
    io_iterator_t iterator;
    io_object_t device;

    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess) {
        printf("Error: IOServiceGetMatchingServices() = %08x\n", result);
        return 1;
    }

    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0) {
        printf("Error: no SMC found\n");
        return 1;
    }

    result = IOServiceOpen(device, mach_task_self(), 0, &conn);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess) {
        printf("Error: IOServiceOpen() = %08x\n", result);
        return 1;
    }
    
    return kIOReturnSuccess;
}

kern_return_t SMCClose(void) {
    return IOServiceClose(conn);
}

kern_return_t SMCCall(int index, SMCKeyData_t* inputStructure, SMCKeyData_t* outputStructure) {
    size_t structureInputSize;
    size_t structureOutputSize;

    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);

#if MAC_OS_X_VERSION_10_5
    return IOConnectCallStructMethod(conn, index,
        // inputStructure
        inputStructure, structureInputSize,
        // ouputStructure
        outputStructure, &structureOutputSize);
#else
    return IOConnectMethodStructureIStructureO(conn, index,
        structureInputSize, /* structureInputSize */
        &structureOutputSize, /* structureOutputSize */
        inputStructure, /* inputStructure */
        outputStructure); /* ouputStructure */
#endif
}

kern_return_t SMCReadKey(UInt32Char_t key, SMCVal_t* val) {
    kern_return_t result;
    SMCKeyData_t inputStructure;
    SMCKeyData_t outputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}

double GetTemperature(char* key) {
    SMCVal_t val;
    kern_return_t result;

    result = SMCReadKey(key, &val);
    if (result == kIOReturnSuccess) {
        if (val.dataSize > 0) {
            if (strcmp(val.dataType, DATATYPE_SP78) == 0) {
                int intValue = val.bytes[0] * 256 + (unsigned char)val.bytes[1];
                return intValue / 256.0;
            }
        }
    } else {
        printf("Error: SMCReadKey() = %08x\n", result);
    }
    
    return 0.0;
}

float GetFanRPM(char* key) {
    SMCVal_t val;
    kern_return_t result;

    result = SMCReadKey(key, &val);
    if (result == kIOReturnSuccess) {
        if (val.dataSize > 0) {
            if (strcmp(val.dataType, DATATYPE_FPE2) == 0) {
                return ntohs(*(UInt16*)val.bytes) / 4.0;
            }
        }
    }
    return -1.f;
}

PowerManagmentInformation *GetPowerInfo() {
    PowerManagmentInformation *info = malloc(sizeof(PowerManagmentInformation));
    
    CFTypeRef power_sources = IOPSCopyPowerSourcesInfo();
    CFTypeRef external_adapter = IOPSCopyExternalPowerAdapterDetails();
    
    /* Get information aboud external adapter */
    if (external_adapter != NULL) {
        CFNumberRef watts = CFDictionaryGetValue(external_adapter, CFSTR(kIOPSPowerAdapterWattsKey));
        if (watts) {
            CFNumberGetValue(watts, kCFNumberDoubleType, &info->ACWatts);
            CFRelease(watts);
        }
        
        CFRelease(external_adapter);
    }
    
    if(power_sources == NULL) {
        return NULL;
    }
    
    CFArrayRef list = IOPSCopyPowerSourcesList(power_sources);
    CFDictionaryRef battery = NULL;

    if(list == NULL) {
        CFRelease(power_sources);
        return NULL;
    }
    
    /* Get the battery */
    for(int i = 0; i < CFArrayGetCount(list) && battery == NULL; ++i) {
        CFDictionaryRef candidate = IOPSGetPowerSourceDescription(power_sources, CFArrayGetValueAtIndex(list, i));
        CFStringRef type;
        
        if(candidate != NULL) {
            type = (CFStringRef) CFDictionaryGetValue(candidate, CFSTR(kIOPSTransportTypeKey));

            if(kCFCompareEqualTo == CFStringCompare(type, CFSTR(kIOPSInternalType), 0)) {
                CFRetain(candidate);
                battery = candidate;
            }
        }
    }

    if(battery != NULL) {
        CFStringRef power_state = CFDictionaryGetValue(battery, CFSTR(kIOPSPowerSourceStateKey));
        
        CFNumberRef max_capacity = CFDictionaryGetValue(battery, CFSTR(kIOPSMaxCapacityKey));
        CFNumberRef design_capacity = CFDictionaryGetValue(battery, CFSTR(kIOPSDesignCapacityKey));
        CFNumberRef current_capacity = CFDictionaryGetValue(battery, CFSTR(kIOPSCurrentCapacityKey));
        
        CFNumberRef amperage = CFDictionaryGetValue(battery, CFSTR(kIOPSCurrentKey));
        CFNumberRef voltage = CFDictionaryGetValue(battery, CFSTR(kIOPSVoltageKey));
        CFNumberRef temperature = CFDictionaryGetValue(battery, CFSTR(kIOPSTemperatureKey));
        
        /* Determine the AC state */
        info->isCharging = kCFCompareEqualTo == CFStringCompare(power_state, CFSTR(kIOPSACPowerValue), 0);
        
        /* Get capacity */
        if (max_capacity) {
            CFNumberGetValue(max_capacity, kCFNumberDoubleType, &info->maxCapacity);
            CFRelease(max_capacity);
        }
        if (design_capacity) {
            CFNumberGetValue(design_capacity, kCFNumberDoubleType, &info->designCapacity);
            CFRelease(design_capacity);
        }
        if (current_capacity) {
            CFNumberGetValue(current_capacity, kCFNumberDoubleType, &info->currentCapacity);
            CFRelease(current_capacity);
        }
        
        /* Determine the level */
        if (info->currentCapacity && info->maxCapacity) {
            info->level = (info->currentCapacity * 100.0) / info->maxCapacity;
        }
        
        /* Get the parameters */
        if (amperage) {
            CFNumberGetValue(amperage, kCFNumberDoubleType, &info->amperage);
            CFRelease(amperage);
        }
        if (voltage) {
            printf("2\n");
            CFNumberGetValue(voltage, kCFNumberDoubleType, &info->voltage);
            CFRelease(voltage);
        }
        if (temperature) {
            printf("3\n");
            CFNumberGetValue(temperature, kCFNumberDoubleType, &info->voltage);
            CFRelease(temperature);
        }
        
//        printf("%f\n", info->amperage);
//        printf("%f\n", test);
//        printf("%f\n", info->temperature);
//        printf("\n%hhu\n", info->isCharging);
        
//        printf("%u", info->level);
        
        CFRelease(battery);
    }

    CFRelease(list);
    CFRelease(power_sources);
    
    free(info);
    return info;
}

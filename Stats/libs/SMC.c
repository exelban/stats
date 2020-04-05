//
//  SMC.c
//  Stats
//
// SMC code borrowed from https://github.com/lavoiesl/osx-cpu-temp.
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

#include <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>

#include <sys/types.h>
#include <sys/sysctl.h>

#include "SMC.h"

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

void GetTemperatures(Temperatures *list) {
    list->termal_zone_0 = GetTemperature(SMC_TEMP_TERMALZONE_0);
    list->termal_zone_1 = GetTemperature(SMC_TEMP_TERMALZONE_1);
    list->termal_ambient_0 = GetTemperature(SMC_TEMP_AMBIENT_AIR_0);
    list->termal_ambient_1 = GetTemperature(SMC_TEMP_AMBIENT_AIR_1);
    list->termal_heatpipe_0 = GetTemperature(SMC_TEMP_HEATPIPE_0);
    list->termal_heatpipe_1 = GetTemperature(SMC_TEMP_HEATPIPE_1);
    list->termal_heatpipe_2 = GetTemperature(SMC_TEMP_HEATPIPE_2);
    list->termal_heatpipe_3 = GetTemperature(SMC_TEMP_HEATPIPE_3);
    
    list->cpu_0_die = GetTemperature(SMC_TEMP_CPU_0_DIE);
    list->cpu_0_diode = GetTemperature(SMC_TEMP_CPU_0_DIODE);
    list->cpu_0_heatsink = GetTemperature(SMC_TEMP_CPU_0_HEATSINK);
    list->cpu_0_proximity = GetTemperature(SMC_TEMP_CPU_0_PROXIMITY);
    list->cpu_1_die = GetTemperature(SMC_TEMP_CPU_1_DIE);
    list->cpu_1_diode = GetTemperature(SMC_TEMP_CPU_1_DIODE);
    list->cpu_1_heatsink = GetTemperature(SMC_TEMP_CPU_1_HEATSINK);
    list->cpu_1_proximity = GetTemperature(SMC_TEMP_CPU_1_PROXIMITY);
    
    list->cpu_1 = GetTemperature(SMC_TEMP_CPU_CORE_1);
    list->cpu_2 = GetTemperature(SMC_TEMP_CPU_CORE_2);
    list->cpu_3 = GetTemperature(SMC_TEMP_CPU_CORE_3);
    list->cpu_4 = GetTemperature(SMC_TEMP_CPU_CORE_4);
    list->cpu_5 = GetTemperature(SMC_TEMP_CPU_CORE_5);
    list->cpu_6 = GetTemperature(SMC_TEMP_CPU_CORE_6);
    list->cpu_7 = GetTemperature(SMC_TEMP_CPU_CORE_7);
    list->cpu_8 = GetTemperature(SMC_TEMP_CPU_CORE_8);
    
    list->gpu_diode = GetTemperature(SMC_TEMP_GPU_0_DIODE);
    list->gpu_heatsink = GetTemperature(SMC_TEMP_GPU_0_HEATSINK);
    list->gpu_proximity = GetTemperature(SMC_TEMP_GPU_0_PROXIMITY);
    
    list->mem_proximity = GetTemperature(SMC_TEMP_MEM_SLOTS);
    list->mem_0 = GetTemperature(SMC_TEMP_MEM_SLOT_0);
    list->mem_1 = GetTemperature(SMC_TEMP_MEM_SLOT_1);
    list->mem_2 = GetTemperature(SMC_TEMP_MEM_SLOT_2);
    list->mem_3 = GetTemperature(SMC_TEMP_MEM_SLOT_3);
    
    list->pci_proximity = GetTemperature(SMC_TEMP_PCI_SLOTS);
    list->pci_0 = GetTemperature(SMC_TEMP_PCI_SLOT_0);
    list->pci_1 = GetTemperature(SMC_TEMP_PCI_SLOT_1);
    list->pci_2 = GetTemperature(SMC_TEMP_PCI_SLOT_2);
    list->pci_3 = GetTemperature(SMC_TEMP_PCI_SLOT_3);
    
    list->sensor_mainboard = GetTemperature(SMC_TEMP_MAINBOARD_PROXIMITY);
    list->sensor_powerboard = GetTemperature(SMC_TEMP_POWERBOARD_PROXIMITY);
    list->sensor_battery = GetTemperature(SMC_TEMP_BATTERY_PROXIMITY);
    list->sensor_airport = GetTemperature(SMC_TEMP_AIRPORT_PROXIMITY);
    list->sensor_lcd = GetTemperature(SMC_TEMP_LCD_PROXIMITY);
    list->sensor_odd = GetTemperature(SMC_TEMP_ODD_PROXIMITY);
    
    list->northbridge_die = GetTemperature(SMC_TEMP_NORTHBRIDGE_DIE);
    list->northbridge_proximity = GetTemperature(SMC_TEMP_NORTHBRIDGE_PROXIMITY);
    
    list->hdd_0 = GetTemperature(SMC_TEMP_HDD_0);
    list->hdd_1 = GetTemperature(SMC_TEMP_HDD_1);
    list->hdd_2 = GetTemperature(SMC_TEMP_HDD_2);
    list->hdd_3 = GetTemperature(SMC_TEMP_HDD_3);
    
    list->thunderbolt_0 = GetTemperature(SMC_TEMP_THUNDERBOLT_0);
    list->thunderbolt_1 = GetTemperature(SMC_TEMP_THUNDERBOLT_1);
    list->thunderbolt_2 = GetTemperature(SMC_TEMP_THUNDERBOLT_2);
    list->thunderbolt_3 = GetTemperature(SMC_TEMP_THUNDERBOLT_3);
}

void GetVoltages(Voltages *list) {
    
}

void GetPowers(Powers *list) {
    
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


int64_t GetCPUFrequency() {
    int mib[2];
    unsigned int freq;
    size_t len;

    mib[0] = CTL_HW;
    mib[1] = HW_CPU_FREQ;
    len = sizeof(freq);
    sysctl(mib, 2, &freq, &len, NULL, 0);

    return freq;
}

//
//  SystemKit.h
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

#define SMC_TEMP_AMBIENT_AIR_0 "TA0P"
#define SMC_TEMP_AMBIENT_AIR_1 "TA1P"

#define SMC_TEMP_CPU_0_DIE "TC0F"
#define SMC_TEMP_CPU_0_DIODE "TC0D"
#define SMC_TEMP_CPU_0_HEATSINK "TC0H"
#define SMC_TEMP_CPU_0_PROXIMITY "TC0P"

#define SMC_TEMP_ENCLOSURE_BASE_0 "TB0T"
#define SMC_TEMP_ENCLOSURE_BASE_1 "TB1T"
#define SMC_TEMP_ENCLOSURE_BASE_2 "TB2T"
#define SMC_TEMP_ENCLOSURE_BASE_3 "TB3T"

#define SMC_TEMP_GPU_0_DIODE "TG0D"
#define SMC_TEMP_GPU_0_HEATSINK "TG0H"
#define SMC_TEMP_GPU_0_PROXIMITY "TG0P"

#define SMC_TEMP_HDD_PROXIMITY "TH0P"
#define SMC_TEMP_LCD_PROXIMITY "TL0P"
#define SMC_TEMP_MISC_PROXIMITY "Tm0P"
#define SMC_TEMP_ODD_PROXIMITY "TO0P"

#define SMC_TEMP_HEATSINK_0 "Th0H"
#define SMC_TEMP_HEATSINK_1 "Th1H"
#define SMC_TEMP_HEATSINK_2 "Th2H"

#define SMC_TEMP_MEM_SLOT_0 "TM0S"
#define SMC_TEMP_MEM_SLOTS_PROXIMITY "TM0P"

#define SMC_TEMP_NORTHBRIDGE "TN0H"
#define SMC_TEMP_NORTHBRIDGE_DIODE "TN0D"
#define SMC_TEMP_NORTHBRIDGE_PROXIMITY "TN0P"

#define SMC_TEMP_PALM_REST "Ts0P"
#define PWR_TEMP_SUPPLY_PROXIMITY "Tp0P"

#define SMC_TEMP_THUNDERBOLT_0 "TI0P"
#define SMC_TEMP_THUNDERBOLT_1 "TI1P"

#define SMC_FAN0_RPM "F0Ac"

typedef enum {
    Off_line,
    AC_Power,
    Battery_Power
} PowerSource;

typedef struct {
    unsigned int level;
    Boolean isCharging;
    
    double amperage;
    double voltage;
    double temperature;
    
    double cycles;
    
    double currentCapacity;
    double maxCapacity;
    double designCapacity;
    
    double timeToEmpty;
    double timeToFull;

    PowerSource powerSource;
    double ACWatts;
} PowerManagmentInformation;

kern_return_t SMCOpen(void);
kern_return_t SMCClose(void);

double GetTemperature(char* key);
float GetFanRPM(char* key);
//PowerManagmentInformation *GetPowerInfo(void);

// INTERNAL
#define KERNEL_INDEX_SMC 2

#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9
#define SMC_CMD_READ_PLIMIT 11
#define SMC_CMD_READ_VERS 12

#define DATATYPE_FPE2 "fpe2"
#define DATATYPE_UINT8 "ui8 "
#define DATATYPE_UINT16 "ui16"
#define DATATYPE_UINT32 "ui32"
#define DATATYPE_SP78 "sp78"

typedef char UInt32Char_t[5];
typedef char SMCBytes_t[32];

typedef struct {
    UInt32Char_t key;
    UInt32 dataSize;
    UInt32Char_t dataType;
    SMCBytes_t bytes;
} SMCVal_t;

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    UInt16 release;
} SMCKeyData_vers_t;

typedef struct {
    UInt16 version;
    UInt16 length;
    UInt32 cpuPLimit;
    UInt32 gpuPLimit;
    UInt32 memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    UInt32 key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    UInt32 data32;
    SMCBytes_t bytes;
} SMCKeyData_t;

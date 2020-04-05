//
//  SMC.h
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 03/04/2020.
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

typedef struct {
    double termal_zone_0;
    double termal_zone_1;
    double termal_ambient_0;
    double termal_ambient_1;
    double termal_heatpipe_0;
    double termal_heatpipe_1;
    double termal_heatpipe_2;
    double termal_heatpipe_3;
    
    double cpu_0_die;
    double cpu_0_diode;
    double cpu_0_heatsink;
    double cpu_0_proximity;
    double cpu_1_die;
    double cpu_1_diode;
    double cpu_1_heatsink;
    double cpu_1_proximity;
    
    double cpu_1;
    double cpu_2;
    double cpu_3;
    double cpu_4;
    double cpu_5;
    double cpu_6;
    double cpu_7;
    double cpu_8;
    
    double gpu_diode;
    double gpu_heatsink;
    double gpu_proximity;
    
    double mem_proximity;
    double mem_0;
    double mem_1;
    double mem_2;
    double mem_3;
    
    double pci_proximity;
    double pci_0;
    double pci_1;
    double pci_2;
    double pci_3;
    
    double sensor_mainboard;
    double sensor_powerboard;
    double sensor_battery;
    double sensor_airport;
    double sensor_lcd;
    double sensor_misc;
    double sensor_odd;
    
    double northbridge_die;
    double northbridge_proximity;
    
    double hdd_0;
    double hdd_1;
    double hdd_2;
    double hdd_3;
    
    double thunderbolt_0;
    double thunderbolt_1;
    double thunderbolt_2;
    double thunderbolt_3;
} Temperatures;

typedef struct {
} Voltages;

typedef struct {
} Powers;

kern_return_t SMCOpen(void);
kern_return_t SMCClose(void);

double GetTemperature(char* key);
float GetFanRPM(char* key);

void GetTemperatures(Temperatures* list);
void GetVoltages(Voltages* list);
void GetPowers(Powers* list);

int64_t GetCPUFrequency(void);

#define SMC_TEMP_AMBIENT_AIR_0 "TA0P"
#define SMC_TEMP_AMBIENT_AIR_1 "TA1P"
#define SMC_TEMP_HEATPIPE_0 "Th0H"
#define SMC_TEMP_HEATPIPE_1 "Th1H"
#define SMC_TEMP_HEATPIPE_2 "Th2H"
#define SMC_TEMP_HEATPIPE_3 "Th3H"
#define SMC_TEMP_TERMALZONE_0 "TZ0C"
#define SMC_TEMP_TERMALZONE_1 "TZ1C"

#define SMC_TEMP_CPU_0_DIE "TC0F"
#define SMC_TEMP_CPU_0_DIODE "TC0D"
#define SMC_TEMP_CPU_0_HEATSINK "TC0H"
#define SMC_TEMP_CPU_0_PROXIMITY "TC0P"
#define SMC_TEMP_CPU_1_DIE "TCAD"
#define SMC_TEMP_CPU_1_DIODE "TC1D"
#define SMC_TEMP_CPU_1_HEATSINK "TC1H"
#define SMC_TEMP_CPU_1_PROXIMITY "TC1P"

#define SMC_TEMP_CPU_CORE_1 "TC1C"
#define SMC_TEMP_CPU_CORE_2 "TC2C"
#define SMC_TEMP_CPU_CORE_3 "TC3C"
#define SMC_TEMP_CPU_CORE_4 "TC4C"
#define SMC_TEMP_CPU_CORE_5 "TC5C"
#define SMC_TEMP_CPU_CORE_6 "TC6C"
#define SMC_TEMP_CPU_CORE_7 "TC7C"
#define SMC_TEMP_CPU_CORE_8 "TC8C"

#define SMC_TEMP_GPU_0_DIODE "TG0D"
#define SMC_TEMP_GPU_0_HEATSINK "TG0H"
#define SMC_TEMP_GPU_0_PROXIMITY "TG0P"

#define SMC_TEMP_MEM_SLOTS "Ts0S"
#define SMC_TEMP_MEM_SLOT_0 "TM0S"
#define SMC_TEMP_MEM_SLOT_1 "TM1S"
#define SMC_TEMP_MEM_SLOT_2 "TM2S"
#define SMC_TEMP_MEM_SLOT_3 "TM3S"

#define SMC_TEMP_PCI_SLOTS "TS0C"
#define SMC_TEMP_PCI_SLOT_0 "TA0S"
#define SMC_TEMP_PCI_SLOT_1 "TA1S"
#define SMC_TEMP_PCI_SLOT_2 "TA2S"
#define SMC_TEMP_PCI_SLOT_3 "TA3S"

#define SMC_TEMP_MAINBOARD_PROXIMITY "Tm0P"
#define SMC_TEMP_POWERBOARD_PROXIMITY "Tp0P"
#define SMC_TEMP_BATTERY_PROXIMITY "TB1T"

#define SMC_TEMP_AIRPORT_PROXIMITY "TW0P"
#define SMC_TEMP_LCD_PROXIMITY "TL0P"
#define SMC_TEMP_ODD_PROXIMITY "TO0P"

#define SMC_TEMP_NORTHBRIDGE_DIE "TN0D"
#define SMC_TEMP_NORTHBRIDGE_PROXIMITY "TN0P"

#define SMC_TEMP_HDD_0 "TH0P"
#define SMC_TEMP_HDD_1 "TH1P"
#define SMC_TEMP_HDD_2 "TH2P"
#define SMC_TEMP_HDD_3 "TH3P"

#define SMC_TEMP_THUNDERBOLT_0 "TI0P"
#define SMC_TEMP_THUNDERBOLT_1 "TI1P"
#define SMC_TEMP_THUNDERBOLT_2 "TI2P"
#define SMC_TEMP_THUNDERBOLT_3 "TI3P"

#define SMC_VOLTAGE_CPU_VRM "VS0C"
#define SMC_VOLTAGE_CPU_CORE_0 "VC0C"
#define SMC_VOLTAGE_CPU_CORE_1 "VC1C"
#define SMC_VOLTAGE_CPU_CORE_2 "VC2C"
#define SMC_VOLTAGE_CPU_CORE_3 "VC3C"
#define SMC_VOLTAGE_CPU_CORE_4 "VC4C"
#define SMC_VOLTAGE_CPU_CORE_5 "VC5C"
#define SMC_VOLTAGE_CPU_CORE_6 "VC6C"
#define SMC_VOLTAGE_CPU_CORE_7 "VC7C"
#define SMC_VOLTAGE_CPU_CORE_8 "VC8C"

#define SMC_VOLTAGE_GPU "VG0C"
#define SMC_VOLTAGE_MEMORY "VM0R"
#define SMC_VOLTAGE_BATTERY "VBAT"
#define SMC_VOLTAGE_CMOS "Vb0R"

#define SMC_VOLTAGE_MAINBOARD "VD0R"
#define SMC_VOLTAGE_12V_RAIL "VP0R"
#define SMC_VOLTAGE_12V_VCC "Vp0C"
#define SMC_VOLTAGE_3V "VV2S"
#define SMC_VOLTAGE_3_3V "VR3R"
#define SMC_VOLTAGE_5V "VV1S"
#define SMC_VOLTAGE_12V "VV9S"
#define SMC_VOLTAGE_PCI_12V "VeES"

#define SMC_VOLTAGE_BATT0_VOLT "B0AV"
#define SMC_CURRENT_BATT0 "B0AC"

#define SMC_WATT_CPU_PACKAGE_CORE "PCPC"
#define SMC_WATT_CPU_PACKAGE_TOTAL "PCPT"
#define SMC_WATT_IGPU_PACKAGE "PCPG"

#define SMC_FREQUENCY_CPU_PACKAGE_MULTI "MPkC"
#define SMC_FREQUENCY_CPU_CORE_0_MULTI "MC0C"
#define SMC_FREQUENCY_CPU_CORE_1_MULTI "MC1C"
#define SMC_FREQUENCY_CPU_CORE_2_MULTI "MC2C"
#define SMC_FREQUENCY_CPU_CORE_3_MULTI "MC3C"
#define SMC_FREQUENCY_CPU_CORE_4_MULTI "MC4C"
#define SMC_FREQUENCY_CPU_CORE_5_MULTI "MC5C"
#define SMC_FREQUENCY_CPU_CORE_6_MULTI "MC6C"
#define SMC_FREQUENCY_CPU_CORE_7_MULTI "MC7C"
#define SMC_FREQUENCY_CPU_CORE_0 "FRC0"
#define SMC_FREQUENCY_CPU_CORE_1 "FRC1"
#define SMC_FREQUENCY_CPU_CORE_2 "FRC2"
#define SMC_FREQUENCY_CPU_CORE_3 "FRC3"
#define SMC_FREQUENCY_CPU_CORE_4 "FRC4"
#define SMC_FREQUENCY_CPU_CORE_5 "FRC5"
#define SMC_FREQUENCY_CPU_CORE_6 "FRC6"
#define SMC_FREQUENCY_CPU_CORE_7 "FRC7"

#define SMC_FREQUENCY_GPU_0 "CG0C"
#define SMC_FREQUENCY_GPU_1 "CG1C"
#define SMC_FREQUENCY_GPU_0_SHADER "CG0S"
#define SMC_FREQUENCY_GPU_1_SHADER "CG1S"
#define SMC_FREQUENCY_GPU_0_MEMORY "CG1M"
#define SMC_FREQUENCY_GPU_1_MEMORY "CG0M"

#define SMC_FAN0_RPM "F0Ac"

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

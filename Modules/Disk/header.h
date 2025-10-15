//
//  Header.h
//  Disk
//
//  Created by Serhiy Mytrovtsiy on 25/03/2023
//  Using Swift 5.0
//  Running on macOS 13.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

#include <libproc.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>

struct nvme_smart_log {
    UInt8  critical_warning;
    UInt8  temperature[2];
    UInt8  avail_spare;
    UInt8  spare_thresh;
    UInt8  percent_used;
    UInt8  rsvd6[26];
    UInt8  data_units_read[16];
    UInt8  data_units_written[16];
    UInt8  host_reads[16];
    UInt8  host_writes[16];
    UInt8  ctrl_busy_time[16];
    UInt32 power_cycles[4];
    UInt32 power_on_hours[4];
    UInt32 unsafe_shutdowns[4];
    UInt32 media_errors[4];
    UInt16 temp_sensor[8];
    UInt32 thm_temp1_trans_count;
    UInt32 thm_temp2_trans_count;
    UInt32 thm_temp1_total_time;
    UInt32 thm_temp2_total_time;
    UInt8  rsvd232[280];
};

typedef struct IONVMeSMARTInterface {
    IUNKNOWN_C_GUTS;
    
    UInt16 version;
    UInt16 revision;
    
    IOReturn ( *SMARTReadData )( void *  interface, struct nvme_smart_log * NVMeSMARTData );
} IONVMeSMARTInterface;

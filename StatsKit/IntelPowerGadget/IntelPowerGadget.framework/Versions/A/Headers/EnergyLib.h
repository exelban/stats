/*
 * INTEL CONFIDENTIAL
 * Copyright 2011 - 2019 Intel Corporation All Rights Reserved.
 *
 * The source code contained or described herein and all documents related
 * to the source code ("Material") are owned by Intel Corporation or its
 * suppliers or licensors. Title to the Material remains with Intel Corporation
 * or its suppliers and licensors. The Material may contain trade secrets and
 * proprietary and confidential information of Intel Corporation and its
 * suppliers and licensors, and is protected by worldwide copyright and trade
 * secret laws and treaty provisions. No part of the Material may be used,
 * copied, reproduced, modified, published, uploaded, posted, transmitted,
 * distributed, or disclosed in any way without Intel's prior express written
 * permission.
 *
 * No license under any patent, copyright, trade secret or other intellectual
 * property right is granted to or conferred upon you by disclosure or delivery
 * of the Materials, either expressly, by implication, inducement, estoppel or
 * otherwise. Any license under such intellectual property rights must be
 * express and approved by Intel in writing.
 *
 * Unless otherwise agreed by Intel in writing, you may not remove or alter
 * this notice or any other notice embedded in Materials by Intel or Intel's
 * suppliers or licensors in any way.
 */

// WARNING: This API has been deprecated and will be removed in a future version, please upgrade to the new PowerGadgetLib.h API

#ifndef _EnergyLib
#define _EnergyLib

#ifdef __cplusplus
extern "C" {
#endif
    
    // macOS specific -- begin
#include <stdint.h>
#include <stdbool.h>
    
#define MSR_FUNC_FREQ  0
#define MSR_FUNC_POWER 1
#define MSR_FUNC_TEMP  2
#define MSR_FUNC_LIMIT 3
    
    // inform the library of the app's polling period; this doesn't change anything directly, but allows the library to discard unreasonable values
    bool SetPollingPeriod(double seconds);
    
    // set the sample-after-value for fixed counters
    bool SetSAV(uint64_t sav);
    
    // enable or disable use of the PMU
    bool UsePMU(bool flag);
    // macOS specific -- end
    
    // Initialize the library and the library calculates processor topology
    // It reads the MSRs from msrConfig.txt where the executable is.
    bool IntelEnergyLibInitialize(void);
    void IntelEnergyLibShutdown(void);
    bool ReservedFunc0(void *a, void *b, void *c);
    bool GetNumNodes(int *nNodes); // the macOS version only supports systems with a single CPU package
    bool GetNumMsrs(int *nMsr);
    bool GetMsrName(int iMsr, char *szName);
    bool GetMsrFunc(int iMsr, int *pFuncID);
    
    // GetBaseFrequency returns the CPU's base frequency
    // This returns 1 values: [0] base frequency in MHz
    bool GetBaseFrequency(int iNode, double *pBaseFrequency);

    // GetIAFrequency returns the CPU's instantaneous frequency
    // This returns 1 values: [0] CPU instantaneous frequency in MHz
    // Note that this returns the instantaneous value, not the value read via ReadSample
    bool GetIAFrequency(int iNode, int *freqInMHz);

    // GetGTFrequency returns the integrated GPU's instantaneous frequency
    // This returns 1 values: [0] integrated GPU instantaneous frequency in MHz
    bool GetGTFrequency(int *freq);

    // GetGpuMaxFrequency returns the integrated GPU's maximum frequency
    // This returns 1 values: [0] integrated GPU maximum frequency in MHz
    // Note that this function is not supported on macOS, and will always return 0
    bool GetGpuMaxFrequency(int *freq);

    // GetTDP returns the CPU's thermal design power (TDP)
    // This returns 1 values: [0] CPU TDP in Watts
    // Note that this returns the instantaneous value, not the value read via ReadSample
    bool GetTDP(int iNode, double *TDP);
    
    // GetMaxTemperature returns the CPU's maximum temperature
    // This returns 1 values: [0] CPU maximum temperature in degrees C
    bool GetMaxTemperature(int iNode, int *degreeC);

    // GetThresholds returns the package thermal thresholds
    // This returns 2 values: [0] package threshold 1 in degrees C, [1] package threshold 2 in degrees C
    bool GetThresholds(int iNode, int *degree1C, int *degree2C);

    // GetTemperature returns the instantaneous package temperature
    // This returns 1 values: [0] instantaneous package temperature in degrees C
    // Note that this returns the instantaneous value, not the value read via ReadSample
    bool GetTemperature(int iNode, int *degreeC);
    
    // ReadSample reads a set of MSRs, the data can be accessed by calling GetPowerData
    // Note that GetPowerData requires at least 2 preceding calls to ReadSample, as these metrics require the delta between 2 samples to calculate their values
    bool ReadSample(void);

    // GetSysTime returns the wallclock time from the preceding call to ReadSample
    // this returns 2 values: [0] seconds since the epoch, [1] nanoseconds since the second
    bool GetSysTime(void *pSysTime);

    // GetTimeInterval returns the seconds between the 2 preceding calls to ReadSample
    // This returns 1 values: [0] time delta in seconds
    bool GetTimeInterval(double *pOffset);
    
    // GetPowerData calculates all the data converted from MSRs.
    // Note that GetPowerData requires at least 2 preceding calls to ReadSample, or will return false
    // If iMSR is an energy MSR, this returns 3 values: [0] power in Watts, [1] energy in Joules, [2] energy in mWh
    // if iMSR is a temperature MSR, this returns 2 values: [0] temperature in degrees C, [1] PROCHOT asserted
    // If iMSR is a frequency MSR, this returns 1 value: [0] frequency in MHz
    // If iMSR is a power limit MSR, this returns 1 value: [0] power limit in Watts
    bool GetPowerData(int iNode, int iMSR, double *pResult, int *nResult);
    
    // Start logging
    // Call ReadSample as many as you want between StartLog and StopLog
    // in order to get more than start and stop samples.
    bool StartLog(char *szFileName);
    
    // Stop logging and dump the log to the file.
    bool StopLog(void);
    
    //Returns true if GT is available, else returns false
    bool IsGTAvailable(void);
    
    // Returns true if we have platform energy MSRs available
    bool IsPlatformEnergyAvailable(void);
    
    // Returns true if we have platform energy MSRs available
    bool IsDramEnergyAvailable(void);
    
    // returns the GPU utilization if it exists
    bool GetGPUUtilization(float *util);
    
    // Calculate and retrieve CPU utilization
    bool GetCpuUtilization(int iNode, int *util);
    
#ifdef __cplusplus
}
#endif 

#endif

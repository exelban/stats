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

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/*@function PG_Initialize
* @abstract Initializes the Power Gadget library.
* @discussion Must be called to allocate resources and setup configuration. Any calls to the Power Gadget library before this will have undefined behavior.
* @result True on success, false on failure. */
bool PG_Initialize(void);

/*@function PG_Shutdown
* @abstract Shutdowns the Power Gadget library.
* @discussion Must be called to release resources. Any calls to the Power Gadget library after this will have undefined behavior.
* @result True on success, false on failure. */
bool PG_Shutdown(void);

/*@function PG_GetNumPackages
* @abstract Gets the number of Intel processor packages on this system.
* @param numPackages Pointer that will be updated with the number of Intel processor packages on this system.
* @result True on success, false on failure. */
bool PG_GetNumPackages(int* numPackages);

/*@function PG_GetNumCores
* @abstract Gets the number of CPU cores on the specified package.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param numCores Pointer that will be updated with the number of CPU cores on this system.
* @result True on success, false on failure. */
bool PG_GetNumCores(int iPackage, int* numCores);

/*@function PG_IsGTAvailable
* @abstract Checks if Intel integrated graphics (GT) is available on the specified package.
* @discussion If GT is not available on this package, calls to functions to access GT data (e.g. PGSample_GetGTFrequency) will return false.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param available Pointer that will be updated with indication of availability: true = available, false = not available.
* @result True on success, false on failure. */
bool PG_IsGTAvailable(int iPackage, bool* available);

/*@function PG_IsIAEnergyAvailable
* @abstract Checks if the CPU core energy plane is available on the specified package.
* @discussion The IA energy plane refers specifically to the CPU core(s) portion of the package, and is not available on all systems; if it is not available on this package, calls to functions to access IA power data (e.g. PGSample_GetIAPower) will return false.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param available Pointer that will be updated with indication of availability: true = available, false = not available.
* @result True on success, false on failure. */
bool PG_IsIAEnergyAvailable(int iPackage, bool* available);

/*@function PG_IsDRAMEnergyAvailable
* @abstract Checks if the DRAM energy plane is available on the specified package.
* @discussion DRAM energy is not available on all systems; if it is not available on this package, calls to functions to access DRAM power data (e.g. PGSample_GetDRAMPower) will return false.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param available Pointer that will be updated with indication of availability: true = available, false = not available.
* @result True on success, false on failure. */
bool PG_IsDRAMEnergyAvailable(int iPackage, bool* available);

/*@function PG_IsPlatformEnergyAvailable
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param available Pointer that will be updated with indication of availability: true = available, false = not available.
* @result True on success, false on failure. */
bool PG_IsPlatformEnergyAvailable(int iPackage, bool* available);

/*@function PG_UsePMU
* @abstract Enable or disable the use of the Performance Monitoring Unit (PMU) by the Power Gadget library.
* @discussion Enabling the use of the PMU by the Power Gadget Library allows for ReadSample to collect higher accuracy data with lower overhead; however, this also prevents the use of the PMU by other software. Disabling the use of the PMU by the Power Gadget library will enable compatibility with other software that uses the PMU.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param flag Set to true to enable the use of the PMU, and false to disable.
* @result True on success, false on failure. */
bool PG_UsePMU(int iPackage, bool flag);

/*@function PG_GetMaxTemperature
* @abstract Get the maximum junction temperature on the specific package.
* @discussion Maximum junction temperature is also referred to as the throttle temperature or PROCHOT temperature. Several registers report temperature as a delta from the maximum temperature, this is the value that should be used for those purposes.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param degreesC Pointer that will be updated with the maximum junction temperature in degrees Celcius.
* @result True on success, false on failure. */
bool PG_GetMaxTemperature(int iPackage, uint8_t* degreesC);

/*@function PG_GetIABaseFrequency
* @abstract Get the CPU base frequency on the specific package.
* @discussion CPU base frequency, also referred to as the advertised frequency, is the maximum non-turbo CPU frequency.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param freq Pointer that will be updated with the CPU base frequency in MHz.
* @result True on success, false on failure. */
bool PG_GetIABaseFrequency(int iPackage, double* freq);

/*@function PG_GetIAMaxFrequency
* @abstract Get the CPU maximum frequency on the specific package.
* @discussion CPU maximum frequency is the maximum 1 core turbo frequency.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param freq Pointer that will be updated with the CPU maximum frequency in MHz.
* @result True on success, false on failure. */
bool PG_GetIAMaxFrequency(int iPackage, double* freq);

/*@function PG_GetGTMaxFrequency
* @abstract Get the Intel integrated GPU maximum frequency on the specific package.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param freq Pointer that will be updated with the Intel integrated GPU maximum frequency in MHz.
* @result True on success, false on failure. */
bool PG_GetGTMaxFrequency(int iPackage, double* freq);

/*@function PG_GetTDP
* @abstract Get the package Thermal Design Point (TDP) on the specific package.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param TDP Pointer that will be updated with the TDP in Watts.
* @result True on success, false on failure. */
bool PG_GetTDP(int iPackage, double* TDP);

/*@type PGSampleID
* @discussion The Power Gadget library reads a sample of multiple metrics in batch when PG_ReadSample is called, and the sample is returned as a PGSampleID. Specific metric values can then be accessed from that sample by calling PGSample_Get<Metric> with the appropriate PGSampleID. Some metrics require 2 samples as they are based on the delta between samples, in which case 2 PGSampleID's must be provided, with sampleID1 preceding sampleID2 in time. */
typedef uint64_t PGSampleID;

/*@function PG_ReadSample
* @abstract Read all available Power Gadget metrics in a single batch call.
* @discussion The PGSampleID that is populated by this function can then be passed to any of the PGSample_Get<Metric> to access specific metrics. A call to PG_ReadSample results in the allocation of memory that must be released by the user by a matching call to PGSample_Release. Because some metrics require 2 samples, it is recommended to retain the 2 most recent samples, and to release all older samples.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param sampleID Pointer that will be updated with PGSampleID for this sample.
* @result True on success, false on failure. */
bool PG_ReadSample(int iPackage, PGSampleID* sampleID);

/*@function PGSample_Release
* @abstract Release a sample generated by a previous call to PG_ReadSample.
* @discussion Each sample generated by a call to PG_ReadSample must later be released by a matching call to PGSample_Release. PGSample_Release should be called when there is no longer a need to use this sample; because some metrics require 2 samples, it is recommended to retain the 2 most recent samples, and to release older samples. After release, any calls that use this sampleID will result in error.
* @param sampleID Sample to release, which was provided by a previous call to PG_ReadSample
* @result True on success, false on failure. */
bool PGSample_Release(PGSampleID sampleID);

/*@function PGSample_GetTime
* @abstract Get the system time for the specified sample.
* @discussion System time is seconds and nanoseconds since the epoch (1970/1/1).
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param seconds Pointer that will be updated with seconds since the epoch.
* @param nanoseconds Pointer that will be updated with nanoseconds since the value returned in "seconds".
* @result True on success, false on failure. */
bool PGSample_GetTime(PGSampleID sampleID, uint32_t* seconds, uint32_t* nanoseconds);

/*@function PGSample_GetTimeInterval
* @abstract Get the time, in seconds, between the 2 specified samples.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param seconds Pointer that will be updated with time, in seconds, between the 2 samples.
* @result True on success, false on failure. */
bool PGSample_GetTimeInterval(PGSampleID sampleID1, PGSampleID sampleID2, double* seconds);

/*@function PGSample_GetIAFrequency
* @abstract Get the CPU core frequency across all cores for the specified sample
* @discussion CPU frequency is constantly changing over time, and each CPU core can potentially run at different frequencies. The method used to measure CPU frequency can vary by CPU features and configuration, and may include mutliple measurements per core per sample. This function returns 3 values that represent CPU frequency across all cores on this package: (1) the mean frequency of all frequency measurements across all cores; (2) the minimum frequency bin observed in any measurement on any core for this sample; (3) the maximum frequency bin observed in any measurement on any core for this sample.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param mean Pointer that will be updated with mean CPU frequency across all measurements in MHz.
* @param min Pointer that will be updated with minimum CPU frequency across any measurement in MHz.
* @param max Pointer that will be updated with maximum CPU frequency across any measurement in MHz.
* @result True on success, false on failure. */
bool PGSample_GetIAFrequency(PGSampleID sampleID1, PGSampleID sampleID2, double* mean, double* min, double* max);

/*@function PGSample_GetIACoreFrequency
* @abstract Get the CPU core frequency on the specified core for the specified sample.
* @discussion CPU frequency is constantly changing over time. The method used to measure CPU frequency can vary by CPU features and configuration, and may include mutliple measurements per sample. This function returns 3 values that represent CPU frequency on the specified package and core: (1) the mean frequency of all frequency measurements on the specified core; (2) the minimum frequency bin observed in any measurement for this sample on the specified core; (3) the maximum frequency bin observed in any measurement on for this sample the specified core.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param iCore Index of CPU core to query on the sampled package. Must be less than the value from PG_GetNumCores.
* @param mean Pointer that will be updated with mean CPU frequency across all measurements in MHz.
* @param min Pointer that will be updated with minimum CPU frequency across any measurement in MHz.
* @param max Pointer that will be updated with maximum CPU frequency across any measurement in MHz.
* @result True on success, false on failure, or if there is no data for the specified core in this sample. */
bool PGSample_GetIACoreFrequency(PGSampleID sampleID1, PGSampleID sampleID2, int iCore, double* mean, double* min, double* max);

/*@function PGSample_GetIAFrequencyRequest
* @abstract Get the CPU core frequency requested by the Operating System (OS) across all cores for the specified sample.
* @discussion CPU frequency requests are constantly changing over time, and a different frequency can potentially be requested for each CPU core. The method used to measure requested CPU frequency can vary by CPU features and configuration, and may include mutliple measurements per core per sample. This function returns 3 values that represent OS requested CPU frequency across all cores on this package: (1) the mean frequency request of all measurements across all cores; (2) the minimum frequency request observed in any measurement on any core for this sample; (3) the maximum frequency request observed in any measurement on any core for this sample.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param mean Pointer that will be updated with mean CPU frequency request across all measurements in MHz.
* @param min Pointer that will be updated with minimum CPU frequency request across any measurement in MHz.
* @param max Pointer that will be updated with maximum CPU frequency request across any measurement in MHz.
* @result True on success, false on failure. */
bool PGSample_GetIAFrequencyRequest(PGSampleID sampleID, double* mean, double* min, double* max);

/*@function PGSample_GetIACoreFrequencyRequest
* @abstract Get the CPU core frequency requested by the Operating System (OS) on the specified core for the specified sample.
* @discussion CPU frequency requests are constantly changing over time. The method used to measure requested CPU frequency can vary by CPU features and configuration, and may include mutliple measurements per sample. This function returns 3 values that represent OS requested CPU frequency on the specified package and core: (1) the mean frequency request of all measurements on the specified core; (2) the minimum frequency request observed in any measurement for this sample on the specified core; (3) the maximum frequency request observed in any measurement for this sample on the specified core.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param iCore Index of CPU core to query on the sampled package. Must be less than the value from PG_GetNumCores.
* @param mean Pointer that will be updated with mean CPU frequency request across all measurements in MHz.
* @param min Pointer that will be updated with minimum CPU frequency request across any measurement in MHz.
* @param max Pointer that will be updated with maximum CPU frequency request across any measurement in MHz.
* @result True on success, false on failure, or if there is no data for the specified core in this sample. */
bool PGSample_GetIACoreFrequencyRequest(PGSampleID sampleID, int iCore, double* mean, double* min, double* max);

/*@function PGSample_GetGTFrequency
* @abstract Get the Intel integrated GPU frequency for the specified sample.
* @discussion GPU frequency will be 0 when the Intel integrated GPU is inactive. This metric is only supported if PG_IsGTAvailable returns true.
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param freq Pointer that will be updated with Intel integrated GPU frequency.
* @result True on success, false on failure. */
bool PGSample_GetGTFrequency(PGSampleID sampleID, double* freq);

/*@function PGSample_GetGTFrequencyRequest
* @abstract Get the Intel integrated GPU frequency requested by the Operating System (OS) for the specified sample.
* @discussion This metric is only supported if PG_IsGTAvailable returns true.
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param freq Pointer that will be updated with Intel integrated GPU frequency requested by the OS in MHz.
* @result True on success, false on failure. */
bool PGSample_GetGTFrequencyRequest(PGSampleID sampleID, double* freq);

/*@function PGSample_GetPackagePower
* @abstract Get the package power and energy between the 2 specified samples.
* @discussion Provides power and energy measurements for the entire package. This provides the absolute energy consumed for the time between the 2 specified samples, and the mean power over the same time.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param powerWatts Pointer that will be updated with the mean power, in Watts, between the 2 samples.
* @param energyJoules Pointer that will be updated with the energy consumed, in Joules, between the 2 samples.
* @result True on success, false on failure. */
bool PGSample_GetPackagePower(PGSampleID sampleID1, PGSampleID sampleID2, double* powerWatts, double* energyJoules);

/*@function PGSample_GetIAPower
* @abstract Get the CPU power and energy between the 2 specified samples.
* @discussion Provides power and energy measurements for the CPU core(s) portion of the package. This provides the absolute energy consumed for the time between the 2 specified samples, and the mean power over the same time. This metric is only supported if PG_IsIAEnergyAvailable returns true.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param powerWatts Pointer that will be updated with the mean power, in Watts, between the 2 samples.
* @param energyJoules Pointer that will be updated with the energy consumed, in Joules, between the 2 samples.
* @result True on success, false on failure. */
bool PGSample_GetIAPower(PGSampleID sampleID1, PGSampleID sampleID2, double* powerWatts, double* energyJoules);

/*@function PGSample_GetDRAMPower
* @abstract Get the DRAM power and energy between the 2 specified samples.
* @discussion Provides power and energy measurements for the DRAM plane. This provides the absolute energy consumed for the time between the 2 specified samples, and the mean power over the same time. This metric is only supported if PG_IsDRAMEnergyAvailable returns true.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param powerWatts Pointer that will be updated with the mean power, in Watts, between the 2 samples.
* @param energyJoules Pointer that will be updated with the energy consumed, in Joules, between the 2 samples.
* @result True on success, false on failure. */
bool PGSample_GetDRAMPower(PGSampleID sampleID1, PGSampleID sampleID2, double* powerWatts, double* energyJoules);

// ?
bool PGSample_GetPlatformPower(PGSampleID sampleID1, PGSampleID sampleID2, double* powerWatts, double* energyJoules);

/*@function PGSample_GetTDP
* @abstract Get the Thermal Design Point (TDP) for the specified sample.
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param TDP Pointer that will be updated with the TDP in Watts.
* @result True on success, false on failure. */
bool PGSample_GetTDP(PGSampleID sampleID, double* TDP);

/*@function PGSample_GetPackageTemperature
* @abstract Get the package temperature for the specified sample.
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param temp Pointer that will be updated with the temperature in degress Celcius.
* @result True on success, false on failure. */
bool PGSample_GetPackageTemperature(PGSampleID sampleID, double* temp);

/*@function PGSample_GetIATemperature
* @abstract Get the CPU core temperature across all cores for the specified sample.
* @discussion CPU temperature is constantly changing over time, and can vary by core. The method used to measure CPU temperature can vary by CPU features and configuration, and may include mutliple measurements per core per sample. This function returns 3 values that represent CPU temperature across all cores on this package: (1) the mean temperature of all measurements across all cores; (2) the minimum temperature observed in any measurement on any core for this sample; (3) the maximum temperature observed in any measurement on any core for this sample.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param mean Pointer that will be updated with mean CPU temperature across all measurements in degrees Celcius.
* @param min Pointer that will be updated with minimum CPU temperature across any measurement in degrees Celcius.
* @param max Pointer that will be updated with maximum CPU temperature across any measurement in degrees Celcius.
* @result True on success, false on failure. */
bool PGSample_GetIATemperature(PGSampleID sampleID, double* mean, double* min, double* max);

/*@function PGSample_GetIACoreTemperature
* @abstract Get the CPU core temperature on the specified core for the specified sample.
* @discussion CPU temperature is constantly changing over time. The method used to measure CPU temperature can vary by CPU features and configuration, and may include mutliple measurements per sample. This function returns 3 values that represent CPU temperature on the specified package and core: (1) the mean temperature of all measurements on the specified core; (2) the minimum temperature observed in any measurement for this sample on the specified core; (3) the maximum temperature observed in any measurement on for this sample the specified core.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param mean Pointer that will be updated with mean CPU temperature across all measurements in degrees Celcius.
* @param min Pointer that will be updated with minimum CPU temperature across any measurement in degrees Celcius.
* @param max Pointer that will be updated with maximum CPU temperature across any measurement in degrees Celcius.
* @result True on success, false on failure, or if there is no data for the specified core in this sample. */
bool PGSample_GetIACoreTemperature(PGSampleID sampleID, int iCore, double* mean, double* min, double* max);

/*@function PGSample_GetIAUtilization
* @abstract Get the CPU utilization across all cores between the 2 specified samples.
* @discussion Utilization is expressed as a percentage, where 100% represents all cores are active at all times.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param util Pointer that will be updated with the utilization across all cores in percentage.
* @result True on success, false on failure. */
bool PGSample_GetIAUtilization(PGSampleID sampleID1, PGSampleID sampleID2, double* util);

/*@function PGSample_GetIAUtilization
* @abstract Get the CPU utilization on the specified core between the 2 specified samples.
* @discussion Utilization is expressed as a percentage, where 100% represents that the specified core was active at all times.
* @param sampleID1 First sample, must precede the second sample in time.
* @param sampleID2 Second sample, must follow the first sample in time.
* @param iCore Index of CPU core to query on the sampled package. Must be less than the value from PG_GetNumCores.
* @param util Pointer that will be updated with the utilization on the specified core in percentage.
* @result True on success, false on failure, or if there is no data for the specified core in this sample. */
bool PGSample_GetIACoreUtilization(PGSampleID sampleID1, PGSampleID sampleID2, int iCore, double* util);

/*@function PGSample_GetGTUtilization
* @abstract Get the Intel integrated GPU utilization for the specified sample.
* @discussion Utilization is expressed as a percentage, where 100% represents the Intel integrated GPU is fully active at all times.
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @param util Pointer that will be updated with the utilization in percentage.
* @result True on success, false on failure. */
bool PGSample_GetGTUtilization(PGSampleID sampleID, double* util);

/*@type PGLogID
* @discussion PGLogID represents an single log file on a single package. */
typedef uint64_t PGLogID;

/*@function PG_StartLog
* @abstract Start logging on the specified package with the specified file name.
* @discussion This function allocates resources for logging. In order to minimized overhead while logging, the log will not be written to the specified file until logging is stopped by calling PGLog_Stop.
* @param iPackage Index of Intel processor package to query. Must be less than the value from PG_GetNumPackages.
* @param filename File path and name to write the log to.
* @param util Pointer that will be updated with the PGLogID.
* @result True on success, false on failure. */
bool PG_StartLog(int iPackage, char* fileName, PGLogID* logID);

/*@function PGLog_AddSample
* @abstract Add the specified sample to the specified log.
* @discussion Note that calls to PGLog_AddSample will not result in an immediate write to the log file, instead the entire log file will be written when logging is stopped. However, it is safe to release the sample after adding to the log but before the log has been stopped.
* @param logID Log that was provided by a previous call to PG_StartLog
* @param sampleID Sample that was provided by a previous call to PG_ReadSample
* @result True on success, false on failure. */
bool PGLog_AddSample(PGLogID logID, PGSampleID sampleID);

/*@function PGLog_Stop
* @abstract Stop the specified log and write the log to file.
* @param logID Log that was provided by a previous call to PG_StartLog
* @result True on success, false on failure. */
bool PGLog_Stop(PGLogID logID);

/*@function PGLog_Release
* @abstract Release a log created by a previous call to PG_StartLog
* @discussion Release resources allocated for this log. Any calls to PGLog_* functions with this logID after the log has been released will result in error.
* @param logID Log that was provided by a previous call to PG_StartLog
* @result True on success, false on failure. */
bool PGLog_Release(PGLogID logID);

#ifdef __cplusplus
}
#endif

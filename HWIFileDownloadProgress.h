/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloadProgress.h
 *
 */

/***************************************************************************
 
 Copyright (c) 2014-2018 Heiko Wichmann
 
 https://github.com/Heikowi/HWIFileDownload
 
 This software is provided 'as-is', without any expressed or implied warranty.
 In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented;
 you must not claim that you wrote the original software.
 If you use this software in a product, an acknowledgment
 in the product documentation would be appreciated
 but is not required.
 
 2. Altered source versions must be plainly marked as such,
 and must not be misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 ***************************************************************************/


#import <Foundation/Foundation.h>


/**
 HWIFileDownloadProgress is the download progress of a download item.
 */
@interface HWIFileDownloadProgress : NSObject

/**
 Designated initializer.
 @param aDownloadProgress Download progress with a range of 0.0 to 1.0.
 @param anExpectedFileSize Expected file size in bytes.
 @param aReceivedFileSize Received file size in bytes.
 @param anEstimatedRemainingTime Estimated remaining time in seconds.
 @param aBytesPerSecondSpeed Download speed in bytes per second.
 @param aProgress Download progress (NSProgress).
 @return Download progress item.
 */
- (nonnull instancetype)initWithDownloadProgress:(float)aDownloadProgress
                                expectedFileSize:(int64_t)anExpectedFileSize
                                receivedFileSize:(int64_t)aReceivedFileSize
                          estimatedRemainingTime:(NSTimeInterval)anEstimatedRemainingTime
                             bytesPerSecondSpeed:(NSUInteger)aBytesPerSecondSpeed
                                        progress:(nonnull NSProgress *)aProgress;
- (nonnull instancetype)init __attribute__((unavailable("use initWithDownloadProgress:expectedFileSize:receivedFileSize:estimatedRemainingTime:bytesPerSecondSpeed:progress:")));
+ (nonnull instancetype)new __attribute__((unavailable("use initWithDownloadProgress:expectedFileSize:receivedFileSize:estimatedRemainingTime:bytesPerSecondSpeed:progress:")));

/**
 Download progress with a range of 0.0 to 1.0.
 */
@property (nonatomic, assign, readonly) float downloadProgress;
/**
 Expected file size in bytes.
 */
@property (nonatomic, assign, readonly) int64_t expectedFileSize;
/**
 Received file size in bytes.
 */
@property (nonatomic, assign, readonly) int64_t receivedFileSize;
/**
 Estimated remaining time in seconds.
 */
@property (nonatomic, assign, readonly) NSTimeInterval estimatedRemainingTime;
/**
 Download speed in bytes per second.
 */
@property (nonatomic, assign, readonly) NSUInteger bytesPerSecondSpeed;
/**
 Can be used to store the last localized description of the native progress.
 @discussion You might want to store the last localized description before the native progress completes (e.g. with pause/cancel).
 */
@property (nonatomic, strong, readwrite, nullable) NSString *lastLocalizedDescription;
/**
 Can be used to store the last localized additional description of the native progress.
 @discussion You might want to store the last localized description before the native progress completes (e.g. with pause/cancel).
 */
@property (nonatomic, strong, readwrite, nullable) NSString *lastLocalizedAdditionalDescription;
/**
 Download progress (NSProgress).
 */
@property (nonatomic, strong, readonly, nonnull) NSProgress *nativeProgress;

@end

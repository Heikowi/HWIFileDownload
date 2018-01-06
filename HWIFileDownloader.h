/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloader.h
 *
 */

/***************************************************************************
 
 Copyright (c) 2014-2016 Heiko Wichmann
 
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

#import "HWIFileDownloadDelegate.h"
#import "HWIBackgroundSessionCompletionHandlerBlock.h"
#import "HWIFileDownloadProgress.h"


/**
 HWIFileDownloaderPauseResumeDataBlock is a block optionally called after cancelling a download.
 */
typedef void (^HWIFileDownloaderPauseResumeDataBlock)(NSData * _Nullable aResumeData);


/**
 HWIFileDownloader coordinates download activities.
 */
@interface HWIFileDownloader : NSObject

/**
 NSURLSession's configuration identifier
 */
@property (readonly, nonatomic, copy, nonnull) NSString *backgroundSessionIdentifier;

#pragma mark - Initialization


/**
 Secondary initializer.
 @param aDelegate Delegate for salient download events.
 @return HWIFileDownloader.
 */
- (nonnull instancetype)initWithDelegate:(nonnull NSObject<HWIFileDownloadDelegate>*)aDelegate;

/**
 Secondary initializer.
 @param aDelegate Delegate for salient download events.
 @param aMaxConcurrentFileDownloadsCount Maximum number of concurrent downloads. Default: no limit.
 @return HWIFileDownloader.
 */
- (nonnull instancetype)initWithDelegate:(nonnull NSObject<HWIFileDownloadDelegate>*)aDelegate maxConcurrentDownloads:(NSInteger)aMaxConcurrentFileDownloadsCount;

/**
 Designated initializer.
 @param aDelegate Delegate for salient download events.
 @param aMaxConcurrentFileDownloadsCount Maximum number of concurrent downloads. Default: no limit.
 @param aBackgroundSessionIdentifier NSURLSession's configuration identifier
 @return HWIFileDownloader.
 */
- (nonnull instancetype)initWithDelegate:(nonnull NSObject<HWIFileDownloadDelegate>*)aDelegate maxConcurrentDownloads:(NSInteger)aMaxConcurrentFileDownloadsCount backgroundSessionIdentifier:(nonnull NSString *)aBackgroundSessionIdentifier;
- (nonnull HWIFileDownloader*)init __attribute__((unavailable("use initWithDelegate:maxConcurrentDownloads: or initWithDelegate:")));
+ (nonnull HWIFileDownloader*)new __attribute__((unavailable("use initWithDelegate:maxConcurrentDownloads: or initWithDelegate:")));


/**
 Set up file downloader.
 @param aSetupCompletionBlock Completion block to be called asynchronously after setup is finished.
 */
- (void)setupWithCompletion:(nullable void (^)(void))aSetupCompletionBlock;


#pragma mark - Download


/**
 Starts a download.
 @param aDownloadIdentifier Download identifier of a download item.
 @param aRemoteURL Remote URL from where data should be downloaded.
 */
- (void)startDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                      fromRemoteURL:(nonnull NSURL *)aRemoteURL;

/**
 Starts a download.
 @param aDownloadIdentifier Download identifier of a download item.
 @param aResumeData Incomplete data from previous download with implicit remote source information.
 */
- (void)startDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                    usingResumeData:(nonnull NSData *)aResumeData;


/**
 Answers the question whether a download is currently running for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @return YES if a download is currently running for the download item, NO otherwise.
 @discussion Waiting downloads are included.
 */
- (BOOL)isDownloadingIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Answers the question whether a download is currently waiting for start.
 @param aDownloadIdentifier Download identifier of the download item.
 @return YES if a download is currently waiting for start, NO otherwise.
 @discussion Downloads might be queued and waiting for download. When a download is waiting, download of data from a remote host did not start yet.
 */
- (BOOL)isWaitingForDownloadOfIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Answers the question whether any download is currently running.
 @return YES if any download is currently running, NO otherwise.
 */
- (BOOL)hasActiveDownloads;


/**
 Cancels the download of a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 */
- (void)cancelDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier;


#pragma mark - BackgroundSessionCompletionHandler


/**
 Sets the completion handler for background session.
 @param aBackgroundSessionCompletionHandlerBlock Completion handler block.
 */
- (void)setBackgroundSessionCompletionHandlerBlock:(nullable HWIBackgroundSessionCompletionHandlerBlock)aBackgroundSessionCompletionHandlerBlock;


#pragma mark - Progress


/**
 Returns download progress information for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @return Download progress information.
 */
- (nullable HWIFileDownloadProgress *)downloadProgressForIdentifier:(nonnull NSString *)aDownloadIdentifier;


@end

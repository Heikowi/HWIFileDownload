/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloader.h
 *
 */

/***************************************************************************
 
 Copyright (c) 2014-2015 Heiko Wichmann
 
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
 HWIFileDownloaderCancelResumeDataBlock is a block optionally called after cancelling a download.
 */
typedef void (^HWIFileDownloaderCancelResumeDataBlock)(NSData *aResumeData);


/**
 HWIFileDownloader coordinates download activities.
 */
@interface HWIFileDownloader : NSObject


/**
 Secondary initializer.
 @param aDelegate Delegate for salient download events.
 @return HWIFileDownloader.
 */
- (instancetype)initWithDelegate:(NSObject<HWIFileDownloadDelegate>*)aDelegate;

/**
 Designated initializer.
 @param aDelegate Delegate for salient download events.
 @param aMaxConcurrentFileDownloadsCount Maximum number of concurrent downloads. Default: no limit.
 @return HWIFileDownloader.
 */
- (instancetype)initWithDelegate:(NSObject<HWIFileDownloadDelegate>*)aDelegate maxConcurrentDownloads:(NSInteger)aMaxConcurrentFileDownloadsCount;
- (instancetype)init __attribute__((unavailable("use initWithDelegate:maxConcurrentDownloads: or initWithDelegate:")));
+ (instancetype)new __attribute__((unavailable("use initWithDelegate:maxConcurrentDownloads: or initWithDelegate:")));


// download

/**
 Starts a download.
 @param aDownloadIdentifier Download identifier of a download item.
 @param aRemoteURL Remote URL from where data should be downloaded.
 */
- (void)startDownloadWithDownloadIdentifier:(NSString *)aDownloadIdentifier
                              fromRemoteURL:(NSURL *)aRemoteURL;

/**
 Starts a download.
 @param aDownloadIdentifier Download identifier of a download item.
 @param aResumeData Incomplete data from previous download with implicit remote source information.
 */
- (void)startDownloadWithDownloadIdentifier:(NSString *)aDownloadIdentifier
                            usingResumeData:(NSData *)aResumeData;


/**
 Answers the question whether a download is currently running for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @return YES if a download is currently running for the download item, NO otherwise.
 */
- (BOOL)isDownloadingIdentifier:(NSString *)aDownloadIdentifier;

/**
 Answers the question whether any download is currently running.
 @return YES if any download is currently running, NO otherwise.
 */
- (BOOL)hasActiveDownloads;


/**
 Cancels the download of a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @remarks Convenience method, calls cancelDownloadWithIdentifier:resumeDataBlock: with nil as resumeDataBlock.
 */
- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier;

/**
 Cancels the download of a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aResumeDataBlock Asynchronously called block with resume data.
 */
- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier resumeDataBlock:(HWIFileDownloaderCancelResumeDataBlock)aResumeDataBlock;


/**
 Sets the completion handler for background session.
 @param aBackgroundSessionCompletionHandlerBlock Completion handler block.
 */
- (void)setBackgroundSessionCompletionHandlerBlock:(HWIBackgroundSessionCompletionHandlerBlock)aBackgroundSessionCompletionHandlerBlock;


// progress


/**
 Returns download progress information for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @return Download progress information.
 */
- (HWIFileDownloadProgress *)downloadProgressForIdentifier:(NSString *)aDownloadIdentifier;


// download directory

/**
 Returns the default download directory.
 @return The default download directory.
 */
+ (NSURL *)fileDownloadDirectoryURL;


@end

/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloader.m
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


#import "HWIFileDownloader.h"
#import "HWIFileDownloadItem.h"


@interface HWIFileDownloader()<NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong, nullable) NSURLSession *backgroundSession;
@property (nonatomic, strong, nonnull) NSMutableDictionary *activeDownloadsDictionary;
@property (nonatomic, strong, nonnull) NSMutableArray *waitingDownloadsArray;
@property (nonatomic, weak, nullable) NSObject<HWIFileDownloadDelegate>* fileDownloadDelegate;
@property (nonatomic, copy, nullable) HWIBackgroundSessionCompletionHandlerBlock bgSessionCompletionHandlerBlock;
@property (nonatomic, assign) NSInteger maxConcurrentFileDownloadsCount;

@property (nonatomic, assign) NSUInteger highestDownloadID;
@property (nonatomic, strong, nullable) dispatch_queue_t downloadFileSerialWriterDispatchQueue;

@end


@implementation HWIFileDownloader


#pragma mark - Initialization


- (nullable instancetype)initWithDelegate:(nullable NSObject<HWIFileDownloadDelegate>*)aDelegate
{
    return [self initWithDelegate:aDelegate maxConcurrentDownloads:-1];
}


- (nullable instancetype)initWithDelegate:(nullable NSObject<HWIFileDownloadDelegate>*)aDelegate maxConcurrentDownloads:(NSInteger)aMaxConcurrentFileDownloadsCount
{
    self = [super init];
    if (self)
    {
        self.maxConcurrentFileDownloadsCount = -1;
        if (aMaxConcurrentFileDownloadsCount > 0)
        {
            self.maxConcurrentFileDownloadsCount = aMaxConcurrentFileDownloadsCount;
        }
    
        self.fileDownloadDelegate = aDelegate;
        self.activeDownloadsDictionary = [NSMutableDictionary dictionary];
        self.waitingDownloadsArray = [NSMutableArray array];
        self.highestDownloadID = 0;
        
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            NSString *aBackgroundDownloadSessionIdentifier = [NSString stringWithFormat:@"%@.HWIFileDownload", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
            NSURLSessionConfiguration *aBackgroundConfigObject = nil;
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1)
            {
                aBackgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:aBackgroundDownloadSessionIdentifier];
            }
            else
            {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                aBackgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration:aBackgroundDownloadSessionIdentifier];
#pragma GCC diagnostic pop
            }
            if ([self.fileDownloadDelegate respondsToSelector:@selector(requestTimeoutInterval)])
            {
                aBackgroundConfigObject.timeoutIntervalForRequest = [self.fileDownloadDelegate requestTimeoutInterval];
            }
            if ([self.fileDownloadDelegate respondsToSelector:@selector(resourceTimeoutInterval)])
            {
                aBackgroundConfigObject.timeoutIntervalForResource = [self.fileDownloadDelegate resourceTimeoutInterval];
            }
            self.backgroundSession = [NSURLSession sessionWithConfiguration:aBackgroundConfigObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
            
            [self.backgroundSession getTasksWithCompletionHandler:^(NSArray *aDataTasksArray, NSArray *anUploadTasksArray, NSArray *aDownloadTasksArray) {
                for (NSURLSessionDownloadTask *aDownloadTask in aDownloadTasksArray)
                {
                    NSString *aDownloadToken = [aDownloadTask.taskDescription copy];
                    if (aDownloadToken)
                    {
                        NSProgress *aRootProgress = nil;
                        if ([self.fileDownloadDelegate respondsToSelector:@selector(rootProgress)])
                        {
                            aRootProgress = [self.fileDownloadDelegate rootProgress];
                        }
                        aRootProgress.totalUnitCount++;
                        [aRootProgress becomeCurrentWithPendingUnitCount:1];
                        HWIFileDownloadItem *aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadToken
                                                                                            sessionDownloadTask:aDownloadTask
                                                                                                  urlConnection:nil];
                        [aRootProgress resignCurrent];
                        [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadTask.taskIdentifier)];
                        NSString *aDownloadToken = [aDownloadItem.downloadToken copy];
                        [aDownloadItem.progress setPausingHandler:^{
                            [self pauseDownloadAndPostResumeDataWithIdentifier:aDownloadToken];
                        }];
                        [aDownloadItem.progress setCancellationHandler:^{
                            [self cancelDownloadWithIdentifier:aDownloadToken];
                        }];
                        [self.fileDownloadDelegate incrementNetworkActivityIndicatorActivityCount];
                    }
                    else
                    {
                        NSLog(@"ERR: Missing task description (%s, %d)", __FILE__, __LINE__);
                    }
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:@"restartDownload" object:nil];
            }];
        }
        else
        {
            self.downloadFileSerialWriterDispatchQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.downloadFileWriter", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]] UTF8String], DISPATCH_QUEUE_SERIAL);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // restartDownload after init is complete
                [[NSNotificationCenter defaultCenter] postNotificationName:@"restartDownload" object:nil];
            });
        }
    }
    return self;
}


- (void)dealloc
{
    [self.backgroundSession finishTasksAndInvalidate];
}


#pragma mark - Download Start

- (void)startDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                              fromRemoteURL:(nonnull NSURL *)aRemoteURL
{
    [self startDownloadWithDownloadToken:aDownloadIdentifier fromRemoteURL:aRemoteURL usingResumeData:nil];
}


- (void)startDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                            usingResumeData:(nonnull NSData *)aResumeData
{
    [self startDownloadWithDownloadToken:aDownloadIdentifier fromRemoteURL:nil usingResumeData:aResumeData];
}


- (void)startDownloadWithDownloadToken:(nonnull NSString *)aDownloadToken
                         fromRemoteURL:(nullable NSURL *)aRemoteURL
                       usingResumeData:(nullable NSData *)aResumeData
{
    NSUInteger aDownloadID = 0;
    
    if ((self.maxConcurrentFileDownloadsCount == -1) || ((NSInteger)self.activeDownloadsDictionary.count < self.maxConcurrentFileDownloadsCount))
    {
        NSURLSessionDownloadTask *aDownloadTask = nil;
        NSURLConnection *aURLConnection = nil;
        
        HWIFileDownloadItem *aDownloadItem = nil;
        NSProgress *aRootProgress = nil;
        if ([self.fileDownloadDelegate respondsToSelector:@selector(rootProgress)])
        {
            aRootProgress = [self.fileDownloadDelegate rootProgress];
        }
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            if (aResumeData)
            {
                aDownloadTask = [self.backgroundSession downloadTaskWithResumeData:aResumeData];
            }
            else if (aRemoteURL)
            {
                aDownloadTask = [self.backgroundSession downloadTaskWithURL:aRemoteURL];
            }
            aDownloadID = aDownloadTask.taskIdentifier;
            aDownloadTask.taskDescription = aDownloadToken;
            
            aRootProgress.totalUnitCount++;
            [aRootProgress becomeCurrentWithPendingUnitCount:1];
            aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadToken
                                                           sessionDownloadTask:aDownloadTask
                                                                 urlConnection:nil];
            if (aResumeData)
            {
                aDownloadItem.resumedFileSizeInBytes = aResumeData.length;
                aDownloadItem.downloadStartDate = [NSDate date];
                aDownloadItem.bytesPerSecondSpeed = 0;
            }
            [aRootProgress resignCurrent];
        }
        else
        {
            aDownloadID = self.highestDownloadID++;
            NSTimeInterval aRequestTimeoutInterval = 60.0; // iOS default value
            if ([self.fileDownloadDelegate respondsToSelector:@selector(requestTimeoutInterval)])
            {
                aRequestTimeoutInterval = [self.fileDownloadDelegate requestTimeoutInterval];
            }
            NSURLRequest *aURLRequest = [[NSURLRequest alloc] initWithURL:aRemoteURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:aRequestTimeoutInterval];
            aURLConnection = [[NSURLConnection alloc] initWithRequest:aURLRequest delegate:self startImmediately:NO];
            
            aRootProgress.totalUnitCount++;
            [aRootProgress becomeCurrentWithPendingUnitCount:1];
            aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadToken
                                                           sessionDownloadTask:nil
                                                                 urlConnection:aURLConnection];
            [aRootProgress resignCurrent];
        }
        if (aDownloadItem)
        {
            [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadID)];
            NSString *aDownloadToken = [aDownloadItem.downloadToken copy];
            [aDownloadItem.progress setPausingHandler:^{
                [self pauseDownloadAndPostResumeDataWithIdentifier:aDownloadToken];
            }];
            [aDownloadItem.progress setCancellationHandler:^{
                [self cancelDownloadWithIdentifier:aDownloadToken];
            }];
            [self.fileDownloadDelegate incrementNetworkActivityIndicatorActivityCount];
            
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
            {
                [aDownloadTask resume];
            }
            else
            {
                [aURLConnection start];
            }
        }
        else
        {
            NSLog(@"ERR: No download item (%s, %d)", __FILE__, __LINE__);
        }
    }
    else
    {
        NSMutableDictionary *aWaitingDownloadDict = [NSMutableDictionary dictionary];
        [aWaitingDownloadDict setObject:aDownloadToken forKey:@"downloadToken"];
        if (aResumeData)
        {
            [aWaitingDownloadDict setObject:aResumeData forKey:@"resumeData"];
        }
        else if (aRemoteURL)
        {
            [aWaitingDownloadDict setObject:aRemoteURL forKey:@"remoteURL"];
        }
        [self.waitingDownloadsArray addObject:aWaitingDownloadDict];
    }
}


#pragma mark - Download Stop


- (void)pauseDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    [self pauseDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:nil];
}


- (void)pauseDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier resumeDataBlock:(nullable HWIFileDownloaderPauseResumeDataBlock)aResumeDataBlock
{
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        [self pauseDownloadWithDownloadID:aDownloadID resumeDataBlock:aResumeDataBlock];
    }
    else
    {
        NSInteger aFoundIndex = -1;
        for (NSUInteger anIndex = 0; anIndex < self.waitingDownloadsArray.count; anIndex++)
        {
            NSDictionary *aWaitingDownloadDict = self.waitingDownloadsArray[anIndex];
            if ([aWaitingDownloadDict[@"downloadToken"] isEqualToString:aDownloadIdentifier])
            {
                aFoundIndex = anIndex;
                break;
            }
            aFoundIndex++;
        }
        if (aFoundIndex > -1)
        {
            [self.waitingDownloadsArray removeObjectAtIndex:aFoundIndex];
        }
    }
}


- (void)pauseDownloadWithDownloadID:(NSUInteger)aDownloadID resumeDataBlock:(nullable HWIFileDownloaderPauseResumeDataBlock)aResumeDataBlock
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
    if (aDownloadItem)
    {
        aDownloadItem.status = HWIFileDownloadItemStatusPaused;
        aDownloadItem.progress.completedUnitCount = aDownloadItem.progress.totalUnitCount;
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            NSURLSessionDownloadTask *aDownloadTask = aDownloadItem.sessionDownloadTask;
            if (aDownloadTask)
            {
                if (aResumeDataBlock)
                {
                    [aDownloadTask cancelByProducingResumeData:^(NSData *aResumeData) {
                        aResumeDataBlock(aResumeData);
                    }];
                }
                else
                {
                    [aDownloadTask cancel];
                }
                // NSURLSessionTaskDelegate method is called
                // URLSession:task:didCompleteWithError:
            }
            else
            {
                NSLog(@"NSURLSessionDownloadTask cancelled (task not found): %@", aDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
        }
        else
        {
            NSURLConnection *aDownloadURLConnection = aDownloadItem.urlConnection;
            if (aDownloadURLConnection)
            {
                [self cancelURLConnection:aDownloadURLConnection downloadID:aDownloadID];
            }
            else
            {
                NSLog(@"NSURLConnection cancelled (connection not found): %@", aDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
        }
    }
}


- (void)pauseDownloadAndPostResumeDataWithIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    BOOL isDownloading = [self isDownloadingIdentifier:aDownloadIdentifier];
    if (isDownloading)
    {
        [self pauseDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:^(NSData *aResumeData) {
            if (aResumeData)
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"PausedDownloadResumeDataNotification"
                                                                    object:aResumeData
                                                                  userInfo:@{@"downloadIdentifier" : aDownloadIdentifier}];
            }
        }];
    }
}


- (void)cancelDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        [self cancelDownloadWithDownloadID:aDownloadID];
    }
    else
    {
        NSInteger aFoundIndex = -1;
        for (NSUInteger anIndex = 0; anIndex < self.waitingDownloadsArray.count; anIndex++)
        {
            NSDictionary *aWaitingDownloadDict = self.waitingDownloadsArray[anIndex];
            if ([aWaitingDownloadDict[@"downloadToken"] isEqualToString:aDownloadIdentifier])
            {
                aFoundIndex = anIndex;
                break;
            }
            aFoundIndex++;
        }
        if (aFoundIndex > -1)
        {
            [self.waitingDownloadsArray removeObjectAtIndex:aFoundIndex];
        }
    }
}


- (void)cancelDownloadWithDownloadID:(NSUInteger)aDownloadID
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
    if (aDownloadItem)
    {
        aDownloadItem.status = HWIFileDownloadItemStatusCancelled;
        aDownloadItem.progress.completedUnitCount = aDownloadItem.progress.totalUnitCount;
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            NSURLSessionDownloadTask *aDownloadTask = aDownloadItem.sessionDownloadTask;
            if (aDownloadTask)
            {
                [aDownloadTask cancel];
                // NSURLSessionTaskDelegate method is called
                // URLSession:task:didCompleteWithError:
            }
            else
            {
                NSLog(@"NSURLSessionDownloadTask cancelled (task not found): %@", aDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
        }
        else
        {
            NSURLConnection *aDownloadURLConnection = aDownloadItem.urlConnection;
            if (aDownloadURLConnection)
            {
                [self cancelURLConnection:aDownloadURLConnection downloadID:aDownloadID];
            }
            else
            {
                NSLog(@"NSURLConnection cancelled (connection not found): %@", aDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
        }
    }
}


- (void)cancelURLConnection:(NSURLConnection *)aDownloadURLConnection downloadID:(NSUInteger)aDownloadID
{
    [aDownloadURLConnection cancel];
    // delegate method is not necessarily called
    
    NSURL *aTempFileURL = [self tempLocalFileURLForDownloadFromURL:aDownloadURLConnection.originalRequest.URL];
    __weak HWIFileDownloader *weakSelf = self;
    dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
        HWIFileDownloader *strongSelf = weakSelf;
        NSError *aRemoveError = nil;
        [[NSFileManager defaultManager] removeItemAtURL:aTempFileURL error:&aRemoveError];
        if (aRemoveError)
        {
            NSLog(@"ERR: Unable to remove file at %@: %@ (%s, %d)", aTempFileURL, aRemoveError, __FILE__, __LINE__);
        }
        __weak HWIFileDownloader *anotherWeakSelf = strongSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            HWIFileDownloader *anotherStrongSelf = anotherWeakSelf;
            HWIFileDownloadItem *aFoundDownloadItem = [strongSelf.activeDownloadsDictionary objectForKey:@(aDownloadID)];
            if (aFoundDownloadItem)
            {
                NSLog(@"NSURLConnection cancelled: %@", aFoundDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [anotherStrongSelf handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
            }
        });
    });
}


#pragma mark - Download Status


- (BOOL)isDownloadingIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    BOOL isDownloading = NO;
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
        if (aDownloadItem && (aDownloadItem.status != HWIFileDownloadItemStatusCancelled) && (aDownloadItem.status != HWIFileDownloadItemStatusPaused) && (aDownloadItem.status != HWIFileDownloadItemStatusError))
        {
            isDownloading = YES;
        }
    }
    if (isDownloading == NO)
    {
        for (NSDictionary *aWaitingDownloadDict in self.waitingDownloadsArray)
        {
            if ([aWaitingDownloadDict[@"downloadToken"] isEqualToString:aDownloadIdentifier])
            {
                isDownloading = YES;
                break;
            }
        }
    }
    return isDownloading;
}


- (BOOL)isWaitingForDownloadOfIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    BOOL isWaitingForDownload = NO;
    for (NSDictionary *aWaitingDownloadDict in self.waitingDownloadsArray)
    {
        if ([aWaitingDownloadDict[@"downloadToken"] isEqualToString:aDownloadIdentifier])
        {
            isWaitingForDownload = YES;
            break;
        }
    }
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
        if (aDownloadItem && (aDownloadItem.status != HWIFileDownloadItemStatusCancelled) && (aDownloadItem.status != HWIFileDownloadItemStatusPaused) && (aDownloadItem.status != HWIFileDownloadItemStatusError) && (aDownloadItem.receivedFileSizeInBytes == 0))
        {
            isWaitingForDownload = YES;
        }
    }
    return isWaitingForDownload;
}


- (BOOL)hasActiveDownloads
{
    BOOL aHasActiveDownloadsFlag = NO;
    if ((self.activeDownloadsDictionary.count > 0) || (self.waitingDownloadsArray.count > 0))
    {
        aHasActiveDownloadsFlag = YES;
    }
    return aHasActiveDownloadsFlag;
}


- (nonnull NSURL *)tempLocalFileURLForDownloadFromURL:(nonnull NSURL *)aRemoteURL
{
    NSString *anOfflineDownloadDirectory = NSTemporaryDirectory();
    anOfflineDownloadDirectory = [anOfflineDownloadDirectory stringByAppendingPathComponent:@"file-download"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:anOfflineDownloadDirectory] == NO)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:anOfflineDownloadDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSURL *anOfflineDownloadDirectoryURL = [NSURL fileURLWithPath:anOfflineDownloadDirectory isDirectory:YES];
    [anOfflineDownloadDirectoryURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:NULL];
    
    NSString *aFilePathName = [anOfflineDownloadDirectory stringByAppendingPathComponent:[aRemoteURL lastPathComponent]];
    NSURL *aLocalFileURL = [NSURL fileURLWithPath:aFilePathName isDirectory:NO];
    return aLocalFileURL;
}


#pragma mark - BackgroundSessionCompletionHandler


- (void)setBackgroundSessionCompletionHandlerBlock:(nullable HWIBackgroundSessionCompletionHandlerBlock)aBackgroundSessionCompletionHandlerBlock
{
    self.bgSessionCompletionHandlerBlock = aBackgroundSessionCompletionHandlerBlock;
}


#pragma mark - NSURLSession
#pragma mark - NSURLSessionDownloadDelegate


- (void)URLSession:(nonnull NSURLSession *)aSession downloadTask:(nonnull NSURLSessionDownloadTask *)aDownloadTask didFinishDownloadingToURL:(nonnull NSURL *)aLocation
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.status = HWIFileDownloadItemStatusError;
        NSURL *aLocalFileURL = nil;
        if ([self.fileDownloadDelegate respondsToSelector:@selector(localFileURLForIdentifier:remoteURL:)])
        {
            NSURL *aRemoteURL = [[aDownloadTask.originalRequest URL] copy];
            if (aRemoteURL)
            {
                aLocalFileURL = [self.fileDownloadDelegate localFileURLForIdentifier:aDownloadItem.downloadToken remoteURL:aRemoteURL];
            }
            else
            {
                NSLog(@"ERR: Missing information: Remote URL (token: %@) (%s, %d)", aDownloadItem.downloadToken, __FILE__, __LINE__);
            }
        }
        else
        {
            aLocalFileURL = [HWIFileDownloader localFileURLForRemoteURL:[aDownloadTask.originalRequest URL]];
        }
        if (aLocalFileURL)
        {
            NSError *anError = nil;
            BOOL aSuccessFlag = [[NSFileManager defaultManager] moveItemAtURL:aLocation toURL:aLocalFileURL error:&anError];
            if (aSuccessFlag == NO)
            {
                NSError *aMoveError = anError;
                if (aMoveError == nil)
                {
                    aMoveError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotMoveFile userInfo:nil];
                }
                NSLog(@"ERR: Unable to move file from %@ to %@ (%@) (%s, %d)", aLocation, aLocalFileURL, aMoveError, __FILE__, __LINE__);
                [self handleDownloadWithError:anError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
            else
            {
                NSError *anError = nil;
                NSDictionary *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
                if (anError)
                {
                    NSLog(@"ERR: Error on getting file size for item at %@: %@ (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
                    [self handleDownloadWithError:anError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken resumeData:nil];
                }
                else
                {
                    unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
                    if (aFileSize == 0)
                    {
                        NSError *aFileSizeZeroError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorZeroByteResource userInfo:nil];
                        NSLog(@"ERR: Zero file size for item at %@: %@ (%s, %d)", aLocalFileURL, aFileSizeZeroError, __FILE__, __LINE__);
                        [self handleDownloadWithError:aFileSizeZeroError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken resumeData:nil];
                    }
                    else
                    {
                        if ([self.fileDownloadDelegate respondsToSelector:@selector(downloadIsValidForDownloadIdentifier:atLocalFileURL:)])
                        {
                            BOOL anIsValidDownloadFlag = [self.fileDownloadDelegate downloadIsValidForDownloadIdentifier:aDownloadItem.downloadToken atLocalFileURL:aLocalFileURL];
                            if (anIsValidDownloadFlag)
                            {
                                [self handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken];
                            }
                            else
                            {
                                NSLog(@"ERR: Download check failed for item at %@: %@ (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
                                NSError *aValidationError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
                                [self handleDownloadWithError:aValidationError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken resumeData:nil];
                            }
                        }
                        else
                        {
                            [self handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken];
                        }
                    }
                }
            }
        }
        else
        {
            NSLog(@"ERR: Missing information: Local file URL (token: %@) (%s, %d)", aDownloadItem.downloadToken, __FILE__, __LINE__);
            NSError *aValidationError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:nil];
            [self handleDownloadWithError:aValidationError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadItem.downloadToken resumeData:nil];
        }
    }
    else
    {
        NSLog(@"ERR: Missing download item for taskIdentifier: %@ (%s, %d)", @(aDownloadTask.taskIdentifier), __FILE__, __LINE__);
    }
}


- (void)URLSession:(nonnull NSURLSession *)aSession downloadTask:(nonnull NSURLSessionDownloadTask *)aDownloadTask didWriteData:(int64_t)aBytesWrittenCount totalBytesWritten:(int64_t)aTotalBytesWrittenCount totalBytesExpectedToWrite:(int64_t)aTotalBytesExpectedToWriteCount
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        if (aDownloadItem.downloadStartDate == nil)
        {
            aDownloadItem.downloadStartDate = [NSDate date];
        }
        aDownloadItem.receivedFileSizeInBytes = aTotalBytesWrittenCount;
        aDownloadItem.expectedFileSizeInBytes = aTotalBytesExpectedToWriteCount;
        if ([self.fileDownloadDelegate respondsToSelector:@selector(downloadProgressChangedForIdentifier:)])
        {
            NSString *aTaskDescription = [aDownloadTask.taskDescription copy];
            if (aTaskDescription)
            {
                [self.fileDownloadDelegate downloadProgressChangedForIdentifier:aTaskDescription];
            }
        }
    }
}


- (void)URLSession:(nonnull NSURLSession *)aSession downloadTask:(nonnull NSURLSessionDownloadTask *)aDownloadTask didResumeAtOffset:(int64_t)aFileOffset expectedTotalBytes:(int64_t)aTotalBytesExpectedCount
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.resumedFileSizeInBytes = aFileOffset;
        aDownloadItem.downloadStartDate = [NSDate date];
        aDownloadItem.bytesPerSecondSpeed = 0;
        NSLog(@"Download (id: %@) resumed (offset: %@ bytes, expected: %@ bytes", aDownloadTask.taskDescription, @(aFileOffset), @(aTotalBytesExpectedCount));
    }
}


#pragma mark - NSURLSessionTaskDelegate


- (void)URLSession:(nonnull NSURLSession *)aSession task:(nonnull NSURLSessionTask *)aDownloadTask didCompleteWithError:(nullable NSError *)anError
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.status = HWIFileDownloadItemStatusError;
        if (anError == nil)
        {
            anError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:nil];
        }
        if (([anError.domain isEqualToString:NSURLErrorDomain]) && (anError.code == NSURLErrorCancelled))
        {
            NSLog(@"Task cancelled: %@", aDownloadTask.taskDescription);
        }
        else
        {
            NSLog(@"Task didCompleteWithError: %@ (%@) (%s, %d)", anError, anError.userInfo, __FILE__, __LINE__);
        }
        
        NSData *aSessionDownloadTaskResumeData = [anError.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
        //NSString *aFailingURLStringErrorKeyString = [anError.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey];
        //NSNumber *aBackgroundTaskCancelledReasonKeyNumber = [anError.userInfo objectForKey:NSURLErrorBackgroundTaskCancelledReasonKey];
        
        [self handleDownloadWithError:anError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription resumeData:aSessionDownloadTaskResumeData];
    }
}


#pragma mark - NSURLSessionDelegate


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)aSession
{
    if (self.bgSessionCompletionHandlerBlock)
    {
        void (^completionHandler)() = self.bgSessionCompletionHandlerBlock;
        self.bgSessionCompletionHandlerBlock = nil;
        completionHandler();
    }
}


#pragma mark - NSURLConnection
#pragma mark - NSURLConnectionDataDelegate


- (void)connectionDidFinishLoading:(nonnull NSURLConnection *)aConnection
{
    NSNumber *aDownloadID = [self downloadIDForConnection:aConnection];
    if (aDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aDownloadID];
        
        if (aDownloadItem)
        {
            NSURL *aLocalFileURL = nil;
            if ([self.fileDownloadDelegate respondsToSelector:@selector(localFileURLForIdentifier:remoteURL:)])
            {
                aLocalFileURL = [self.fileDownloadDelegate localFileURLForIdentifier:aDownloadItem.downloadToken remoteURL:aConnection.originalRequest.URL];
            }
            else
            {
                aLocalFileURL = [HWIFileDownloader localFileURLForRemoteURL:aConnection.originalRequest.URL];
            }

            NSURL *aTempFileURL = [self tempLocalFileURLForDownloadFromURL:aConnection.originalRequest.URL];
            
            __weak HWIFileDownloader *weakSelf = self;
            dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
                
                HWIFileDownloader *strongSelf = weakSelf;
                
                if (aTempFileURL)
                {
                    NSError *anError = nil;
                    BOOL aMoveSuccessFlag = [[NSFileManager defaultManager] moveItemAtURL:aTempFileURL toURL:aLocalFileURL error:&anError];
                    if (aMoveSuccessFlag == NO)
                    {
                        NSLog(@"ERR: Unable to move file from %@ to %@ (%@) (%s, %d)", aTempFileURL, aLocalFileURL, anError, __FILE__, __LINE__);
                        __weak HWIFileDownloader *anotherWeakSelf = strongSelf;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            HWIFileDownloader *anotherStrongSelf = anotherWeakSelf;
                            HWIFileDownloadItem *aFoundDownloadItem = [anotherStrongSelf.activeDownloadsDictionary objectForKey:aDownloadID];
                            if (aFoundDownloadItem)
                            {
                                aDownloadItem.status = HWIFileDownloadItemStatusError;
                                [anotherStrongSelf handleDownloadWithError:anError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
                            }
                        });
                    }
                    else
                    {
                        __weak HWIFileDownloader *anotherWeakSelf = strongSelf;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            HWIFileDownloader *anotherStrongSelf = anotherWeakSelf;
                            
                            HWIFileDownloadItem *aFoundDownloadItem = [anotherStrongSelf.activeDownloadsDictionary objectForKey:aDownloadID];
                            if (aFoundDownloadItem == nil)
                            {
                                // download has been cancelled meanwhile
                                NSError *anError = nil;
                                BOOL aRemoveSuccessFlag = [[NSFileManager defaultManager] removeItemAtURL:aLocalFileURL error:&anError];
                                if (aRemoveSuccessFlag == NO)
                                {
                                    NSLog(@"ERR: Unable to remove file at %@ (%@) (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
                                }
                            }
                            else
                            {
                                
                                NSError *anError = nil;
                                NSDictionary *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
                                if (anError)
                                {
                                    NSLog(@"ERR: Error on getting file size for item at %@: %@ (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
                                    aDownloadItem.status = HWIFileDownloadItemStatusError;
                                    [anotherStrongSelf handleDownloadWithError:anError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
                                }
                                else
                                {
                                    unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
                                    if (aFileSize == 0)
                                    {
                                        NSError *aFileSizeZeroError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorZeroByteResource userInfo:nil];
                                        NSLog(@"ERR: Zero file size for item at %@: %@ (%s, %d)", aLocalFileURL, aFileSizeZeroError, __FILE__, __LINE__);
                                        aDownloadItem.status = HWIFileDownloadItemStatusError;
                                        [anotherStrongSelf handleDownloadWithError:aFileSizeZeroError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
                                    }
                                    else
                                    {
                                        if ([self.fileDownloadDelegate respondsToSelector:@selector(downloadIsValidForDownloadIdentifier:atLocalFileURL:)])
                                        {
                                            BOOL anIsValidDownloadFlag = [self.fileDownloadDelegate downloadIsValidForDownloadIdentifier:aFoundDownloadItem.downloadToken atLocalFileURL:aLocalFileURL];
                                            if (anIsValidDownloadFlag)
                                            {
                                                [anotherStrongSelf handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aDownloadItem.downloadToken];
                                            }
                                            else
                                            {
                                                NSLog(@"ERR: Download check failed for item at %@: %@ (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
                                                NSError *aValidationError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
                                                aDownloadItem.status = HWIFileDownloadItemStatusError;
                                                [anotherStrongSelf handleDownloadWithError:aValidationError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
                                            }
                                        }
                                        else
                                        {
                                            [anotherStrongSelf handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aDownloadItem.downloadToken];
                                        }
                                    }
                                }
                            }
                        });
                    }
                }
                
            });
        }
    }
}


- (void)connection:(nonnull NSURLConnection *)aConnection didReceiveResponse:(nonnull NSURLResponse *)aResponse
{
    NSNumber *aFoundDownloadID = [self downloadIDForConnection:aConnection];
    if (aFoundDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aFoundDownloadID];
        if (aDownloadItem)
        {
            if (aDownloadItem.downloadStartDate == nil)
            {
                aDownloadItem.downloadStartDate = [NSDate date];
            }
            long long anExpectedContentLength = [aResponse expectedContentLength];
            if (anExpectedContentLength > 0)
            {
                aDownloadItem.expectedFileSizeInBytes = anExpectedContentLength;
            }
        }
    }
}


- (void)connection:(nonnull NSURLConnection *)aConnection didReceiveData:(nonnull NSData *)aData
{
    NSNumber *aFoundDownloadID = [self downloadIDForConnection:aConnection];
    if (aFoundDownloadID)
    {
        NSURL *aTempFileURL = [self tempLocalFileURLForDownloadFromURL:aConnection.originalRequest.URL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[aTempFileURL path]] == NO)
        {
            dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
                [[NSFileManager defaultManager] createFileAtPath:aTempFileURL.path contents:nil attributes:nil];
            });
        }
        
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aFoundDownloadID];
        if (aDownloadItem)
        {
            if (aDownloadItem.downloadStartDate == nil)
            {
                aDownloadItem.downloadStartDate = [NSDate date];
            }
            int64_t anUntilNowReceivedContentSize = aDownloadItem.receivedFileSizeInBytes;
            int64_t aCompleteReceivedContentSize = anUntilNowReceivedContentSize + [aData length];
            aDownloadItem.receivedFileSizeInBytes = aCompleteReceivedContentSize;
            
            if ([self.fileDownloadDelegate respondsToSelector:@selector(downloadProgressChangedForIdentifier:)])
            {
                NSString *aDownloadIdentifier = [aDownloadItem.downloadToken copy];
                if (aDownloadIdentifier)
                {
                    [self.fileDownloadDelegate downloadProgressChangedForIdentifier:aDownloadItem.downloadToken];
                }
            }
            
            dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
                NSFileHandle *aFileHandle = [NSFileHandle fileHandleForWritingAtPath:aTempFileURL.path];
                if (!aFileHandle)
                {
                    NSLog(@"ERR: No file handle (%s, %d)", __FILE__, __LINE__);
                }
                else
                {
                    [aFileHandle seekToEndOfFile];
                    [aFileHandle writeData:aData];
                    [aFileHandle closeFile];
                }
            });
        }
    }
}


- (NSNumber *)downloadIDForConnection:(nonnull NSURLConnection *)aConnection
{
    NSNumber *aFoundDownloadID = nil;
    NSArray *aDownloadKeysArray = [self.activeDownloadsDictionary allKeys];
    for (NSNumber *aDownloadID in aDownloadKeysArray)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aDownloadID];
        if ([aDownloadItem.urlConnection isEqual:aConnection])
        {
            aFoundDownloadID = aDownloadID;
            break;
        }
    }
    return aFoundDownloadID;
}


#pragma mark - NSURLConnectionDelegate


- (void)connection:(nonnull NSURLConnection *)aConnection didFailWithError:(nonnull NSError *)anError
{
    NSNumber *aDownloadID = [self downloadIDForConnection:aConnection];
    if (aDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aDownloadID];
        if (aDownloadItem)
        {
            NSLog(@"ERR: NSURLConnection failed with error: %@ (%s, %d)", anError, __FILE__, __LINE__);
            aDownloadItem.status = HWIFileDownloadItemStatusError;
            [self handleDownloadWithError:anError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aDownloadItem.downloadToken resumeData:nil];
        }
    }
}


#pragma mark - HWIFileDownloadDelegate Defaults


+ (nullable NSURL *)localFileURLForRemoteURL:(nonnull NSURL *)aRemoteURL
{
    NSURL *aFileDownloadDirectoryURL = [HWIFileDownloader fileDownloadDirectoryURL];
    NSString *aLocalFileName = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], [[aRemoteURL lastPathComponent] pathExtension]];
    NSURL *aLocalFileURL = [aFileDownloadDirectoryURL URLByAppendingPathComponent:aLocalFileName];
    return aLocalFileURL;
}


+ (nullable NSURL *)fileDownloadDirectoryURL
{
    NSURL *aFileDownloadDirectoryURL = nil;
    NSError *anError = nil;
    NSString *aFileDownloadDirectory = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    aFileDownloadDirectory = [aFileDownloadDirectory stringByAppendingPathComponent:@"file-download"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:aFileDownloadDirectory] == NO)
    {
        BOOL aCreateDirectorySuccess = [[NSFileManager defaultManager] createDirectoryAtPath:aFileDownloadDirectory withIntermediateDirectories:YES attributes:nil error:&anError];
        if (aCreateDirectorySuccess == NO)
        {
            NSLog(@"ERR on create directory: %@ (%s, %d)", anError, __FUNCTION__, __LINE__);
        }
        else
        {
            NSURL *aFileDownloadDirectoryURL = [NSURL fileURLWithPath:aFileDownloadDirectory isDirectory:YES];
            BOOL aSetResourceValueSuccess = [aFileDownloadDirectoryURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&anError];
            if (aSetResourceValueSuccess == NO)
            {
                NSLog(@"ERR on set resource value: %@ (%s, %d)", anError, __FUNCTION__, __LINE__);
            }
        }
    }
    aFileDownloadDirectoryURL = [NSURL fileURLWithPath:aFileDownloadDirectory isDirectory:NO];
    return aFileDownloadDirectoryURL;
}


#pragma mark - Download Completion Handler


- (void)handleSuccessfulDownloadToLocalFileURL:(nonnull NSURL *)aLocalFileURL downloadID:(NSUInteger)aDownloadID downloadToken:(nonnull NSString *)aDownloadToken
{
    [self.fileDownloadDelegate downloadDidCompleteWithIdentifier:aDownloadToken
                                                    localFileURL:aLocalFileURL];
    [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
    [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    [self startNextWaitingDownload];
}


- (void)handleDownloadWithError:(nonnull NSError *)anError downloadID:(NSUInteger)aDownloadID downloadToken:(nullable NSString *)aDownloadToken resumeData:(nullable NSData *)aResumeData
{
    [self.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadToken
                                                      error:anError
                                                 resumeData:aResumeData];
    [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
    [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    [self startNextWaitingDownload];
}


#pragma mark - Download Progress


- (nullable HWIFileDownloadProgress *)downloadProgressForIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    HWIFileDownloadProgress *aDownloadProgress = nil;
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        aDownloadProgress = [self downloadProgressForDownloadID:aDownloadID];
    }
    return aDownloadProgress;
}


- (nullable HWIFileDownloadProgress *)downloadProgressForDownloadID:(NSUInteger)aDownloadID
{
    HWIFileDownloadProgress *aDownloadProgress = nil;
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
    if (aDownloadItem)
    {
        if ((aDownloadItem.status != HWIFileDownloadItemStatusCancelled) && (aDownloadItem.status != HWIFileDownloadItemStatusPaused) && (aDownloadItem.status != HWIFileDownloadItemStatusError))
        {
            float aDownloadProgressFloat = 0.0;
            if (aDownloadItem.expectedFileSizeInBytes > 0)
            {
                aDownloadProgressFloat = (float)aDownloadItem.receivedFileSizeInBytes / (float)aDownloadItem.expectedFileSizeInBytes;
            }
            NSDictionary *aRemainingTimeDict = [HWIFileDownloader remainingTimeAndBytesPerSecondForDownloadItem:aDownloadItem];
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
            {
                [aDownloadItem.progress setUserInfoObject:[aRemainingTimeDict objectForKey:@"remainingTime"] forKey:NSProgressEstimatedTimeRemainingKey];
                [aDownloadItem.progress setUserInfoObject:[aRemainingTimeDict objectForKey:@"bytesPerSecondSpeed"] forKey:NSProgressThroughputKey];
            }
            aDownloadProgress = [[HWIFileDownloadProgress alloc] initWithDownloadProgress:aDownloadProgressFloat
                                                                         expectedFileSize:aDownloadItem.expectedFileSizeInBytes
                                                                         receivedFileSize:aDownloadItem.receivedFileSizeInBytes
                                                                   estimatedRemainingTime:[[aRemainingTimeDict objectForKey:@"remainingTime"] doubleValue]
                                                                      bytesPerSecondSpeed:[[aRemainingTimeDict objectForKey:@"bytesPerSecondSpeed"] unsignedIntegerValue]
                                                                                 progress:aDownloadItem.progress];
        }
    }
    return aDownloadProgress;
}


#pragma mark - Utilities


- (NSInteger)downloadIDForActiveDownloadToken:(nonnull NSString *)aDownloadToken
{
    NSInteger aFoundDownloadID = -1;
    NSArray *aDownloadKeysArray = [self.activeDownloadsDictionary allKeys];
    for (NSNumber *aDownloadID in aDownloadKeysArray)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aDownloadID];
        if ([aDownloadItem.downloadToken isEqualToString:aDownloadToken])
        {
            aFoundDownloadID = [aDownloadID unsignedIntegerValue];
            break;
        }
    }
    return aFoundDownloadID;
}


- (void)startNextWaitingDownload
{
    if ((self.maxConcurrentFileDownloadsCount == -1) || ((NSInteger)self.activeDownloadsDictionary.count < self.maxConcurrentFileDownloadsCount))
    {
        if (self.waitingDownloadsArray.count > 0)
        {
            NSDictionary *aWaitingDownload = [self.waitingDownloadsArray objectAtIndex:0];
            NSString *aDownloadToken = aWaitingDownload[@"downloadToken"];
            NSURL *aRemoteURL = aWaitingDownload[@"remoteURL"];
            NSData *aResumeData = aWaitingDownload[@"resumeData"];
            [self.waitingDownloadsArray removeObjectAtIndex:0];
            [self startDownloadWithDownloadToken:aDownloadToken
                                   fromRemoteURL:aRemoteURL
                                 usingResumeData:aResumeData];
        }
    }
}


+ (nonnull NSDictionary *)remainingTimeAndBytesPerSecondForDownloadItem:(nonnull HWIFileDownloadItem *)aDownloadItem
{
    NSTimeInterval aRemainingTimeInterval = 0.0;
    NSUInteger aBytesPerSecondsSpeed = 0;
    if ((aDownloadItem.status != HWIFileDownloadItemStatusCancelled) && (aDownloadItem.status != HWIFileDownloadItemStatusPaused) && (aDownloadItem.status != HWIFileDownloadItemStatusError) && (aDownloadItem.receivedFileSizeInBytes > 0) && (aDownloadItem.expectedFileSizeInBytes > 0))
    {
        float aSmoothingFactor = 0.8; // range 0.0 ... 1.0 (determines the weight of the current speed calculation in relation to the stored past speed value)
        NSTimeInterval aDownloadDurationUntilNow = [[NSDate date] timeIntervalSinceDate:aDownloadItem.downloadStartDate];
        int64_t aDownloadedFileSize = aDownloadItem.receivedFileSizeInBytes - aDownloadItem.resumedFileSizeInBytes;
        float aCurrentBytesPerSecondSpeed = (aDownloadDurationUntilNow > 0.0) ? (aDownloadedFileSize / aDownloadDurationUntilNow) : 0.0;
        float aNewWeightedBytesPerSecondSpeed = 0.0;
        if (aDownloadItem.bytesPerSecondSpeed > 0.0)
        {
            aNewWeightedBytesPerSecondSpeed = (aSmoothingFactor * aCurrentBytesPerSecondSpeed) + ((1.0 - aSmoothingFactor) * (float)aDownloadItem.bytesPerSecondSpeed);
        }
        else
        {
            aNewWeightedBytesPerSecondSpeed = aCurrentBytesPerSecondSpeed;
        }
        if (aNewWeightedBytesPerSecondSpeed > 0.0)
        {
            aRemainingTimeInterval = (aDownloadItem.expectedFileSizeInBytes - aDownloadItem.resumedFileSizeInBytes - aDownloadedFileSize) / aNewWeightedBytesPerSecondSpeed;
        }
        aBytesPerSecondsSpeed = (NSUInteger)aNewWeightedBytesPerSecondSpeed;
        aDownloadItem.bytesPerSecondSpeed = aBytesPerSecondsSpeed;
    }
    return @{@"bytesPerSecondSpeed" : @(aBytesPerSecondsSpeed), @"remainingTime" : @(aRemainingTimeInterval)};
}


#pragma mark - Description


- (NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:self.activeDownloadsDictionary forKey:@"activeDownloadsDictionary"];
    [aDescriptionDict setObject:self.waitingDownloadsArray forKey:@"waitingDownloadsArray"];
    [aDescriptionDict setObject:@(self.maxConcurrentFileDownloadsCount) forKey:@"maxConcurrentFileDownloadsCount"];
    [aDescriptionDict setObject:@(self.highestDownloadID) forKey:@"highestDownloadID"];
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end


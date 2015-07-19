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

@property (nonatomic, strong) NSURLSession *backgroundSession;
@property (nonatomic, strong) NSMutableDictionary *activeDownloadsDictionary;
@property (nonatomic, strong) NSMutableArray *waitingDownloadsArray;
@property (nonatomic, weak) NSObject<HWIFileDownloadDelegate>* fileDownloadDelegate;
@property (nonatomic, copy) HWIBackgroundSessionCompletionHandlerBlock backgroundSessionCompletionHandlerBlock;
@property (nonatomic, assign) NSInteger maxConcurrentFileDownloadsCount;

@property (nonatomic, assign) NSUInteger highestDownloadID;
@property (nonatomic, strong) dispatch_queue_t downloadFileSerialWriterDispatchQueue;

@end


@implementation HWIFileDownloader


#pragma mark - Initialization


- (instancetype)initWithDelegate:(NSObject<HWIFileDownloadDelegate>*)aDelegate
{
    return [self initWithDelegate:aDelegate maxConcurrentDownloads:-1];
}


- (instancetype)initWithDelegate:(NSObject<HWIFileDownloadDelegate>*)aDelegate maxConcurrentDownloads:(NSInteger)aMaxConcurrentFileDownloadsCount
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
                    HWIFileDownloadItem *aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadTask.taskDescription
                                                                                        sessionDownloadTask:aDownloadTask
                                                                                              urlConnection:nil];
                    [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadTask.taskIdentifier)];
                    [self.fileDownloadDelegate incrementNetworkActivityIndicatorActivityCount];
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

- (void)startDownloadWithDownloadIdentifier:(NSString *)aDownloadIdentifier
                              fromRemoteURL:(NSURL *)aRemoteURL
{
    if (aDownloadIdentifier.length > 0 && aRemoteURL)
    {
        [self startDownloadWithDownloadToken:aDownloadIdentifier fromRemoteURL:aRemoteURL usingResumeData:nil];
    }
    else
    {
        NSLog(@"ERR: Missing arguments (%s, %d)", __FILE__, __LINE__);
    }
}


- (void)startDownloadWithDownloadIdentifier:(NSString *)aDownloadIdentifier
                            usingResumeData:(NSData *)aResumeData
{
    if (aDownloadIdentifier.length > 0 && aResumeData)
    {
        [self startDownloadWithDownloadToken:aDownloadIdentifier fromRemoteURL:nil usingResumeData:aResumeData];
    }
    else
    {
        NSLog(@"ERR: Missing arguments (%s, %d)", __FILE__, __LINE__);
    }
}


- (void)startDownloadWithDownloadToken:(NSString *)aDownloadToken
                         fromRemoteURL:(NSURL *)aRemoteURL
                       usingResumeData:(NSData *)aResumeData
{
    NSUInteger aDownloadID = 0;
    
    if ((self.maxConcurrentFileDownloadsCount == -1) || ((NSInteger)self.activeDownloadsDictionary.count < self.maxConcurrentFileDownloadsCount))
    {
        NSURLSessionDownloadTask *aDownloadTask = nil;
        NSURLConnection *aURLConnection = nil;
        
        HWIFileDownloadItem *aDownloadItem = nil;
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            if (aResumeData)
            {
                aDownloadTask = [self.backgroundSession downloadTaskWithResumeData:aResumeData];
            }
            else
            {
                aDownloadTask = [self.backgroundSession downloadTaskWithURL:aRemoteURL];
            }
            aDownloadID = aDownloadTask.taskIdentifier;
            aDownloadTask.taskDescription = aDownloadToken;
            aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadToken
                                                           sessionDownloadTask:aDownloadTask
                                                                 urlConnection:nil];
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
            aDownloadItem = [[HWIFileDownloadItem alloc] initWithDownloadToken:aDownloadToken
                                                           sessionDownloadTask:nil
                                                                 urlConnection:aURLConnection];
        }
        [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadID)];
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
        NSMutableDictionary *aWaitingDownloadDict = [NSMutableDictionary dictionary];
        [aWaitingDownloadDict setObject:aDownloadToken forKey:@"downloadToken"];
        if (aRemoteURL)
        {
            [aWaitingDownloadDict setObject:aRemoteURL forKey:@"remoteURL"];
        }
        if (aResumeData)
        {
            [aWaitingDownloadDict setObject:aResumeData forKey:@"resumeData"];
        }
        [self.waitingDownloadsArray addObject:aWaitingDownloadDict];
    }
}


#pragma mark - Download Stop


- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    [self cancelDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:nil];
}


- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier resumeDataBlock:(HWIFileDownloaderCancelResumeDataBlock)aResumeDataBlock
{
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        [self cancelDownloadWithDownloadID:aDownloadID resumeDataBlock:aResumeDataBlock];
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


- (void)cancelDownloadWithDownloadID:(NSUInteger)aDownloadID resumeDataBlock:(HWIFileDownloaderCancelResumeDataBlock)aResumeDataBlock
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
    if (aDownloadItem)
    {
        aDownloadItem.isCancelled = YES;
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
        }
        else
        {
            NSURLConnection *aDownloadConnection = aDownloadItem.urlConnection;
            if (aDownloadConnection)
            {
                [aDownloadConnection cancel];
                // delegate method is not necessarily called
                
                NSURL *aTempFileURL = [self tempLocalFileURLForDownloadFromURL:aDownloadItem.urlConnection.originalRequest.URL];
                __weak HWIFileDownloader *weakSelf = self;
                dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
                    HWIFileDownloader *strongSelf = weakSelf;
                    if (aResumeDataBlock)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            aResumeDataBlock(nil);
                        });
                    }
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
            else
            {
                NSLog(@"NSURLConnection cancelled (connection not found): %@", aDownloadItem.downloadToken);
                NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [self handleDownloadWithError:aCancelError downloadID:aDownloadID downloadToken:aDownloadItem.downloadToken resumeData:nil];
            }
        }
    }
}


#pragma mark - Download Status


- (BOOL)isDownloadingIdentifier:(NSString *)aDownloadIdentifier
{
    BOOL isDownloading = NO;
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
        if (aDownloadItem && (aDownloadItem.isCancelled == NO) && (aDownloadItem.isInvalid == NO))
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


- (BOOL)hasActiveDownloads
{
    BOOL aHasActiveDownloadsFlag = NO;
    if ((self.activeDownloadsDictionary.count > 0) || (self.waitingDownloadsArray.count > 0))
    {
        aHasActiveDownloadsFlag = YES;
    }
    return aHasActiveDownloadsFlag;
}


- (NSURL *)tempLocalFileURLForDownloadFromURL:(NSURL *)aRemoteURL
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
    NSURL *aLocalFileURL = [NSURL fileURLWithPath:aFilePathName];
    return aLocalFileURL;
}


#pragma mark - BackgroundSessionCompletionHandler


- (void)setBackgroundSessionCompletionHandlerBlock:(HWIBackgroundSessionCompletionHandlerBlock)aBackgroundSessionCompletionHandlerBlock
{
    _backgroundSessionCompletionHandlerBlock = aBackgroundSessionCompletionHandlerBlock;
}


#pragma mark - NSURLSession
#pragma mark - NSURLSessionDownloadDelegate


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didFinishDownloadingToURL:(NSURL *)aLocation
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.isInvalid = YES;
        NSURL *aLocalFileURL = nil;
        if ([self.fileDownloadDelegate respondsToSelector:@selector(localFileURLForIdentifier:remoteURL:)])
        {
            aLocalFileURL = [self.fileDownloadDelegate localFileURLForIdentifier:aDownloadTask.taskDescription remoteURL:[aDownloadTask.originalRequest URL]];
            if (aLocalFileURL == nil)
            {
                NSLog(@"ERR: No local file url (%s, %d)", __FILE__, __LINE__);
            }
        }
        else
        {
            aLocalFileURL = [HWIFileDownloader localFileURLForRemoteURL:[aDownloadTask.originalRequest URL]];
        }
        NSError *anError = nil;
        BOOL aSuccessFlag = [[NSFileManager defaultManager] moveItemAtURL:aLocation toURL:aLocalFileURL error: &anError];
        if (aSuccessFlag == NO)
        {
            NSLog(@"ERR: Unable to move file from %@ to %@ (%@) (%s)", aLocation, aLocalFileURL, anError, __PRETTY_FUNCTION__);
            [self handleDownloadWithError:anError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription resumeData:nil];
        }
        else
        {
            NSError *anError = nil;
            NSDictionary *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
            if (anError)
            {
                NSLog(@"ERR: Error on getting file size for item at %@: %@ (%s)", aLocalFileURL, anError, __PRETTY_FUNCTION__);
                [self handleDownloadWithError:anError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription resumeData:nil];
            }
            else
            {
                unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
                if (aFileSize == 0)
                {
                    NSError *aFileSizeZeroError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorZeroByteResource userInfo:nil];
                    NSLog(@"ERR: Zero file size for item at %@: %@ (%s)", aLocalFileURL, aFileSizeZeroError, __PRETTY_FUNCTION__);
                    [self handleDownloadWithError:aFileSizeZeroError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription resumeData:nil];
                }
                else
                {
                    if ([self.fileDownloadDelegate respondsToSelector:@selector(downloadIsValidForDownloadIdentifier:atLocalFileURL:)])
                    {
                        BOOL anIsValidDownloadFlag = [self.fileDownloadDelegate downloadIsValidForDownloadIdentifier:aDownloadTask.taskDescription atLocalFileURL:aLocalFileURL];
                        if (anIsValidDownloadFlag)
                        {
                            [self handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription];
                        }
                        else
                        {
                            NSLog(@"ERR: Download check failed for item at %@: %@ (%s)", aLocalFileURL, anError, __PRETTY_FUNCTION__);
                            NSError *aValidationError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
                            [self handleDownloadWithError:aValidationError downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription resumeData:nil];
                        }
                    }
                    else
                    {
                        [self handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription];
                    }
                }
            }
        }
    }
}


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didWriteData:(int64_t)aBytesWrittenCount totalBytesWritten:(int64_t)aTotalBytesWrittenCount totalBytesExpectedToWrite:(int64_t)aTotalBytesExpectedToWriteCount
{
    float aProgressRatio = 0.0;
    if (aTotalBytesExpectedToWriteCount > 0.0)
    {
        aProgressRatio = (float)aTotalBytesWrittenCount / (float)aTotalBytesExpectedToWriteCount;
    }
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
            [self.fileDownloadDelegate downloadProgressChangedForIdentifier:aDownloadTask.taskDescription];
        }
    }
}


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didResumeAtOffset:(int64_t)aFileOffset expectedTotalBytes:(int64_t)aTotalBytesExpectedCount
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    aDownloadItem.resumedFileSizeInBytes = aFileOffset;
    NSLog(@"Download (id: %@) resumed (offset: %@ bytes, expected: %@ bytes", aDownloadTask.taskDescription, @(aFileOffset), @(aTotalBytesExpectedCount));
}


#pragma mark - NSURLSessionTaskDelegate


- (void)URLSession:(NSURLSession *)aSession task:(NSURLSessionTask *)aDownloadTask didCompleteWithError:(NSError *)anError
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.isInvalid = YES;
        if (([anError.domain isEqualToString:NSURLErrorDomain]) && (anError.code == NSURLErrorCancelled))
        {
            NSLog(@"Task cancelled: %@", aDownloadTask.taskDescription);
        }
        else
        {
            NSLog(@"Task didCompleteWithError: %@ (%@), %s", anError, anError.userInfo, __PRETTY_FUNCTION__);
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
    if (self.backgroundSessionCompletionHandlerBlock)
    {
        void (^completionHandler)() = self.backgroundSessionCompletionHandlerBlock;
        self.backgroundSessionCompletionHandlerBlock = nil;
        completionHandler();
    }
}


#pragma mark - NSURLConnection
#pragma mark - NSURLConnectionDataDelegate


- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
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
                if (aLocalFileURL == nil)
                {
                    NSLog(@"ERR: No local file url (%s, %d)", __FILE__, __LINE__);
                }
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
                    NSFileHandle *aFileHandle = [NSFileHandle fileHandleForWritingAtPath:aTempFileURL.path];
                    if (!aFileHandle)
                    {
                        NSLog(@"ERR: No file handle (%s, %d)", __FILE__, __LINE__);
                    }
                    
                    NSError *anError = nil;
                    BOOL aMoveSuccessFlag = [[NSFileManager defaultManager] moveItemAtURL:aTempFileURL toURL:aLocalFileURL error:&anError];
                    if (aMoveSuccessFlag == NO)
                    {
                        NSLog(@"ERR: Unable to move file from %@ to %@ (%@) (%s)", aTempFileURL, aLocalFileURL, anError, __PRETTY_FUNCTION__);
                        __weak HWIFileDownloader *anotherWeakSelf = strongSelf;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            HWIFileDownloader *anotherStrongSelf = anotherWeakSelf;
                            HWIFileDownloadItem *aFoundDownloadItem = [anotherStrongSelf.activeDownloadsDictionary objectForKey:aDownloadID];
                            if (aFoundDownloadItem)
                            {
                                aDownloadItem.isInvalid = YES;
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
                                    NSLog(@"ERR: Unable to remove file at %@ (%@) (%s)", aLocalFileURL, anError, __PRETTY_FUNCTION__);
                                }
                            }
                            else
                            {
                                
                                NSError *anError = nil;
                                NSDictionary *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
                                if (anError)
                                {
                                    NSLog(@"ERR: Error on getting file size for item at %@: %@ (%s)", aLocalFileURL, anError, __PRETTY_FUNCTION__);
                                    aDownloadItem.isInvalid = YES;
                                    [anotherStrongSelf handleDownloadWithError:anError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aFoundDownloadItem.downloadToken resumeData:nil];
                                }
                                else
                                {
                                    unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
                                    if (aFileSize == 0)
                                    {
                                        NSError *aFileSizeZeroError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorZeroByteResource userInfo:nil];
                                        NSLog(@"ERR: Zero file size for item at %@: %@ (%s)", aLocalFileURL, aFileSizeZeroError, __PRETTY_FUNCTION__);
                                        aDownloadItem.isInvalid = YES;
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
                                                NSLog(@"ERR: Download check failed for item at %@: %@ (%s)", aLocalFileURL, anError, __PRETTY_FUNCTION__);
                                                NSError *aValidationError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotDecodeRawData userInfo:nil];
                                                aDownloadItem.isInvalid = YES;
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


- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse
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


- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)aData
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
                [self.fileDownloadDelegate downloadProgressChangedForIdentifier:aDownloadItem.downloadToken];
            }
            
            dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
                if (aTempFileURL)
                {
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
                }
            });
        }
    }
}


- (NSNumber *)downloadIDForConnection:(NSURLConnection *)aConnection
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


- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)anError
{
    NSNumber *aDownloadID = [self downloadIDForConnection:aConnection];
    if (aDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aDownloadID];
        if (aDownloadItem)
        {
            NSLog(@"ERR: NSURLConnection failed with error: %@ (%s, %d)", anError, __FILE__, __LINE__);
            aDownloadItem.isInvalid = YES;
            [self handleDownloadWithError:anError downloadID:[aDownloadID unsignedIntegerValue] downloadToken:aDownloadItem.downloadToken resumeData:nil];
        }
    }
}


#pragma mark - HWIFileDownloadDelegate Defaults


+ (NSURL *)localFileURLForRemoteURL:(NSURL *)aRemoteURL
{
    NSURL *aFileDownloadDirectoryURL = [HWIFileDownloader fileDownloadDirectoryURL];
    NSString *aLocalFileName = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], [[aRemoteURL lastPathComponent] pathExtension]];
    NSURL *aLocalFileURL = [aFileDownloadDirectoryURL URLByAppendingPathComponent:aLocalFileName];
    return aLocalFileURL;
}


+ (NSURL *)fileDownloadDirectoryURL
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
    aFileDownloadDirectoryURL = [NSURL fileURLWithPath:aFileDownloadDirectory];
    return aFileDownloadDirectoryURL;
}


#pragma mark - Download Completion Handler


- (void)handleSuccessfulDownloadToLocalFileURL:(NSURL *)aLocalFileURL downloadID:(NSUInteger)aDownloadID downloadToken:(NSString *)aDownloadToken
{
    [self.fileDownloadDelegate downloadDidCompleteWithIdentifier:aDownloadToken
                                                    localFileURL:aLocalFileURL];
    [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
    [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    [self startNextWaitingDownload];
}


- (void)handleDownloadWithError:(NSError *)anError downloadID:(NSUInteger)aDownloadID downloadToken:(NSString *)aDownloadToken resumeData:(NSData *)aResumeData
{
    [self.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadToken
                                                                   error:anError
                                                              resumeData:aResumeData];
    [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
    [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    [self startNextWaitingDownload];
}


#pragma mark - Download Progress


- (HWIFileDownloadProgress *)downloadProgressForIdentifier:(NSString *)aDownloadIdentifier
{
    HWIFileDownloadProgress *aDownloadProgress = nil;
    NSInteger aDownloadID = [self downloadIDForActiveDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        aDownloadProgress = [self downloadProgressForDownloadID:aDownloadID];
    }
    return aDownloadProgress;
}


- (HWIFileDownloadProgress *)downloadProgressForDownloadID:(NSUInteger)aDownloadID
{
    HWIFileDownloadProgress *aDownloadProgress = nil;
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
    if (aDownloadItem)
    {
        if ((aDownloadItem.isCancelled == NO) && (aDownloadItem.isInvalid == NO))
        {
            float aDownloadProgressFloat = 0.0;
            if (aDownloadItem.expectedFileSizeInBytes > 0)
            {
                aDownloadProgressFloat = (float)aDownloadItem.receivedFileSizeInBytes / (float)aDownloadItem.expectedFileSizeInBytes;
            }
            NSDictionary *aRemainingTimeDict = [HWIFileDownloader remainingTimeForDownloadItem:aDownloadItem];
            aDownloadProgress = [[HWIFileDownloadProgress alloc] initWithDownloadProgress:aDownloadProgressFloat
                                                                         expectedFileSize:aDownloadItem.expectedFileSizeInBytes
                                                                         receivedFileSize:aDownloadItem.receivedFileSizeInBytes
                                                                   estimatedRemainingTime:[[aRemainingTimeDict objectForKey:@"remainingTime"] doubleValue]
                                                                      bytesPerSecondSpeed:[[aRemainingTimeDict objectForKey:@"bytesPerSecondSpeed"] unsignedIntegerValue]];
        }
    }
    return aDownloadProgress;
}


#pragma mark - Utilities


- (NSInteger)downloadIDForActiveDownloadToken:(NSString *)aDownloadToken
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


+ (NSDictionary *)remainingTimeForDownloadItem:(HWIFileDownloadItem *)aDownloadItem
{
    NSTimeInterval aRemainingTimeInterval = 0.0;
    NSUInteger aBytesPerSecondsSpeed = 0;
    if ((aDownloadItem.isCancelled == NO) && (aDownloadItem.isInvalid == NO))
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
            aRemainingTimeInterval = (aDownloadItem.expectedFileSizeInBytes - aDownloadItem.receivedFileSizeInBytes) / aNewWeightedBytesPerSecondSpeed;
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


/*
 * Project: HWIFileDownload
 
 * Created by Heiko Wichmann (20140928)
 * File: HWIFileDownloader.m
 *
 */

/***************************************************************************
 
 Copyright (c) 2014 Heiko Wichmann
 
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
@property (nonatomic, weak) NSObject<HWIFileDownloadDelegate>* fileDownloadDelegate;
@property (nonatomic, copy) HWIBackgroundSessionCompletionHandlerBlock backgroundSessionCompletionHandlerBlock;
@property (nonatomic, assign) NSInteger maxConcurrentFileDownloadsCount;
@property (nonatomic, assign) NSUInteger currentFileDownloadsCount;
@property (nonatomic, strong) NSMutableArray *waitingDownloadsArray;

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
        self.currentFileDownloadsCount = 0;
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
            self.backgroundSession = [NSURLSession sessionWithConfiguration:aBackgroundConfigObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
            
            [self.backgroundSession getTasksWithCompletionHandler:^(NSArray *aDataTasksArray, NSArray *anUploadTasksArray, NSArray *aDownloadTasksArray) {
                for (NSURLSessionDownloadTask *aDownloadTask in aDownloadTasksArray)
                {
                    HWIFileDownloadItem *aDownloadItem = [[HWIFileDownloadItem alloc] init];
                    aDownloadItem.downloadToken = aDownloadTask.taskDescription;
                    aDownloadItem.sessionDownloadTask = aDownloadTask;
                    aDownloadItem.resumedFileSizeInBytes = 0;
                    aDownloadItem.isCancelled = NO;
                    [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadTask.taskIdentifier)];
                    self.currentFileDownloadsCount++;
                    [self.fileDownloadDelegate incrementNetworkActivityIndicatorActivityCount];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:@"restartDownload" object:nil];
            }];
        }
        else
        {
            self.downloadFileSerialWriterDispatchQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.downloadFileWriter", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]] UTF8String], DISPATCH_QUEUE_SERIAL);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // restartDownload after init is completed
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
    
    if ((self.maxConcurrentFileDownloadsCount == -1) || ((NSInteger)self.currentFileDownloadsCount < self.maxConcurrentFileDownloadsCount))
    {
        self.currentFileDownloadsCount++;
        
        NSURLSessionDownloadTask *aDownloadTask = nil;
        NSURLConnection *aURLConnection = nil;
        
        HWIFileDownloadItem *aDownloadItem = [[HWIFileDownloadItem alloc] init];
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
            aDownloadItem.downloadToken = aDownloadTask.taskDescription;
            aDownloadItem.sessionDownloadTask = aDownloadTask;
        }
        else
        {
            aDownloadID = self.highestDownloadID++;
            NSURLRequest *aURLRequest = [NSURLRequest requestWithURL:aRemoteURL];
            aURLConnection = [[NSURLConnection alloc] initWithRequest:aURLRequest delegate:self startImmediately:NO];
            aDownloadItem.downloadToken = aDownloadToken;
            aDownloadItem.urlConnection = aURLConnection;
        }
        aDownloadItem.receivedFileSizeInBytes = 0;
        aDownloadItem.expectedFileSizeInBytes = 0;
        aDownloadItem.resumedFileSizeInBytes = 0;
        aDownloadItem.isCancelled = NO;
        [self.activeDownloadsDictionary setObject:aDownloadItem forKey:@(aDownloadID)];
        
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            [aDownloadTask resume];
        }
        else
        {
            [aURLConnection start];
        }
        
        [self.fileDownloadDelegate incrementNetworkActivityIndicatorActivityCount];
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
    NSInteger aDownloadID = [self downloadIDForDownloadToken:aDownloadIdentifier];
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
            // no delegate method is called
            
            self.currentFileDownloadsCount--;
            HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
            NSURL *aTempFileURL = [self tempLocalFileURLForDownloadFromURL:aDownloadItem.urlConnection.originalRequest.URL];
            dispatch_async(self.downloadFileSerialWriterDispatchQueue, ^{
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
                __weak HWIFileDownloader* weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    HWIFileDownloader *strongSelf = weakSelf;
                    NSError *aCancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                    [strongSelf.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadItem.downloadToken
                                                                            error:aCancelError
                                                                       resumeData:nil];
                    [strongSelf.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
                    [strongSelf.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
                });
            });
        }
    }
    aDownloadItem.isCancelled = YES;
}


- (void)setBackgroundSessionCompletionHandlerBlock:(HWIBackgroundSessionCompletionHandlerBlock)aBackgroundSessionCompletionHandlerBlock
{
    _backgroundSessionCompletionHandlerBlock = aBackgroundSessionCompletionHandlerBlock;
}


#pragma mark - Download Status


- (BOOL)isDownloadingIdentifier:(NSString *)aDownloadIdentifier
{
    BOOL isDownloading = NO;
    NSInteger aDownloadID = [self downloadIDForDownloadToken:aDownloadIdentifier];
    if (aDownloadID > -1)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadID)];
        if (aDownloadItem && (aDownloadItem.isCancelled == NO))
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


#pragma mark - NSURLSession
#pragma mark - NSURLSessionDownloadDelegate


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didFinishDownloadingToURL:(NSURL *)aLocation
{
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
        [self.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadTask.taskDescription
                                                          error:anError
                                                     resumeData:nil];
        [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadTask.taskIdentifier)];
        [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    }
    else
    {
        [self handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:aDownloadTask.taskIdentifier downloadToken:aDownloadTask.taskDescription];
    }
    self.currentFileDownloadsCount--;
    [self startNextWaitingDownload];
}


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didWriteData:(int64_t)aBytesWrittenCount totalBytesWritten:(int64_t)aTotalBytesWrittenCount totalBytesExpectedToWrite:(int64_t)aTotalBytesExpectedToWriteCount
{
    float aProgressRatio = 0.0;
    if (aTotalBytesExpectedToWriteCount > 0.0)
    {
        aProgressRatio = (float)aTotalBytesWrittenCount / (float)aTotalBytesExpectedToWriteCount;
    }
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
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


- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)aDownloadTask didResumeAtOffset:(int64_t)aFileOffset expectedTotalBytes:(int64_t)aTotalBytesExpectedCount
{
    HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:@(aDownloadTask.taskIdentifier)];
    if (aDownloadItem)
    {
        aDownloadItem.resumedFileSizeInBytes = aFileOffset;
    }
    NSLog(@"Download (id: %@) resumed (offset: %@ bytes, expected: %@ bytes", aDownloadTask.taskDescription, @(aFileOffset), @(aTotalBytesExpectedCount));
}


#pragma mark - NSURLSessionTaskDelegate


- (void)URLSession:(NSURLSession *)aSession task:(NSURLSessionTask *)aTask didCompleteWithError:(NSError *)anError
{
    if (anError)
    {
        if (([anError.domain isEqualToString:NSURLErrorDomain]) && (anError.code == NSURLErrorCancelled))
        {
            NSLog(@"Task cancelled: %@", aTask.taskDescription);
        }
        else
        {
            NSLog(@"Task didCompleteWithError: %@ (%@), %s", anError, anError.userInfo, __PRETTY_FUNCTION__);
        }
        NSData *aSessionDownloadTaskResumeData = [anError.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
        //NSString *aFailingURLStringErrorKeyString = [anError.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey];
        //NSNumber *aBackgroundTaskCancelledReasonKeyNumber = [anError.userInfo objectForKey:NSURLErrorBackgroundTaskCancelledReasonKey];
        
        [self.fileDownloadDelegate downloadFailedWithIdentifier:aTask.taskDescription
                                                          error:anError
                                                     resumeData:aSessionDownloadTaskResumeData];
        [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    }
    [self.activeDownloadsDictionary removeObjectForKey:@(aTask.taskIdentifier)];
}


#pragma mark - NSURLSessionDelegate


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)aSession
{
    if (self.backgroundSessionCompletionHandlerBlock) {
        void (^completionHandler)() = self.backgroundSessionCompletionHandlerBlock;
        self.backgroundSessionCompletionHandlerBlock = nil;
        completionHandler();
    }
}


#pragma mark - NSURLConnection
#pragma mark - NSURLConnectionDataDelegate


- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    NSNumber *aFoundDownloadID = [self downloadIDForConnection:aConnection];
    if (aFoundDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aFoundDownloadID];
        
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
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"ERR: Unable to move file from %@ to %@ (%@) (%s)", aTempFileURL, aLocalFileURL, anError, __PRETTY_FUNCTION__);
                        [strongSelf.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadItem.downloadToken
                                                                                error:anError
                                                                           resumeData:nil];
                        [strongSelf.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
                        strongSelf.currentFileDownloadsCount--;
                        [strongSelf startNextWaitingDownload];
                    });
                }
                else
                {
                    __weak HWIFileDownloader *weakSelf = strongSelf;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        HWIFileDownloader *strongSelf = weakSelf;
                        
                        HWIFileDownloadItem *aDownloadItem = [strongSelf.activeDownloadsDictionary objectForKey:aFoundDownloadID];
                        if (aDownloadItem == nil)
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
                            [strongSelf handleSuccessfulDownloadToLocalFileURL:aLocalFileURL downloadID:[aFoundDownloadID unsignedIntegerValue] downloadToken:aDownloadItem.downloadToken];
                        }
                        [strongSelf.activeDownloadsDictionary removeObjectForKey:aFoundDownloadID];
                        strongSelf.currentFileDownloadsCount--;
                        [strongSelf startNextWaitingDownload];
                    });
                }
            }
            
        });
    }
    else
    {
        NSLog(@"ERR: No download id found (%s, %d)", __FILE__, __LINE__);
        [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
        self.currentFileDownloadsCount--;
        [self startNextWaitingDownload];
    }
}


- (void)connection:(NSURLConnection *)aConnection didReceiveResponse:(NSURLResponse *)aResponse
{
    NSNumber *aFoundDownloadID = [self downloadIDForConnection:aConnection];
    if (aFoundDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aFoundDownloadID];
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
    NSLog(@"ERR: NSURLConnection failed with error: %@ (%s, %d)", anError, __FILE__, __LINE__);
    
    NSNumber *aFoundDownloadID = [self downloadIDForConnection:aConnection];
    if (aFoundDownloadID)
    {
        HWIFileDownloadItem *aDownloadItem = [self.activeDownloadsDictionary objectForKey:aFoundDownloadID];
        [self.fileDownloadDelegate downloadFailedWithIdentifier:aDownloadItem.downloadToken
                                                          error:anError
                                                     resumeData:nil];
        [self.activeDownloadsDictionary removeObjectForKey:aFoundDownloadID];
        [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
    }
    self.currentFileDownloadsCount--;
    [self startNextWaitingDownload];
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


#pragma mark - Successful Download Handler


- (void)handleSuccessfulDownloadToLocalFileURL:(NSURL *)aLocalFileURL downloadID:(NSUInteger)aDownloadID downloadToken:(NSString *)aDownloadToken
{
    [self.fileDownloadDelegate downloadDidCompleteWithIdentifier:aDownloadToken
                                                    localFileURL:aLocalFileURL];
    
    [self.activeDownloadsDictionary removeObjectForKey:@(aDownloadID)];
    
    [self.fileDownloadDelegate decrementNetworkActivityIndicatorActivityCount];
}


#pragma mark - Download Progress


- (HWIFileDownloadProgress *)downloadProgressForIdentifier:(NSString *)aDownloadIdentifier
{
    HWIFileDownloadProgress *aDownloadProgress = nil;
    NSInteger aDownloadID = [self downloadIDForDownloadToken:aDownloadIdentifier];
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
        if (aDownloadItem.isCancelled == NO)
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


- (NSInteger)downloadIDForDownloadToken:(NSString *)aDownloadToken
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
    if ((self.maxConcurrentFileDownloadsCount == -1) || ((NSInteger)self.currentFileDownloadsCount < self.maxConcurrentFileDownloadsCount))
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
    NSTimeInterval aRemainingTime = 0.0;
    NSUInteger aBytesPerSecondsSpeed = 0;
    if (aDownloadItem.isCancelled == NO)
    {
        // speed => downloaded bytes in 1 second
        float aSmoothingFactor = 0.5; // range 0.0 ... 1.0
        NSTimeInterval aDownloadDurationUntilNow = [[NSDate date] timeIntervalSinceDate:aDownloadItem.downloadStartDate];
        int64_t aDownloadedFileSize = aDownloadItem.receivedFileSizeInBytes - aDownloadItem.resumedFileSizeInBytes;
        float aLastSpeed = (aDownloadDurationUntilNow > 0.0) ? (aDownloadedFileSize / aDownloadDurationUntilNow) : 0.0;
        float aNewAverageSpeed = aSmoothingFactor * aLastSpeed + (1.0 - aSmoothingFactor) * (float)aDownloadItem.bytesPerSecondSpeed;
        if (aNewAverageSpeed > 0)
        {
            aRemainingTime = (aDownloadItem.expectedFileSizeInBytes - aDownloadItem.receivedFileSizeInBytes) / aNewAverageSpeed;
        }
        aBytesPerSecondsSpeed = (NSUInteger)aNewAverageSpeed;
        aDownloadItem.bytesPerSecondSpeed = aBytesPerSecondsSpeed;
    }
    return @{@"bytesPerSecondSpeed" : @(aBytesPerSecondsSpeed), @"remainingTime" : @(aRemainingTime)};
}


#pragma mark - Description


- (NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:self.activeDownloadsDictionary forKey:@"activeDownloadsDictionary"];
    [aDescriptionDict setObject:self.waitingDownloadsArray forKey:@"waitingDownloadsArray"];
    [aDescriptionDict setObject:@(self.maxConcurrentFileDownloadsCount) forKey:@"maxConcurrentFileDownloadsCount"];
    [aDescriptionDict setObject:@(self.currentFileDownloadsCount) forKey:@"currentFileDownloadsCount"];
    [aDescriptionDict setObject:@(self.highestDownloadID) forKey:@"highestDownloadID"];
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end


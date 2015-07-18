/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloadItem.m
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


#import "HWIFileDownloadItem.h"


@interface HWIFileDownloadItem()
@property (nonatomic, strong, readwrite) NSString *downloadToken;
@property (nonatomic, strong, readwrite) NSURLSessionDownloadTask *sessionDownloadTask;
@property (nonatomic, strong, readwrite) NSURLConnection *urlConnection;
@end


@implementation HWIFileDownloadItem


#pragma mark - Initialization


- (instancetype)initWithDownloadToken:(NSString *)aDownloadToken
                  sessionDownloadTask:(NSURLSessionDownloadTask *)aSessionDownloadTask
                        urlConnection:(NSURLConnection *)aURLConnection
{
    self = [super init];
    if (self)
    {
        self.downloadToken = aDownloadToken;
        self.sessionDownloadTask = aSessionDownloadTask;
        self.urlConnection = aURLConnection;
        self.receivedFileSizeInBytes = 0;
        self.expectedFileSizeInBytes = 0;
        self.bytesPerSecondSpeed = 0;
        self.resumedFileSizeInBytes = 0;
        self.isCancelled = NO;
        self.isInvalid = NO;
    }
    return self;
}


#pragma mark - Description


- (NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:@(self.receivedFileSizeInBytes) forKey:@"receivedFileSizeInBytes"];
    [aDescriptionDict setObject:@(self.expectedFileSizeInBytes) forKey:@"expectedFileSizeInBytes"];
    [aDescriptionDict setObject:@(self.bytesPerSecondSpeed) forKey:@"bytesPerSecondSpeed"];
    [aDescriptionDict setObject:self.downloadToken forKey:@"downloadToken"];
    [aDescriptionDict setObject:@(self.isCancelled) forKey:@"isCancelled"];
    [aDescriptionDict setObject:@(self.isInvalid) forKey:@"isInvalid"];
    if (self.sessionDownloadTask)
    {
        [aDescriptionDict setObject:@(YES) forKey:@"hasSessionDownloadTask"];
    }
    if (self.urlConnection)
    {
        [aDescriptionDict setObject:@(YES) forKey:@"hasUrlConnection"];
    }
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end

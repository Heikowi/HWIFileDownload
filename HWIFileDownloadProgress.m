/*
 * Project: HWIFileDownload
 * Version: 1.0
 
 * Created by Heiko Wichmann (20141012)
 * File: HWIFileDownloadProgress.m
 *
 */

/***************************************************************************
 
 Copyright (c) 2014 Heiko Wichmann
 
 http://www.imagomat.de
 
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


#import "HWIFileDownloadProgress.h"

@interface HWIFileDownloadProgress()
@property (nonatomic, assign, readwrite) float downloadProgress;
@property (nonatomic, assign, readwrite) int64_t expectedFileSize;
@property (nonatomic, assign, readwrite) int64_t receivedFileSize;
@end


@implementation HWIFileDownloadProgress


#pragma mark - Initialization

- (instancetype)initWithDownloadProgress:(float)aDownloadProgress expectedFileSize:(int64_t)anExpectedFileSize receivedFileSize:(int64_t)aReceivedFileSize
{
    self = [super init];
    if (self)
    {
        self.downloadProgress = aDownloadProgress;
        self.expectedFileSize = anExpectedFileSize;
        self.receivedFileSize = aReceivedFileSize;
    }
    return self;
}


#pragma mark - Description


- (NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:@(self.downloadProgress) forKey:@"downloadProgress"];
    [aDescriptionDict setObject:@(self.expectedFileSize) forKey:@"expectedFileSize"];
    [aDescriptionDict setObject:@(self.receivedFileSize) forKey:@"receivedFileSize"];
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end

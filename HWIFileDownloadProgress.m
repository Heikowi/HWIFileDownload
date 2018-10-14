/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloadProgress.m
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


#import "HWIFileDownloadProgress.h"


@interface HWIFileDownloadProgress()<NSCoding>
@property (nonatomic, assign, readwrite) float downloadProgress;
@property (nonatomic, assign, readwrite) int64_t expectedFileSize;
@property (nonatomic, assign, readwrite) int64_t receivedFileSize;
@property (nonatomic, assign, readwrite) NSTimeInterval estimatedRemainingTime;
@property (nonatomic, assign, readwrite) NSUInteger bytesPerSecondSpeed;
@property (nonatomic, strong, readwrite, nonnull) NSProgress *nativeProgress;
@end


@implementation HWIFileDownloadProgress


#pragma mark - Initialization

- (nonnull instancetype)initWithDownloadProgress:(float)aDownloadProgress
                                expectedFileSize:(int64_t)anExpectedFileSize
                                receivedFileSize:(int64_t)aReceivedFileSize
                          estimatedRemainingTime:(NSTimeInterval)anEstimatedRemainingTime
                             bytesPerSecondSpeed:(NSUInteger)aBytesPerSecondSpeed
                                        progress:(nonnull NSProgress *)aProgress
{
    self = [super init];
    if (self)
    {
        self.downloadProgress = aDownloadProgress;
        self.expectedFileSize = anExpectedFileSize;
        self.receivedFileSize = aReceivedFileSize;
        self.estimatedRemainingTime = anEstimatedRemainingTime;
        self.bytesPerSecondSpeed = aBytesPerSecondSpeed;
        self.nativeProgress = aProgress;
    }
    return self;
}


#pragma mark - NSCoding


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:@(self.downloadProgress) forKey:@"downloadProgress"];
    [aCoder encodeObject:@(self.expectedFileSize) forKey:@"expectedFileSize"];
    [aCoder encodeObject:@(self.receivedFileSize) forKey:@"receivedFileSize"];
    [aCoder encodeObject:@(self.estimatedRemainingTime) forKey:@"estimatedRemainingTime"];
    [aCoder encodeObject:@(self.bytesPerSecondSpeed) forKey:@"bytesPerSecondSpeed"];
    if (self.lastLocalizedDescription)
    {
        [aCoder encodeObject:self.lastLocalizedDescription forKey:@"lastLocalizedDescription"];
    }
    if (self.lastLocalizedAdditionalDescription)
    {
        [aCoder encodeObject:self.lastLocalizedAdditionalDescription forKey:@"lastLocalizedAdditionalDescription"];
    }
}


- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super init];
    if (self)
    {
        self.downloadProgress = [[aCoder decodeObjectForKey:@"downloadProgress"] floatValue];
        self.expectedFileSize = (int64_t)[[aCoder decodeObjectForKey:@"expectedFileSize"] intValue];
        self.receivedFileSize = (int64_t)[[aCoder decodeObjectForKey:@"receivedFileSize"] intValue];
        self.estimatedRemainingTime = (NSTimeInterval)[[aCoder decodeObjectForKey:@"estimatedRemainingTime"] doubleValue];
        self.bytesPerSecondSpeed = (NSTimeInterval)[[aCoder decodeObjectForKey:@"bytesPerSecondSpeed"] unsignedIntegerValue];
        self.lastLocalizedDescription = [aCoder decodeObjectForKey:@"lastLocalizedDescription"];
        self.lastLocalizedAdditionalDescription = [aCoder decodeObjectForKey:@"lastLocalizedAdditionalDescription"];
    }
    return self;
}


#pragma mark - Description


- (nonnull NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:@(self.downloadProgress) forKey:@"downloadProgress"];
    [aDescriptionDict setObject:@(self.expectedFileSize) forKey:@"expectedFileSize"];
    [aDescriptionDict setObject:@(self.receivedFileSize) forKey:@"receivedFileSize"];
    [aDescriptionDict setObject:@(self.estimatedRemainingTime) forKey:@"estimatedRemainingTime"];
    [aDescriptionDict setObject:@(self.bytesPerSecondSpeed) forKey:@"bytesPerSecondSpeed"];
    [aDescriptionDict setObject:self.nativeProgress forKey:@"nativeProgress"];
    if (self.lastLocalizedDescription)
    {
        [aDescriptionDict setObject:self.lastLocalizedDescription forKey:@"lastLocalizedDescription"];
    }
    if (self.lastLocalizedAdditionalDescription)
    {
        [aDescriptionDict setObject:self.lastLocalizedAdditionalDescription forKey:@"lastLocalizedAdditionalDescription"];
    }
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end

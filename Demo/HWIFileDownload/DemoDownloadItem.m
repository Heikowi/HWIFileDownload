/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20160130)
 * File: DemoDownloadItem.m
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


#import "DemoDownloadItem.h"


@interface DemoDownloadItem()<NSCoding>
@property (nonatomic, strong, readwrite, nonnull) NSString *downloadIdentifier;
@property (nonatomic, strong, readwrite, nonnull) NSURL *remoteURL;
@end



@implementation DemoDownloadItem


- (nonnull instancetype)initWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                                         remoteURL:(nonnull NSURL *)aRemoteURL
{
    self = [super init];
    if (self)
    {
        self.downloadIdentifier = aDownloadIdentifier;
        self.remoteURL = aRemoteURL;
        self.status = DemoDownloadItemStatusNotStarted;
    }
    return self;
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.downloadIdentifier forKey:@"downloadIdentifier"];
    [aCoder encodeObject:self.remoteURL forKey:@"remoteURL"];
    [aCoder encodeObject:@(self.status) forKey:@"status"];
    if (self.resumeData.length > 0)
    {
        [aCoder encodeObject:self.resumeData forKey:@"resumeData"];
    }
    if (self.progress)
    {
        [aCoder encodeObject:self.progress forKey:@"progress"];
    }
    if (self.downloadError)
    {
        [aCoder encodeObject:self.downloadError forKey:@"downloadError"];
    }
    if (self.downloadErrorMessagesStack)
    {
        [aCoder encodeObject:self.downloadErrorMessagesStack forKey:@"downloadErrorMessagesStack"];
    }
    [aCoder encodeObject:@(self.lastHttpStatusCode) forKey:@"lastHttpStatusCode"];
}


- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super init];
    if (self)
    {
        self.downloadIdentifier = [aCoder decodeObjectForKey:@"downloadIdentifier"];
        self.remoteURL = [aCoder decodeObjectForKey:@"remoteURL"];
        self.status = [[aCoder decodeObjectForKey:@"status"] unsignedIntegerValue];
        self.resumeData = [aCoder decodeObjectForKey:@"resumeData"];
        self.progress = [aCoder decodeObjectForKey:@"progress"];
        self.downloadError = [aCoder decodeObjectForKey:@"downloadError"];
        self.downloadErrorMessagesStack = [aCoder decodeObjectForKey:@"downloadErrorMessagesStack"];
        self.lastHttpStatusCode = [[aCoder decodeObjectForKey:@"lastHttpStatusCode"] integerValue];
    }
    return self;
}


#pragma mark - Description


- (NSString *)description
{
    NSMutableDictionary *aDescriptionDict = [NSMutableDictionary dictionary];
    [aDescriptionDict setObject:self.downloadIdentifier forKey:@"downloadIdentifier"];
    [aDescriptionDict setObject:self.remoteURL forKey:@"remoteURL"];
    [aDescriptionDict setObject:@(self.status) forKey:@"status"];
    if (self.progress)
    {
        [aDescriptionDict setObject:self.progress forKey:@"progress"];
    }
    if (self.resumeData.length > 0)
    {
        [aDescriptionDict setObject:@"hasData" forKey:@"resumeData"];
    }
    
    NSString *aDescriptionString = [NSString stringWithFormat:@"%@", aDescriptionDict];
    
    return aDescriptionString;
}

@end

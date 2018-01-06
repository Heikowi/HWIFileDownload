/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20160130)
 * File: DemoDownloadItem.h
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

#import "DemoDownloadItemStatus.h"


@class HWIFileDownloadProgress;


@interface DemoDownloadItem : NSObject


- (nonnull instancetype)initWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                                         remoteURL:(nonnull NSURL *)aRemoteURL;


@property (nonatomic, strong, readonly, nonnull) NSString *downloadIdentifier;
@property (nonatomic, strong, readonly, nonnull) NSURL *remoteURL;

@property (nonatomic, strong, nullable) NSData *resumeData;
@property (nonatomic, assign) DemoDownloadItemStatus status;

@property (nonatomic, strong, nullable) HWIFileDownloadProgress *progress;

@property (nonatomic, strong, nullable) NSError *downloadError;
@property (nonatomic, strong, nullable) NSArray<NSString *> *downloadErrorMessagesStack;
@property (nonatomic, assign) NSInteger lastHttpStatusCode;

- (nonnull DemoDownloadItem *)init __attribute__((unavailable("use initWithDownloadIdentifier:remoteURL:")));
+ (nonnull DemoDownloadItem *)new __attribute__((unavailable("use initWithDownloadIdentifier:remoteURL:")));


@end

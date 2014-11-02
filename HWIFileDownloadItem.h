/*
 * Project: HWIFileDownload
 
 * Created by Heiko Wichmann (20140924)
 * File: HWIFileDownloadItem.h
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


#import <Foundation/Foundation.h>


/**
 HWIFileDownloadItem is used internally by HWIFileDownloader.
 */
@interface HWIFileDownloadItem : NSObject


@property (nonatomic, assign) float downloadProgress;
@property (nonatomic, assign) int64_t receivedFileSizeInBytes;
@property (nonatomic, assign) int64_t expectedFileSizeInBytes;
@property (nonatomic, strong) NSString *downloadToken;

@property (nonatomic, strong) NSURLSessionDownloadTask *sessionDownloadTask;

@property (nonatomic, strong) NSURLConnection *urlConnection;

@end

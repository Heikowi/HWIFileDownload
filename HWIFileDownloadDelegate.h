/*
 * Project: HWIFileDownload
 
 * Created by Heiko Wichmann (20140929)
 * File: HWIFileDownloadDelegate.h
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

/**
 HWIFileDownloadDelegate is a protocol for handling salient download events.
 */
@protocol HWIFileDownloadDelegate

/**
 Called on successful download of a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aLocalFileURL Local file URL of the downloaded item.
 */
- (void)downloadDidCompleteWithIdentifier:(NSString *)aDownloadIdentifier
                             localFileURL:(NSURL *)aLocalFileURL;

/**
 Called on a failed download.
 @param aDownloadIdentifier Download identifier of the download item.
 @param anError Download error.
 @param aResumeData Incompletely downloaded data that can be reused later if the download is started again.
 */
- (void)downloadFailedWithIdentifier:(NSString *)aDownloadIdentifier
                               error:(NSError *)anError
                          resumeData:(NSData *)aResumeData;

/**
 Called when the network activity indicator should be displayed because a download started.
 @discussion Use UIApplication's setNetworkActivityIndicatorVisible: to actually set the visibility of the network activity indicator.
 */
- (void)incrementNetworkActivityIndicatorActivityCount;

/**
 Called when the display of the network activity indicator might end (if the last running network activity stopped with this call).
 @discussion Use UIApplication's setNetworkActivityIndicatorVisible: to actually set the visibility of the network activity indicator.
 */
- (void)decrementNetworkActivityIndicatorActivityCount;


@optional


/**
 Optionally called when the progress changed for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @discussion To access the current download progress of a download item call HWIFileDownloader's downloadProgressForIdentifier:.
 */
- (void)downloadProgressChangedForIdentifier:(NSString *)aDownloadIdentifier;


/**
 Optionally called when the HWIFileDownloader needs to store the downloaded data for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aRemoteURL Remote URL from where the data has been downloaded.
 @return The local file URL where the downloaded data should be persistently stored in the file system.
 @discussion Although the download identifier is enough to identify a singular download item, the remote URL is passed here too for convenience as it might convey useful information for determining a local file URL.
 */
- (NSURL *)localFileURLForIdentifier:(NSString *)aDownloadIdentifier remoteURL:(NSURL *)aRemoteURL;


/**
 Optionally called to validate downloaded data.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aLocalFileURL Local file URL of the downloaded item.
 @return True if downloaded data in local file passed validation test.
 @discussion The download might finish successfully with an error string as downloaded data. This method can be used to check whether the downloaded data is the expected content and data type.
 */
- (BOOL)downloadIsValidForDownloadIdentifier:(NSString *)aDownloadIdentifier atLocalFileURL:(NSURL *)aLocalFileURL;


/**
 Optionally set timeout interval for a request with this return value.
 @return The timeout to use for the a request.
 @discussion The timeout fires if no data is transmitted for the given timeout value.
 */
- (NSTimeInterval)requestTimeoutInterval;


/**
 Optionally set timeout interval for downloading an individual item with this return value.
 @return The timeout to use for a download item.
 @discussion The timeout fires if a download item does not complete download during the time interval (only applies to NSURLSession).
 */
- (NSTimeInterval)resourceTimeoutInterval;


@end

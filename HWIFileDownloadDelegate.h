/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloadDelegate.h
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


@class NSURLSessionConfiguration;


/**
 HWIFileDownloadDelegate is a protocol for handling salient download events.
 */
@protocol HWIFileDownloadDelegate

/**
 Called on successful download of a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aLocalFileURL Local file URL of the downloaded item.
 */
- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                             localFileURL:(nonnull NSURL *)aLocalFileURL;

/**
 Called on a failed download.
 @param aDownloadIdentifier Download identifier of the download item.
 @param anError Download error.
 @param aHttpStatusCode HTTP status code of the http response.
 @param anErrorMessagesStack Array with error strings (latest error messages added on top of stack).
 @param aResumeData Incompletely downloaded data that can be reused later if the download is started again.
 */
- (void)downloadFailedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                               error:(nonnull NSError *)anError
                      httpStatusCode:(NSInteger)aHttpStatusCode
                  errorMessagesStack:(nullable NSArray *)anErrorMessagesStack
                          resumeData:(nullable NSData *)aResumeData;

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
 @discussion Use HWIFileDownloader's downloadProgressForIdentifier: to access the current download progress of a download item at any time.
 */
- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Optionally called on a paused download.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aResumeData Incompletely downloaded data that can be reused later if the download is started again.
 */
- (void)downloadPausedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                          resumeData:(nullable NSData *)aResumeData;


/**
 Optionally called on download resume.
 @param aDownloadIdentifier Download identifier of the download item.
 @discussion The delegate is responsible for using resume data if available.
 */
- (void)resumeDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Optionally called when the HWIFileDownloader needs to store the downloaded data for a download item.
 @param aDownloadIdentifier Download identifier of the download item.
 @param aRemoteURL Remote URL from where the data has been downloaded.
 @return The local file URL where the downloaded data should be persistently stored in the file system.
 @discussion Although the download identifier is enough to identify a singular download item, the remote URL is passed here too for convenience as it might convey useful information for determining a local file URL.
 */
- (nullable NSURL *)localFileURLForIdentifier:(nonnull NSString *)aDownloadIdentifier
                                    remoteURL:(nonnull NSURL *)aRemoteURL;


/**
 Optionally called to validate downloaded data.
 @param aLocalFileURL Local file URL of the downloaded item.
 @param aDownloadIdentifier Download identifier of the download item.
 @return True if downloaded data in local file passed validation test.
 @discussion The download might finish successfully with an error explanation string as downloaded data. This method can be used to check whether the downloaded data is the expected content and data type. If not implemented, every download is valid.
 */
- (BOOL)downloadAtLocalFileURL:(nonnull NSURL *)aLocalFileURL isValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Optionally called to validate http status code.
 @param httpStatusCode Http status code of the http response.
 @param aDownloadIdentifier Download identifier of the download item.
 @return True if http status code is valued as correct.
 @discussion Default implementation values http status code from 200 to 299 as correct.
 */
- (BOOL)httpStatusCode:(NSInteger)aHttpStatusCode isValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;


/**
 Optionally customize the background session configuration.
 @param aBackgroundSessionConfiguration Background session configuration to modify.
 @discussion With the background session configuration parameters can be adjusted (e.g. timeoutIntervalForRequest, timeoutIntervalForResource, HTTPAdditionalHeaders).
 */
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)aBackgroundSessionConfiguration;


/**
 Optionally create a custom url request for a remote url.
 @param aRemoteURL Remote URL from where the data should be downloaded.
 @discussion Create a custom url request if you want to customize cachePolicy or timeoutInterval. Used with NSURLConnection on iOS 6 only.
 */
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)aRemoteURL;


/**
 Optionally provide a progress object for tracking progress across individual downloads.
 @return Root progress object.
 @discussion NSProgress is set up in a hierarchy. Download progress of HWIFileDownloader items can be tracked individually and in total.
 */
- (nullable NSProgress *)rootProgress;


@end

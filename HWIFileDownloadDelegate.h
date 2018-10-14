/*
 * Project: HWIFileDownload
 
 * File: HWIFileDownloadDelegate.h
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


#import <Foundation/Foundation.h>


@class NSURLSessionConfiguration;


/**
 HWIFileDownloadDelegate is a protocol for handling salient download events.
 */
@protocol HWIFileDownloadDelegate

/**
 Called on successful download of a download item.
 @param identifier Download identifier of the download item.
 @param localFileURL Local file URL of the downloaded item.
 */
- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)identifier
                             localFileURL:(nonnull NSURL *)localFileURL;

/**
 Called on a failed download.
 @param identifier Download identifier of the download item.
 @param error Download error.
 @param httpStatusCode HTTP status code of the http response.
 @param errorMessagesStack Array with error strings (error messages inserted at first position of array).
 @param resumeData Incompletely downloaded data that can be reused later if the download is started again.
 */
- (void)downloadFailedWithIdentifier:(nonnull NSString *)identifier
                               error:(nonnull NSError *)error
                      httpStatusCode:(NSInteger)httpStatusCode
                  errorMessagesStack:(nullable NSArray<NSString *> *)errorMessagesStack
                          resumeData:(nullable NSData *)resumeData;

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
 @param identifier Download identifier of the download item.
 @discussion Use HWIFileDownloader's downloadProgressForIdentifier: to access the current download progress of a download item at any time.
 */
- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)identifier;


/**
 Optionally called on a paused download.
 @param identifier Download identifier of the download item.
 @param resumeData Incompletely downloaded data that can be reused later if the download is started again.
 @discussion Since iOS 9 resume data is managed by the system. For iOS 7 and iOS 8 resume data is passed with the parameter.
 */
- (void)downloadPausedWithIdentifier:(nonnull NSString *)identifier
                          resumeData:(nullable NSData *)resumeData;


/**
 Optionally called on download resume.
 @param identifier Download identifier of the download item.
 @discussion The delegate is responsible for using resume data if available.
 */
- (void)resumeDownloadWithIdentifier:(nonnull NSString *)identifier;


/**
 Optionally called when the HWIFileDownloader needs to store the downloaded data for a download item.
 @param identifier Download identifier of the download item.
 @param remoteURL Remote URL from where the data has been downloaded.
 @return The local file URL where the downloaded data should be persistently stored in the file system.
 @discussion Although the download identifier is enough to identify a singular download item, the remote URL is passed here too for convenience as it might convey useful information for determining a local file URL.
 */
- (nullable NSURL *)localFileURLForIdentifier:(nonnull NSString *)identifier
                                    remoteURL:(nonnull NSURL *)remoteURL;


/**
 Optionally called to validate downloaded data.
 @param localFileURL Local file URL of the downloaded item.
 @param downloadIdentifier Download identifier of the download item.
 @return True if downloaded data in local file passed validation test.
 @discussion The download might finish successfully with an error explanation string as downloaded data. This method can be used to check whether the downloaded data is the expected content and data type. If not implemented, every download is valid.
 */
- (BOOL)downloadAtLocalFileURL:(nonnull NSURL *)localFileURL isValidForDownloadIdentifier:(nonnull NSString *)downloadIdentifier;


/**
 Optionally called to validate http status code.
 @param httpStatusCode Http status code of the http response.
 @param downloadIdentifier Download identifier of the download item.
 @return True if http status code is valued as correct.
 @discussion Default implementation values http status code from 200 to 299 as correct.
 */
- (BOOL)httpStatusCode:(NSInteger)httpStatusCode isValidForDownloadIdentifier:(nonnull NSString *)downloadIdentifier;


/**
 Optionally customize the background session configuration.
 @param backgroundSessionConfiguration Background session configuration to modify.
 @discussion With the background session configuration parameters can be adjusted (e.g. timeoutIntervalForRequest, timeoutIntervalForResource, HTTPAdditionalHeaders).
 */
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)backgroundSessionConfiguration;


/**
 Optionally create a custom url request for a remote url.
 @param remoteURL Remote URL from where the data should be downloaded.
 @discussion Create a custom url request if you want to customize cachePolicy or timeoutInterval. Used with NSURLConnection on iOS 6 only.
 */
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)remoteURL;


/**
 Optionally called to receive NSURLCredential and NSURLSessionAuthChallengeDisposition for download identifier and authentication challenge.
 @param challenge Authentication challenge.
 @param downloadIdentifier Download identifier of the download item.
 @param completionHandler Completion handler to call with credential and disposition.
 @discussion This method is called if the file is protected on the server.
 */
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
               downloadIdentifier:(nonnull NSString *)downloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable credential, NSURLSessionAuthChallengeDisposition disposition))completionHandler;


/**
 Optionally provide a progress object for tracking progress across individual downloads.
 @return Root progress object.
 @discussion NSProgress is set up in a hierarchy. Download progress of HWIFileDownloader items can be tracked individually and in total.
 */
- (nullable NSProgress *)rootProgress;


@end

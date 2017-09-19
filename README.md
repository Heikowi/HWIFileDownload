# HWIFileDownload

HWIFileDownload simplifies file download with `NSURLSession` on iOS. Parallel file download can be controlled individually with all possible actions: start, cancel, pause, resume. Download progress is reported natively with `NSProgress` for every single file and in total.

## Features

Based on `NSURLSession` HWIFileDownload offers system background operation even when the app is not running. Downloads can be started individually, cancelled, paused and resumed. All possible states are supported: not started, waiting for download, started (downloading), completed, paused, cancelled, interrupted, error. When resuming cancelled downloads, previously downloaded data is reused. `NSProgress` is used for progress reporting and cancel/pause/resume event propagation.

HWIFileDownload is backwards compatible down to iOS 6 (where `NSURLConnection` is used instead of `NSURLSession`).

![Demo Download Screenshot](Demo/HWIFileDownload/DemoDownloadScreenshot.png?raw=true "Demo Download Screenshot")

## Installation

You can add HWIFileDownload to your project manually or with CocoaPods.

### Manual installation

HWIFileDownload consists of these files:

* HWIBackgroundSessionCompletionHandlerBlock.h
* HWIFileDownloadDelegate.h
* HWIFileDownloader.h
* HWIFileDownloader.m
* HWIFileDownloadItem.h
* HWIFileDownloadItem.m
* HWIFileDownloadProgress.h
* HWIFileDownloadProgress.m

All files need to be added to your app project.

### Installation with CocoaPods


To integrate HWIFileDownload into your Xcode project with [CocoaPods](http://cocoapods.org), specify it in your `Podfile`:

```ruby
pod 'HWIFileDownload'
```

Then run

```bash
$ pod install
```

### Using HWIFileDownload

To use HWIFileDownload after integration, import the header file ``HWIFileDownloader.h`` in the class files where you want to use it:

```objective-c
#import "HWIFileDownloader.h"
```


## Implementation

HWIFileDownload uses a __download identifier__ for starting a download, retrieving progress information, and for handling download completion. The __download identifier__ is a string that must be unique for each individual file download.

To start a download, the app client calls the method `startDownloadWithIdentifier:fromRemoteURL:` of the `HWIFileDownloader`.

### Download Store as Delegate

The app client must maintain a custom __download store__ to manage the downloads and the persistent store. The app __download store__ needs to implement the protocol `HWIFileDownloadDelegate` to be called on important download events.

The delegate is called on download completion. Additional mandatory calls control the visibility of the network activity indicator. Optionally the delegate can be called on download progress change for each download item. To control the local name and location of the downloaded file, the delegate can implement the method `localFileURLForIdentifier:remoteURL:`.

```objective-c
@protocol HWIFileDownloadDelegate
- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                             localFileURL:(nonnull NSURL *)aLocalFileURL;
- (void)downloadFailedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                               error:(nonnull NSError *)anError
                      httpStatusCode:(NSInteger)aHttpStatusCode
                  errorMessagesStack:(nullable NSArray<NSString *> *)anErrorMessagesStack
                          resumeData:(nullable NSData *)aResumeData;
- (void)incrementNetworkActivityIndicatorActivityCount;
- (void)decrementNetworkActivityIndicatorActivityCount;

@optional
- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (void)downloadPausedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                          resumeData:(nullable NSData *)aResumeData;
- (void)resumeDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (nullable NSURL *)localFileURLForIdentifier:(nonnull NSString *)aDownloadIdentifier
                                    remoteURL:(nonnull NSURL *)aRemoteURL;
- (BOOL)downloadAtLocalFileURL:(nonnull NSURL *)aLocalFileURL isValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (BOOL)httpStatusCode:(NSInteger)aHttpStatusCode isValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)aBackgroundSessionConfiguration;
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)aRemoteURL;
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)aChallenge
               downloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable aCredential, NSURLSessionAuthChallengeDisposition disposition))aCompletionHandler;
- (nullable NSProgress *)rootProgress;
@end
```

### Downloader

The app needs to hold an instance of the `HWIFileDownloader` that manages the download process. `HWIFileDownloader` provides methods for starting, querying and controlling individual download processes.

```objective-c
- (void)startDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                      fromRemoteURL:(nonnull NSURL *)aRemoteURL;
- (void)startDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                    usingResumeData:(nonnull NSData *)aResumeData;
- (BOOL)isDownloadingIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (BOOL)isWaitingForDownloadOfIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (BOOL)hasActiveDownloads;
- (void)cancelDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (nullable HWIFileDownloadProgress *)downloadProgressForIdentifier:(nonnull NSString *)aDownloadIdentifier;
```
	
### Progress

`HWIFileDownloadProgress` exposes these properties:

```objective-c
@property (nonatomic, assign, readonly) float downloadProgress;
@property (nonatomic, assign, readonly) int64_t expectedFileSize;
@property (nonatomic, assign, readonly) int64_t receivedFileSize;
@property (nonatomic, assign, readonly) NSTimeInterval estimatedRemainingTime;
@property (nonatomic, assign, readonly) NSUInteger bytesPerSecondSpeed;
@property (nonatomic, strong, readwrite, nullable) NSString *lastLocalizedDescription;
@property (nonatomic, strong, readwrite, nullable) NSString *lastLocalizedAdditionalDescription;
@property (nonatomic, strong, readonly, nonnull) NSProgress *nativeProgress;
```

## Demo App

The demo app shows a sample setup and integration of HWIFileDownload.

The app __download store__ is implemented with the custom class `DemoDownloadStore`.

The app delegate of the demo app holds an instance of the `DemoDownloadStore` and an instance of the `HWIFileDownloader`.

## Workflows and Scenarios

### Start and Restart

On app start a list of all downloads is collected.

### Pause and Resume

On "Pause" the download is stopped. The incomplete download data is preserved as resume data. With "Resume" the download can be continued, starting with the already downloaded data.

On iOS 6 pause and resume is not available. On iOS 7 and iOS 8 resume data needs to be managed by the app client. Since iOS 9 `NSProgress` manages the resume data transparently with the resume method.

### Cancel

On "Cancel" the download is stopped. No resume data is preserved. No re-download is offered.

### Crash

On "Crash" the app crashes. On iOS 7 (and later) started downloads continue in the background even though the app is not running anymore. On iOS 6 download does not continue.

### Force Quit

After the app has been killed by the user, downloads do not continue in the background. On iOS 7 (and later) resume data is passed back after the app launched again. Interrupted downloads can be resumed.

### Background

When running in the background, all running downloads continue on iOS 7 (and later). On iOS 6 all running downloads continue as background task for about 10 minutes.

### Network Interruption

When loosing network connection, all running downloads pause after request timeout. On iOS 7 (and later) the downloads resume when network becomes available again. On iOS 6 downloads are stopped after request timeout; they start again with the next app start.

## Customization

Two delegate calls provide hooks for adjusting connection parameters:

```objective-c
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)aBackgroundSessionConfiguration;
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)aRemoteURL; // iOS 6 only
```

### Timeout

With the delegate calls, timeout behaviour can be customized. On iOS there are two timeouts: __request timeout__ and __resource timeout__.

The __request timeout__ fires "if no data is transmitted for the given timeout value, and is reset whenever data is transmitted". iOS's system default value is 60 seconds.

The __resource timeout__ (available with `NSURLSession`) fires "if a resource is not able to be retrieved within a given timeout". The resource timeout fires even if data is currently received. It is reset with the first download task resuming on a background session with no download tasks running. iOS's system default value is 604800 seconds (7 days).

If the host of the network request is not reachable, `NSURLConnection` checks for host availability right after request start and fails immediately with an error if the host is not reachable (NSURLErrorDomain Code=-1003 "A server with the specified hostname could not be found."). `NSURLSession` only terminates when the resource timeout fires.

### Authentication

If authentication is required for a file download, you need to implement the delegate method

```objective-c
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)aChallenge
               downloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable aCredential, NSURLSessionAuthChallengeDisposition disposition))aCompletionHandler;
```

The demo app code includes a deactivated sample implementation.

## Integration

### App Delegate

See the sample code for advice on source code integration with the app delegate.

### Dependencies

HWIFileDownload has no third-party dependencies.

### Font Awesome

The demo app uses [Font Awesome](http://fontawesome.io "Font Awesome") for the download, cancel, pause, resume, completed, error, and cancelled icons.


## Notes

Please note that a system bug with iOS 10 broke correct progress reporting after resuming download until iOS 10.2. With the release of iOS 10.2 the bug was fixed by Apple (https://github.com/Heikowi/HWIFileDownload/issues/23).

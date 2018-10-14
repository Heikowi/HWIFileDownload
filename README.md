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

To use HWIFileDownload after integration, import the header file ``HWIFileDownloader.h`` in the Objective-C class files where you want to use it:

```objective-c
#import "HWIFileDownloader.h"
```

For use with Swift you need to add the imports to your Bridging-Header file:

```
#import "HWIBackgroundSessionCompletionHandlerBlock.h"
#import "HWIFileDownloadDelegate.h"
#import "HWIFileDownloader.h"
#import "HWIFileDownloadItem.h"
#import "HWIFileDownloadProgress.h"
```

## Implementation

HWIFileDownload uses a __download identifier__ for starting a download, retrieving progress information, and for handling download completion. The __download identifier__ is a string that must be unique for each individual file download.

To start a download, the app client calls the method `startDownloadWithIdentifier:fromRemoteURL:` of the `HWIFileDownloader`.

### Download Store as Delegate

The app client must maintain a custom __download store__ to manage the downloads and the persistent store. The app __download store__ needs to implement the protocol `HWIFileDownloadDelegate` to be called on important download events.

The delegate is called on download completion. Additional mandatory calls control the visibility of the network activity indicator. Optionally the delegate can be called on download progress change for each download item. To control the local name and location of the downloaded file, the delegate can implement the method `localFileURLForIdentifier:remoteURL:`.

Objective-C:

```objective-c
@protocol HWIFileDownloadDelegate
- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)identifier
                             localFileURL:(nonnull NSURL *)localFileURL;
- (void)downloadFailedWithIdentifier:(nonnull NSString *)identifier
                               error:(nonnull NSError *)error
                      httpStatusCode:(NSInteger)httpStatusCode
                  errorMessagesStack:(nullable NSArray<NSString *> *)errorMessagesStack
                          resumeData:(nullable NSData *)resumeData;
- (void)incrementNetworkActivityIndicatorActivityCount;
- (void)decrementNetworkActivityIndicatorActivityCount;

@optional
- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)identifier;
- (void)downloadPausedWithIdentifier:(nonnull NSString *)identifier
                          resumeData:(nullable NSData *)resumeData;
- (void)resumeDownloadWithIdentifier:(nonnull NSString *)identifier;
- (nullable NSURL *)localFileURLForIdentifier:(nonnull NSString *)identifier
                                    remoteURL:(nonnull NSURL *)remoteURL;
- (BOOL)downloadAtLocalFileURL:(nonnull NSURL *)localFileURL isValidForDownloadIdentifier:(nonnull NSString *)downloadIdentifier;
- (BOOL)httpStatusCode:(NSInteger)httpStatusCode isValidForDownloadIdentifier:(nonnull NSString *)downloadIdentifier;
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)backgroundSessionConfiguration;
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)remoteURL;
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
               downloadIdentifier:(nonnull NSString *)downloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable credential, NSURLSessionAuthChallengeDisposition disposition))completionHandler;
- (nullable NSProgress *)rootProgress;
@end
```

Swift sample class implementing the protocol:

```swift
class DownloadStore: NSObject, HWIFileDownloadDelegate {

    // HWIFileDownloadDelegate (mandatory)
    
    @objc public func downloadDidComplete(withIdentifier identifier: String, localFileURL: URL) {
        print("yes")
    }
    
    @objc public func downloadFailed(withIdentifier identifier: String, error: Error, httpStatusCode: Int, errorMessagesStack: [String]?, resumeData: Data?) {
        print("no")
    }
    
    @objc public func incrementNetworkActivityIndicatorActivityCount() {
        //
    }
    
    @objc public func decrementNetworkActivityIndicatorActivityCount() {
        //
    }
    
    // HWIFileDownloadDelegate (optional)
/*
    @objc public func downloadProgressChanged(forIdentifier identifier: String) {
        //
    }
    
    @objc public func downloadPaused(withIdentifier identifier: String, resumeData: Data?) {
        //
    }
    
    @objc public func resumeDownload(withIdentifier identifier: String) {
        //
    }
    
    @objc public func localFileURL(forIdentifier identifier: String, remoteURL: URL) -> URL? {
        return nil
    }
    
    @objc public func download(atLocalFileURL localFileURL: URL, isValidForDownloadIdentifier downloadIdentifier: String) -> Bool {
        return true
    }
    
    @objc public func httpStatusCode(_ httpStatusCode: Int, isValidForDownloadIdentifier downloadIdentifier: String) -> Bool {
        return true
    }
    
    @objc public func customizeBackgroundSessionConfiguration(_ backgroundSessionConfiguration: URLSessionConfiguration) {
        //
    }
    
    @objc public func urlRequest(forRemoteURL remoteURL: URL) -> URLRequest? {
        return nil
    }
    
    @objc public func onAuthenticationChallenge(_ challenge: URLAuthenticationChallenge, downloadIdentifier: String, completionHandler: @escaping (URLCredential?, URLSession.AuthChallengeDisposition) -> Void) {
        //
    }
    
    @objc public func rootProgress() -> Progress? {
        return nil
    }
*/
```


### Downloader

The app needs to hold an instance of the `HWIFileDownloader` that manages the download process. `HWIFileDownloader` provides methods for starting, querying and controlling individual download processes.

```objective-c
- (nonnull instancetype)initWithDelegate:(nonnull NSObject<HWIFileDownloadDelegate>*)delegate;
- (void)startDownloadWithIdentifier:(nonnull NSString *)identifier
                      fromRemoteURL:(nonnull NSURL *)remoteURL;
- (void)startDownloadWithIdentifier:(nonnull NSString *)identifier
                    usingResumeData:(nonnull NSData *)resumeData;
- (BOOL)isDownloadingIdentifier:(nonnull NSString *)identifier;
- (BOOL)isWaitingForDownloadOfIdentifier:(nonnull NSString *)identifier;
- (BOOL)hasActiveDownloads;
- (void)cancelDownloadWithIdentifier:(nonnull NSString *)identifier;
- (nullable HWIFileDownloadProgress *)downloadProgressForIdentifier:(nonnull NSString *)identifier;
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

The demo app shows a sample setup and integration of HWIFileDownload with an Objective-C application.

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
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)backgroundSessionConfiguration;
- (nullable NSURLRequest *)urlRequestForRemoteURL:(nonnull NSURL *)remoteURL; // iOS 6 only
```

### Timeout

With the delegate calls, timeout behaviour can be customized. On iOS there are two timeouts: __request timeout__ and __resource timeout__.

The __request timeout__ fires "if no data is transmitted for the given timeout value, and is reset whenever data is transmitted". iOS's system default value is 60 seconds.

The __resource timeout__ (available with `NSURLSession`) fires "if a resource is not able to be retrieved within a given timeout". The resource timeout fires even if data is currently received. It is reset with the first download task resuming on a background session with no download tasks running. iOS's system default value is 604800 seconds (7 days).

If the host of the network request is not reachable, `NSURLConnection` checks for host availability right after request start and fails immediately with an error if the host is not reachable (NSURLErrorDomain Code=-1003 "A server with the specified hostname could not be found."). `NSURLSession` only terminates when the resource timeout fires.

### Authentication

If authentication is required for a file download, you need to implement the delegate method

```objective-c
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
               downloadIdentifier:(nonnull NSString *)downloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable credential, NSURLSessionAuthChallengeDisposition disposition))completionHandler;
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

/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141003)
 * File: AppDelegate.m
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


#import "AppDelegate.h"

#import "DownloadTableViewController.h"
#import "HWIFileDownloader.h"
#import "DownloadStore.h"


@interface AppDelegate()
@property (strong, nonatomic, readwrite) DownloadStore *downloadStore;
@property (nonatomic, strong, readwrite) HWIFileDownloader *fileDownloader;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier; // iOS 6
@end



@implementation AppDelegate


- (BOOL)application:(UIApplication *)anApplication didFinishLaunchingWithOptions:(NSDictionary *)aLaunchOptionsDict
{
    
    // setup app download store
    self.downloadStore = [[DownloadStore alloc] init];
    
    // setup downloader
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        self.fileDownloader = [[HWIFileDownloader alloc] initWithDelegate:self.downloadStore];
    }
    else
    {
        self.fileDownloader = [[HWIFileDownloader alloc] initWithDelegate:self.downloadStore maxConcurrentDownloads:1];
    }
    
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid; // iOS 6
    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    DownloadTableViewController *downloadTableViewController = [[DownloadTableViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:downloadTableViewController];
    [self.window setRootViewController:navigationController];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}


// iOS 7
- (void)application:(UIApplication *)anApplication handleEventsForBackgroundURLSession:(NSString *)aBackgroundURLSessionIdentifier completionHandler:(void (^)())aCompletionHandler
{
    [self.fileDownloader setBackgroundSessionCompletionHandlerBlock:aCompletionHandler];
}


- (void)applicationDidBecomeActive:(UIApplication *)anApplication
{
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }
}


- (void)applicationDidEnterBackground:(UIApplication *)anApplication
{
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if (self.fileDownloader.hasActiveDownloads)
        {
            if (self.backgroundTaskIdentifier == UIBackgroundTaskInvalid)
            {
                __weak AppDelegate *weakSelf = self;
                dispatch_block_t anExpirationHandler = ^{
                    [[UIApplication sharedApplication] endBackgroundTask:weakSelf.backgroundTaskIdentifier];
                    weakSelf.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
                };
                self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:anExpirationHandler];
            }
        }
    }
}


@end

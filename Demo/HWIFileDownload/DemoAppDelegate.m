/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141003)
 * File: DemoAppDelegate.m
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


#import "DemoAppDelegate.h"

#import "DemoDownloadTableViewController.h"
#import "HWIFileDownloader.h"
#import "DemoDownloadStore.h"


@interface DemoAppDelegate()
@property (nonnull, nonatomic, strong, readwrite) DemoDownloadStore *demoDownloadStore;
@property (nonnull, nonatomic, strong, readwrite) HWIFileDownloader *fileDownloader;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier; // iOS 6
@end



@implementation DemoAppDelegate


- (BOOL)application:(UIApplication *)anApplication didFinishLaunchingWithOptions:(nullable NSDictionary *)aLaunchOptionsDict
{
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid; // iOS 6
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    DemoDownloadTableViewController *demoDownloadTableViewController = [[DemoDownloadTableViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:demoDownloadTableViewController];
    [self.window setRootViewController:navigationController];
    
    [self.window makeKeyAndVisible];
    
    
    // setup app download store
    self.demoDownloadStore = [[DemoDownloadStore alloc] init];
    
    // setup downloader
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        self.fileDownloader = [[HWIFileDownloader alloc] initWithDelegate:self.demoDownloadStore];
    }
    else
    {
        self.fileDownloader = [[HWIFileDownloader alloc] initWithDelegate:self.demoDownloadStore maxConcurrentDownloads:1];
    }
    [self.fileDownloader setupWithCompletion:^{
        [self.demoDownloadStore restartDownload];
    }];
    
    
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
                __weak DemoAppDelegate *weakSelf = self;
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

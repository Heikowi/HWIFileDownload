/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141004)
 * File: DownloadStore.m
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


#import "DownloadStore.h"
#import "AppDelegate.h"
#import "HWIFileDownloadDelegate.h"
#import "HWIFileDownloader.h"

#import <UIKit/UIKit.h>


@interface DownloadStore()
@property (nonatomic, assign) NSUInteger networkActivityIndicatorCount;
@property (nonatomic, strong, readwrite, nonnull) NSMutableDictionary *downloadItemsDict;
@property (nonatomic, strong, readwrite, nonnull) NSArray *sortedDownloadIdentifiersArray;
@end



@implementation DownloadStore


- (nullable DownloadStore *)init
{
    self = [super init];
    if (self)
    {
        self.networkActivityIndicatorCount = 0;
        
        // restore downloaded items
        self.downloadItemsDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"downloadItems"] mutableCopy];
        if (self.downloadItemsDict == nil)
        {
            self.downloadItemsDict = [NSMutableDictionary dictionary];
        }
        
        // setup items to download
        for (NSUInteger num = 1; num < 11; num++)
        {
            NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%@", @(num)];
            NSDictionary *aDownloadItemDict = [self.downloadItemsDict objectForKey:aDownloadIdentifier];
            if (aDownloadItemDict == nil)
            {
                NSURL *aRemoteURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.imagomat.de/testimages/%@.tiff", @(num)]];
                aDownloadItemDict = @{@"URL" : aRemoteURL.absoluteString};
                [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
            }
        };
        NSArray *aDownloadIdentifiersArray = [self.downloadItemsDict allKeys];
        NSSortDescriptor *aDownloadIdentifiersSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil
                                                                                             ascending:YES
                                                                                            comparator:^(id obj1, id obj2)
                                                                {
                                                                    return [obj1 compare:obj2 options:NSNumericSearch];
                                                                }];
        self.sortedDownloadIdentifiersArray = [aDownloadIdentifiersArray sortedArrayUsingDescriptors:@[aDownloadIdentifiersSortDescriptor]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restartDownload) name:@"restartDownload" object:nil];
        
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"restartDownload" object:nil];
}


#pragma mark - HWIFileDownloadDelegate


- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                             localFileURL:(nonnull NSURL *)aLocalFileURL
{
    NSLog(@"Download completed (id: %@)", aDownloadIdentifier);
    
    // store download item
    NSDictionary *aDownloadItemDict = @{@"URL" : aLocalFileURL.absoluteString, @"didFail" : @(NO)};
    [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
    [[NSUserDefaults standardUserDefaults] setObject:self.downloadItemsDict forKey:@"downloadItems"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadDidComplete" object:aDownloadIdentifier userInfo:nil];
}


- (void)downloadFailedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                               error:(nonnull NSError *)anError
                          resumeData:(nullable NSData *)aResumeData
{
    if (aResumeData)
    {
        NSMutableDictionary *aDownloadItemDict = [[self.downloadItemsDict objectForKey:aDownloadIdentifier] mutableCopy];
        if (aDownloadItemDict)
        {
            [aDownloadItemDict setObject:aResumeData forKey:@"ResumeData"];
            [aDownloadItemDict setObject:@(YES) forKey:@"didFail"];
            [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
            [[NSUserDefaults standardUserDefaults] setObject:self.downloadItemsDict forKey:@"downloadItems"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        else
        {
            NSLog(@"ERR: Download item dict not found for identifier: %@ (%s, %d)", aDownloadIdentifier, __FILE__, __LINE__);
        }
    }
    if ([anError.domain isEqualToString:NSURLErrorDomain] && (anError.code == NSURLErrorCancelled))
    {
        NSLog(@"Download cancelled - id: %@", aDownloadIdentifier);
    }
    else
    {
        NSLog(@"ERR: %@ (%s, %d)", anError, __FILE__, __LINE__);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadDidComplete" object:aDownloadIdentifier userInfo:nil];
}


- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgressChanged" object:aDownloadIdentifier userInfo:nil];
}


- (NSTimeInterval)requestTimeoutInterval
{
    return 30.0;
}


- (void)incrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:YES];
}


- (void)decrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:NO];
}


- (BOOL)downloadIsValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                              atLocalFileURL:(nonnull NSURL *)aLocalFileURL
{
    BOOL anIsValidFlag = YES;
    
    // just checking for file size
    // you might want to check by converting into expected data format (like UIImage) or by scanning for expected content
    
    NSError *anError = nil;
    NSDictionary *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
    if (anError)
    {
        NSLog(@"ERR: Error on getting file size for item at %@: %@ (%s, %d)", aLocalFileURL, anError, __FILE__, __LINE__);
        anIsValidFlag = NO;
    }
    else
    {
        unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
        if (aFileSize == 0)
        {
            anIsValidFlag = NO;
        }
        else
        {
            if (aFileSize < 40000)
            {
                anIsValidFlag = NO;
            }
        }
    }
    return anIsValidFlag;
}


#pragma mark - restart download


- (void)restartDownload
{
    for (NSString *aDownloadIdentifierString in self.sortedDownloadIdentifiersArray)
    {
        NSDictionary *aDownloadItemDict = [self.downloadItemsDict objectForKey:aDownloadIdentifierString];
        NSString *aURLString = [aDownloadItemDict objectForKey:@"URL"];
        if (aURLString.length > 0)
        {
            NSURL *aURL = [NSURL URLWithString:aURLString];
            if ([aURL.scheme isEqualToString:@"http"])
            {
                NSMutableDictionary *aDownloadItemDict = [[self.downloadItemsDict objectForKey:aDownloadIdentifierString] mutableCopy];
                [aDownloadItemDict setObject:@(NO) forKey:@"didFail"];
                [self.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifierString];
                [[NSUserDefaults standardUserDefaults] setObject:self.downloadItemsDict forKey:@"downloadItems"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
                BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifierString];
                if (isDownloading == NO)
                {
                    // kick off individual download
                    NSData *aResumeData = [aDownloadItemDict objectForKey:@"ResumeData"];
                    if (aResumeData)
                    {
                        [theAppDelegate.fileDownloader startDownloadWithDownloadIdentifier:aDownloadIdentifierString usingResumeData:aResumeData];
                    }
                    else
                    {
                        [theAppDelegate.fileDownloader startDownloadWithDownloadIdentifier:aDownloadIdentifierString fromRemoteURL:aURL];
                    }
                }
            }
        }
        else
        {
            NSLog(@"ERR: No URL (%s, %d)", __FILE__, __LINE__);
        }
    }
}


#pragma mark - network activity indicator


- (void)toggleNetworkActivityIndicatorVisible:(BOOL)visible
{
    visible ? self.networkActivityIndicatorCount++ : self.networkActivityIndicatorCount--;
    NSLog(@"NetworkActivityIndicatorCount: %@", @(self.networkActivityIndicatorCount));
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.networkActivityIndicatorCount > 0);
}


@end

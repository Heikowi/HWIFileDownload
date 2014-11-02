/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141003)
 * File: DownloadTableViewController.m
 *
 */

/***************************************************************************
 
 Copyright (c) 2014 Heiko Wichmann
 
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


#import "DownloadTableViewController.h"

#import "AppDelegate.h"
#import "DownloadStore.h"
#import "HWIFileDownloader.h"



@interface DownloadTableViewController ()
@property (nonatomic, assign) NSInteger textLabelTag;
@property (nonatomic, assign) NSInteger progressViewTag;
@end



@implementation DownloadTableViewController


- (instancetype)initWithStyle:(UITableViewStyle)aTableViewStyle
{
    self = [super initWithStyle:aTableViewStyle];
    if (self)
    {
        self.textLabelTag = 1;
        self.progressViewTag = 2;
        
        UIRefreshControl *aRefreshControl = [[UIRefreshControl alloc] init];
        [aRefreshControl addTarget:self action:@selector(onRefreshTable) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = aRefreshControl;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadDidComplete:) name:@"downloadDidComplete" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onProgressChanged:) name:@"downloadProgressChanged" object:nil];
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"downloadDidComplete" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"downloadProgressChanged" object:nil];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.rowHeight = 44.0;
    [self.tableView registerNib:[UINib nibWithNibName:@"DownloadTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"DownloadTableViewCell"];
    self.title = @"Downloads";
    
    UIBarButtonItem *aLeftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Crash" style:UIBarButtonItemStyleBordered target:self action:@selector(crash)];
    self.navigationItem.leftBarButtonItem = aLeftBarButtonItem;
    
    UIBarButtonItem *aRightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = aRightBarButtonItem;    
}


#pragma mark - UITableViewDataSource


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return [theAppDelegate.downloadStore.downloadItemsDict count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *aCell = [tableView dequeueReusableCellWithIdentifier:@"DownloadTableViewCell" forIndexPath:indexPath];

    NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%@", @(indexPath.row + 1)];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSDictionary *aDownloadItemDict = [[theAppDelegate downloadStore].downloadItemsDict objectForKey:aDownloadIdentifier];
    NSString *aURLString = [aDownloadItemDict objectForKey:@"URL"];
    NSURL *aURL = nil;
    if (aURLString.length > 0)
    {
        aURL = [NSURL URLWithString:aURLString];
    }
    
    UILabel *aTextLabel = (UILabel *)[aCell viewWithTag:self.textLabelTag];
    UIProgressView *aProgressView = (UIProgressView *)[aCell viewWithTag:self.progressViewTag];
    if ([aURL.scheme isEqualToString:@"http"])
    {
        aTextLabel.text = aURL.absoluteString;
        HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
        aProgressView.progress = aFileDownloadProgress.downloadProgress;
        [aProgressView setHidden:NO];
    }
    else
    {
        aTextLabel.text = [NSString stringWithFormat:@"%@", aURL.lastPathComponent];
        [aProgressView setHidden:YES];
    }
    return aCell;
}


#pragma mark - Actions

- (void)crash
{
    NSArray *anArray = [NSArray array];
    id test = [anArray objectAtIndex:123456789];
    NSLog(@"%@", test);
}


- (void)cancel
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSArray *aDownloadIdentifiersArray = [theAppDelegate.downloadStore.downloadItemsDict allKeys];
    for (NSString *aDownloadIdentifier in aDownloadIdentifiersArray)
    {
        BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
        if (isDownloading)
        {
            [theAppDelegate.fileDownloader cancelDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:^(NSData *aResumeData) {
                if (aResumeData)
                {
                    NSMutableDictionary *aDownloadItemDict = [[theAppDelegate.downloadStore.downloadItemsDict objectForKey:aDownloadIdentifier] mutableCopy];
                    [aDownloadItemDict setObject:aResumeData forKey:@"ResumeData"];
                    [theAppDelegate.downloadStore.downloadItemsDict setObject:aDownloadItemDict forKey:aDownloadIdentifier];
                    [[NSUserDefaults standardUserDefaults] setObject:theAppDelegate.downloadStore.downloadItemsDict forKey:@"downloadItems"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }];
        }
    }
}


#pragma mark - Download Notifications


- (void)onDownloadDidComplete:(NSNotification *)aNotification
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSDictionary *aDownloadItemDict = [theAppDelegate.downloadStore.downloadItemsDict objectForKey:(NSString *)aNotification.object];
    NSString *aLocalFileURLString = [aDownloadItemDict objectForKey:@"URL"];
    NSURL *aLocalFileURL = nil;
    if (aLocalFileURLString.length > 0)
    {
        aLocalFileURL = [NSURL URLWithString:aLocalFileURLString];
    }
    
    NSNumberFormatter *aNumberFormatter = [[NSNumberFormatter alloc] init];
    [aNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *aRowNumber = [aNumberFormatter numberFromString:(NSString *)aNotification.object];
    NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:([aRowNumber unsignedIntegerValue]- 1) inSection:0];
    
    UITableViewCell *aTableViewCell = [self.tableView cellForRowAtIndexPath:anIndexPath];
    UILabel *aTextLabel = (UILabel *)[aTableViewCell viewWithTag:self.textLabelTag];
    UIProgressView *aProgressView = (UIProgressView *)[aTableViewCell viewWithTag:self.progressViewTag];
    aTextLabel.text = aLocalFileURL.lastPathComponent;
    [aProgressView setHidden:YES];
}


- (void)onProgressChanged:(NSNotification *)aNotification
{
    NSNumberFormatter *aNumberFormatter = [[NSNumberFormatter alloc] init];
    [aNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber *aRowNumber = [aNumberFormatter numberFromString:(NSString *)aNotification.object];
    NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:([aRowNumber unsignedIntegerValue]- 1) inSection:0];
    UITableViewCell *aTableViewCell = [self.tableView cellForRowAtIndexPath:anIndexPath];
    UIProgressView *aProgressView = (UIProgressView *)[aTableViewCell viewWithTag:self.progressViewTag];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:(NSString *)aNotification.object];
    aProgressView.progress = aFileDownloadProgress.downloadProgress;
    [aProgressView setHidden:NO];
}


- (void)onRefreshTable
{
    [self.refreshControl endRefreshing];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [theAppDelegate.downloadStore restartDownload];
    [self.tableView reloadData];
}


@end

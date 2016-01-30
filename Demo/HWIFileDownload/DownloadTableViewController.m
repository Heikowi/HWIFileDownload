/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141003)
 * File: DownloadTableViewController.m
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


#import "DownloadTableViewController.h"

#import "AppDelegate.h"
#import "DownloadStore.h"
#import "HWIFileDownloader.h"
#import "HWIFileDownloadItemStatus.h"


@interface DownloadTableViewController ()
@property (nonatomic, assign) NSInteger fileNameLabelTag;
@property (nonatomic, assign) NSInteger infoTextLabelTag;
@property (nonatomic, assign) NSInteger progressViewTag;
@property (nonatomic, assign) NSInteger pauseResumeButtonTag;
@property (nonatomic, assign) NSInteger cancelButtonTag;

@property (nonatomic, weak) UIProgressView *totalProgressView;
@property (nonatomic, weak) UILabel *totalProgressLocalizedDescriptionLabel;

@property (nonatomic, strong, nullable) NSDate *lastProgressChangedUpdate;
@end



@implementation DownloadTableViewController


- (instancetype)initWithStyle:(UITableViewStyle)aTableViewStyle
{
    self = [super initWithStyle:aTableViewStyle];
    if (self)
    {
        self.fileNameLabelTag = 1;
        self.infoTextLabelTag = 2;
        self.progressViewTag = 3;
        self.pauseResumeButtonTag = 4;
        self.cancelButtonTag = 5;
        
        UIRefreshControl *aRefreshControl = [[UIRefreshControl alloc] init];
        [aRefreshControl addTarget:self action:@selector(onRefreshTable) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = aRefreshControl;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadDidComplete:) name:@"downloadDidComplete" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onProgressDidChange:) name:@"downloadProgressChanged" object:nil];
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTotalProgressDidChange:) name:@"totalDownloadProgressChanged" object:nil];
        }
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
    
    self.tableView.rowHeight = 98.0;
    [self.tableView registerNib:[UINib nibWithNibName:@"DownloadTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"DownloadTableViewCell"];
    self.title = @"Download";
    
    UIBarButtonItem *aRightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Crash" style:UIBarButtonItemStyleBordered target:self action:@selector(crash)];
    self.navigationItem.rightBarButtonItem = aRightBarButtonItem;    
}


#pragma mark - UITableViewDataSource


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)aSection
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return [theAppDelegate downloadStore].sortedDownloadIdentifiersArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)anIndexPath
{
    UITableViewCell *aTableViewCell = [aTableView dequeueReusableCellWithIdentifier:@"DownloadTableViewCell" forIndexPath:anIndexPath];
    
    UIButton *aPauseResumeDownloadButton = (UIButton *)[aTableViewCell viewWithTag:self.pauseResumeButtonTag];
    UIButton *aCancelDownloadButton = (UIButton *)[aTableViewCell viewWithTag:self.cancelButtonTag];
    
    [aPauseResumeDownloadButton addTarget:self action:@selector(onPauseResumeIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
    [aCancelDownloadButton addTarget:self action:@selector(onCancelIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *anInfoTextLabel = (UILabel *)[aTableViewCell viewWithTag:self.infoTextLabelTag];
    if ([UIFont respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)])
    {
        [anInfoTextLabel setFont:[UIFont monospacedDigitSystemFontOfSize:10.0 weight:UIFontWeightRegular]];
    }
    else
    {
        [anInfoTextLabel setFont:[UIFont systemFontOfSize:10.0]];
    }
    
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *aDownloadIdentifier = [[theAppDelegate downloadStore].sortedDownloadIdentifiersArray objectAtIndex:anIndexPath.row];
    NSDictionary *aDownloadItemDict = [[theAppDelegate downloadStore].downloadItemsDict objectForKey:aDownloadIdentifier];
    
    [self prepareTableViewCell:aTableViewCell withDict:aDownloadItemDict downloadIdentifier:aDownloadIdentifier];
    
    return aTableViewCell;
}


- (CGFloat)tableView:(UITableView *)aTableView heightForHeaderInSection:(NSInteger)aSection
{
    CGFloat aHeaderHeight = 0.0;
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        if (aSection == 0)
        {
            aHeaderHeight = 20.0;
        }
    }
    return aHeaderHeight;
}


- (UIView *)tableView:(UITableView *)aTableView viewForHeaderInSection:(NSInteger)aSection
{
    UIView *aHeaderView = nil;
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        if (aSection == 0)
        {
            aHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 20.0)];
            [aHeaderView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
            [aHeaderView setBackgroundColor:[UIColor colorWithRed:(212.0 / 255.0) green:(212.0 / 255.0) blue:(212.0 / 255.0) alpha:1.0]];
            // total progress view
            UIProgressView *aProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
            CGRect aProgressViewRect = aProgressView.frame;
            aProgressViewRect.size.width = aHeaderView.frame.size.width;
            [aProgressView setFrame:aProgressViewRect];
            [aProgressView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
            [aHeaderView addSubview:aProgressView];
            self.totalProgressView = aProgressView;
            // total progress localized description view
            UILabel *aLocalizedDescriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0, CGRectGetMaxY(self.totalProgressView.frame), aHeaderView.frame.size.width - 20.0, 14.0)];
            if ([UIFont respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)])
            {
                [aLocalizedDescriptionLabel setFont:[UIFont monospacedDigitSystemFontOfSize:10.0 weight:UIFontWeightRegular]];
            }
            else
            {
                [aLocalizedDescriptionLabel setFont:[UIFont systemFontOfSize:10.0]];
            }
            [aLocalizedDescriptionLabel setTextAlignment:NSTextAlignmentCenter];
            [aLocalizedDescriptionLabel setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin)];
            [aHeaderView addSubview:aLocalizedDescriptionLabel];
            self.totalProgressLocalizedDescriptionLabel = aLocalizedDescriptionLabel;
        }
    }
    return aHeaderView;
}


#pragma mark - Actions

- (void)crash
{
    NSArray *anArray = [NSArray array];
    id test = [anArray objectAtIndex:123456789];
    NSLog(@"%@", test);
}


- (void)onCancelIndividualDownload:(id)aSender
{
    UITableViewCell *aTableViewCell = nil;
    UIView *aCurrView = (UIView *)aSender;
    while (aTableViewCell == nil)
    {
        UIView *aSuperView = [aCurrView superview];
        if ([aSuperView isKindOfClass:[UITableViewCell class]])
        {
            aTableViewCell = (UITableViewCell *)aSuperView;
        }
        aCurrView = aSuperView;
    }
    NSIndexPath *anIndexPath = [self.tableView indexPathForCell:aTableViewCell];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *aDownloadIdentifier = [[theAppDelegate downloadStore].sortedDownloadIdentifiersArray objectAtIndex:anIndexPath.row];
    
    [self cancelDownloadWithIdentifier:aDownloadIdentifier];
}


- (void)onPauseResumeIndividualDownload:(id)aSender
{
    UITableViewCell *aTableViewCell = nil;
    UIView *aCurrView = (UIView *)aSender;
    while (aTableViewCell == nil)
    {
        UIView *aSuperView = [aCurrView superview];
        if ([aSuperView isKindOfClass:[UITableViewCell class]])
        {
            aTableViewCell = (UITableViewCell *)aSuperView;
        }
        aCurrView = aSuperView;
    }
    NSIndexPath *anIndexPath = [self.tableView indexPathForCell:aTableViewCell];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSString *aDownloadIdentifier = [[theAppDelegate downloadStore].sortedDownloadIdentifiersArray objectAtIndex:anIndexPath.row];
    
    [self pauseResumeDownloadWithIdentifier:aDownloadIdentifier];
}


- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
    if (isDownloading)
    {
        // app client bookkeeping
        AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [theAppDelegate.downloadStore cancelDownloadWithDownloadIdentifier:aDownloadIdentifier];
        
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
            [aFileDownloadProgress.progress cancel];
        }
        else
        {
            [theAppDelegate.fileDownloader cancelDownloadWithIdentifier:aDownloadIdentifier];
        }
    }
}


- (void)pauseResumeDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
    if (isDownloading)
    {
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
            [aFileDownloadProgress.progress pause];
        }
        else
        {
            [theAppDelegate.fileDownloader pauseDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:^(NSData *aResumeData) {
                if (aResumeData)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"PausedDownloadResumeDataNotification"
                                                                        object:aResumeData
                                                                      userInfo:@{@"downloadIdentifier" : aDownloadIdentifier}];
                }
            }];
        }
    }
}


#pragma mark - Download Notifications


- (void)onDownloadDidComplete:(NSNotification *)aNotification
{
    NSString *aDownloadIdentifier = (NSString *)aNotification.object;
    
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSInteger aFoundRowIndex = -1;
    NSUInteger aCurrIndex = 0;
    for (NSString *anIdentifier in [theAppDelegate downloadStore].sortedDownloadIdentifiersArray)
    {
        if ([anIdentifier isEqualToString:aDownloadIdentifier])
        {
            aFoundRowIndex = aCurrIndex;
            break;
        }
        aCurrIndex++;
    }
    
    if (aFoundRowIndex > -1)
    {
        NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:aFoundRowIndex inSection:0];
        UITableViewCell *aTableViewCell = [self.tableView cellForRowAtIndexPath:anIndexPath];
        if (aTableViewCell)
        {
            NSDictionary *aDownloadItemDict = [[theAppDelegate downloadStore].downloadItemsDict objectForKey:aDownloadIdentifier];
            [self prepareTableViewCell:aTableViewCell withDict:aDownloadItemDict downloadIdentifier:aDownloadIdentifier];
        }
    }
}


- (void)onTotalProgressDidChange:(NSNotification *)aNotification
{
    NSProgress *aProgress = aNotification.object;
    self.totalProgressView.progress = (float)aProgress.fractionCompleted;
    if (aProgress.completedUnitCount != aProgress.totalUnitCount)
    {
        self.totalProgressLocalizedDescriptionLabel.text = aProgress.localizedDescription;
    }
    else
    {
        self.totalProgressLocalizedDescriptionLabel.text = @"";
    }
}


- (void)onProgressDidChange:(NSNotification *)aNotification
{
    NSTimeInterval aLastProgressChangedUpdateDelta = 0.0;
    if (self.lastProgressChangedUpdate)
    {
        aLastProgressChangedUpdateDelta = [[NSDate date] timeIntervalSinceDate:self.lastProgressChangedUpdate];
    }
    // refresh progress display about four times per second
    if ((aLastProgressChangedUpdateDelta == 0.0) || (aLastProgressChangedUpdateDelta > 0.25))
    {
        AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSArray *aVisibleIndexPathsArray = [self.tableView indexPathsForVisibleRows];
        for (NSIndexPath *anIndexPath in aVisibleIndexPathsArray)
        {
            NSString *aDownloadIdentifier = [[theAppDelegate downloadStore].sortedDownloadIdentifiersArray objectAtIndex:anIndexPath.row];
            NSDictionary *aDownloadItemDict = [[theAppDelegate downloadStore].downloadItemsDict objectForKey:aDownloadIdentifier];
            UITableViewCell *aTableViewCell = [self.tableView cellForRowAtIndexPath:anIndexPath];
            if (aTableViewCell)
            {
                [self prepareTableViewCell:aTableViewCell withDict:aDownloadItemDict downloadIdentifier:aDownloadIdentifier];
            }
        }
        self.lastProgressChangedUpdate = [NSDate date];
    }
}


- (void)onRefreshTable
{
    [self.refreshControl endRefreshing];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [theAppDelegate.downloadStore restartDownload];
    [self.tableView reloadData];
}


- (void)prepareTableViewCell:(UITableViewCell *)aTableViewCell withDict:(NSDictionary *)aDownloadItemDict downloadIdentifier:(NSString *)aDownloadIdentifier
{
    UILabel *aFileNameLabel = (UILabel *)[aTableViewCell viewWithTag:self.fileNameLabelTag];
    UILabel *anInfoTextLabel = (UILabel *)[aTableViewCell viewWithTag:self.infoTextLabelTag];
    UIButton *aPauseResumeDownloadButton = (UIButton *)[aTableViewCell viewWithTag:self.pauseResumeButtonTag];
    UIButton *aCancelDownloadButton = (UIButton *)[aTableViewCell viewWithTag:self.cancelButtonTag];
    
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    [aPauseResumeDownloadButton setHidden:YES];
    [aCancelDownloadButton setHidden:YES];
    
    NSString *aURLString = [aDownloadItemDict objectForKey:@"URL"];
    NSURL *aURL = [NSURL URLWithString:aURLString];
    
    UIProgressView *aProgressView = (UIProgressView *)[aTableViewCell viewWithTag:self.progressViewTag];
    
    BOOL isCancelled = [[aDownloadItemDict objectForKey:@"isCancelled"] boolValue];
    if (isCancelled)
    {
        [aProgressView setHidden:YES];
        [anInfoTextLabel setHidden:NO];
        [aPauseResumeDownloadButton setHidden:YES];
        [aCancelDownloadButton setHidden:NO];
        anInfoTextLabel.text = @"Cancelled";
    }
    else
    {
        if ([aURL.scheme isEqualToString:@"http"])
        {
            aFileNameLabel.text = aURL.absoluteString;
            BOOL isWaitingForDownload = [theAppDelegate.fileDownloader isWaitingForDownloadOfIdentifier:aDownloadIdentifier];
            if (isWaitingForDownload)
            {
                aProgressView.progress = 0.0;
                anInfoTextLabel.text = @"Waiting for download";
                [aProgressView setHidden:NO];
                [anInfoTextLabel setHidden:NO];
            }
            else
            {
                HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
                if (aFileDownloadProgress)
                {
                    [aProgressView setHidden:NO];
                    [anInfoTextLabel setHidden:NO];
                    [aPauseResumeDownloadButton setHidden:NO];
                    [aCancelDownloadButton setHidden:NO];
                    float aProgress = 0.0;
                    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
                    {
                        aProgress = aFileDownloadProgress.progress.fractionCompleted;
                    }
                    else
                    {
                        aProgress = aFileDownloadProgress.downloadProgress;
                    }
                    BOOL didFail = [[aDownloadItemDict objectForKey:@"didFail"] boolValue];
                    if (didFail == YES)
                    {
                        aProgress = 0.0;
                    }
                    aProgressView.progress = aProgress;
                    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
                    {
                        anInfoTextLabel.text = aFileDownloadProgress.progress.localizedAdditionalDescription;
                    }
                    else
                    {
                        anInfoTextLabel.text = [DownloadTableViewController displayStringForRemainingTime:aFileDownloadProgress.estimatedRemainingTime];
                    }
                }
            }
        }
        else
        {
            aFileNameLabel.text = [NSString stringWithFormat:@"%@", aURL.lastPathComponent];
            anInfoTextLabel.text = @"";
            [aProgressView setHidden:YES];
            [anInfoTextLabel setHidden:YES];
        }
    }
}

#pragma mark - Utilities


+ (nonnull NSString *)displayStringForRemainingTime:(NSTimeInterval)aRemainingTime
{
    NSNumberFormatter *aNumberFormatter = [[NSNumberFormatter alloc] init];
    [aNumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [aNumberFormatter setMinimumFractionDigits:1];
    [aNumberFormatter setMaximumFractionDigits:1];
    [aNumberFormatter setDecimalSeparator:@"."];
    return [NSString stringWithFormat:@"Estimated remaining time: %@ seconds", [aNumberFormatter stringFromNumber:@(aRemainingTime)]];
}


@end

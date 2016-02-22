/*
 * Project: HWIFileDownload (Demo App)
 
 * Created by Heiko Wichmann (20141003)
 * File: DownloadTableViewController.m
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


#import "DownloadTableViewController.h"

#import "AppDelegate.h"
#import "DownloadStore.h"
#import "DemoDownloadItem.h"
#import "HWIFileDownloader.h"


@interface DownloadTableViewController ()
@property (nonatomic, assign) NSInteger fileNameLabelTag;
@property (nonatomic, assign) NSInteger infoTextLabelTag;
@property (nonatomic, assign) NSInteger progressViewTag;
@property (nonatomic, assign) NSInteger pauseOrResumeButtonTag;
@property (nonatomic, assign) NSInteger downloadCancelOrStateButtonTag;
@property (nonatomic, strong) NSString *downloadChar;
@property (nonatomic, strong) NSString *cancelChar;
@property (nonatomic, strong) NSString *pauseChar;
@property (nonatomic, strong) NSString *resumeChar;
@property (nonatomic, strong) NSString *completedChar;
@property (nonatomic, strong) NSString *errorChar;
@property (nonatomic, strong) NSString *cancelledChar;

@property (nonatomic, strong) UIView *headerView;
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
        self.pauseOrResumeButtonTag = 4;
        self.downloadCancelOrStateButtonTag = 5;
        
        self.downloadChar = @"\uf0ed"; // fa-cloud-download
        self.cancelChar = @"\uf00d"; // fa-times (Aliases: fa-remove, fa-close)
        self.pauseChar = @"\uf04c"; // fa-pause
        self.resumeChar = @"\uf021"; // fa-refresh
        self.completedChar = @"\uf00c"; // fa-check
        self.errorChar = @"\uf0e7"; // fa-bolt (Aliases: fa-flash)
        self.cancelledChar = @"\uf05e"; // fa-ban
        
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
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"totalDownloadProgressChanged" object:nil];
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.rowHeight = 120.0;
    [self.tableView registerNib:[UINib nibWithNibName:@"DownloadTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"DownloadTableViewCell"];
    self.title = @"Download";
    
    UIBarButtonItem *aRightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Crash" style:UIBarButtonItemStyleBordered target:self action:@selector(crash)];
    self.navigationItem.rightBarButtonItem = aRightBarButtonItem;    
}


#pragma mark - UITableViewDataSource


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)aSection
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    return [theAppDelegate downloadStore].downloadItemsArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)anIndexPath
{
    UITableViewCell *aTableViewCell = [aTableView dequeueReusableCellWithIdentifier:@"DownloadTableViewCell" forIndexPath:anIndexPath];
    
    UIButton *aPauseOrResumeButton = (UIButton *)[aTableViewCell viewWithTag:self.pauseOrResumeButtonTag];
    UIButton *aDownloadCancelOrStateButton = (UIButton *)[aTableViewCell viewWithTag:self.downloadCancelOrStateButtonTag];
    
    [aPauseOrResumeButton.titleLabel setFont:[UIFont fontWithName:@"FontAwesome" size:20.0]];
    [aDownloadCancelOrStateButton.titleLabel setFont:[UIFont fontWithName:@"FontAwesome" size:20.0]];
    
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
    DemoDownloadItem *aDownloadItem = [[theAppDelegate downloadStore].downloadItemsArray objectAtIndex:anIndexPath.row];
    
    [self prepareTableViewCell:aTableViewCell withDownloadItem:aDownloadItem];
    
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
    if (self.headerView == nil)
    {
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            if (aSection == 0)
            {
                UIView *aHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 20.0)];
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
                self.headerView = aHeaderView;
            }
        }
    }
    return self.headerView;
}


#pragma mark - Actions


- (void)crash
{
    NSArray *anArray = [NSArray array];
    id test = [anArray objectAtIndex:123456789];
    NSLog(@"%@", test);
}


- (void)onStartIndividualDownload:(id)aSender
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
    if (anIndexPath)
    {
        AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        DemoDownloadItem *aDownloadItem = [[theAppDelegate downloadStore].downloadItemsArray objectAtIndex:anIndexPath.row];
        
        [theAppDelegate.downloadStore startDownloadWithDownloadItem:aDownloadItem];
    }
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
    if (anIndexPath)
    {
        AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        DemoDownloadItem *aDownloadItem = [[theAppDelegate downloadStore].downloadItemsArray objectAtIndex:anIndexPath.row];
        
        [self cancelDownloadWithIdentifier:aDownloadItem.downloadIdentifier];
    }
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
    if (anIndexPath)
    {
        AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        DemoDownloadItem *aDownloadItem = [[theAppDelegate downloadStore].downloadItemsArray objectAtIndex:anIndexPath.row];
        
        UIButton *aButton = (UIButton *)aSender;
        if ([[aButton titleForState:UIControlStateNormal] isEqualToString:self.pauseChar])
        {
            [self pauseDownloadWithIdentifier:aDownloadItem.downloadIdentifier];
        }
        else if ([[aButton titleForState:UIControlStateNormal] isEqualToString:self.resumeChar])
        {
            [self resumeDownloadWithIdentifier:aDownloadItem.downloadIdentifier];
        }
    }
}


- (void)cancelDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
    if (isDownloading)
    {
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
            [aFileDownloadProgress.nativeProgress cancel];
        }
        else
        {
            [theAppDelegate.fileDownloader cancelDownloadWithIdentifier:aDownloadIdentifier];
        }
    }
    else
    {
        // app client bookkeeping
        [theAppDelegate.downloadStore cancelDownloadWithDownloadIdentifier:aDownloadIdentifier];
        
        __block BOOL found = NO;
        NSUInteger aCompletedDownloadItemIndex = [[theAppDelegate downloadStore].downloadItemsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            if ([[(DemoDownloadItem *)obj downloadIdentifier] isEqualToString:aDownloadIdentifier]) {
                *stop = YES;
                found = YES;
                return YES;
            }
            return NO;
        }];
        if (found)
        {
            NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:aCompletedDownloadItemIndex inSection:0];
            [self.tableView reloadRowsAtIndexPaths:@[anIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}


- (void)pauseDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    BOOL isDownloading = [theAppDelegate.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
    if (isDownloading)
    {
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
            [aFileDownloadProgress.nativeProgress pause];
        }
        else
        {
            [theAppDelegate.fileDownloader pauseDownloadWithIdentifier:aDownloadIdentifier resumeDataBlock:^(NSData *aResumeData) {
                [theAppDelegate.downloadStore downloadPausedWithIdentifier:aDownloadIdentifier
                                                                resumeData:aResumeData];
            }];
        }
    }
}


- (void)resumeDownloadWithIdentifier:(NSString *)aDownloadIdentifier
{
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [theAppDelegate.downloadStore restartDownloadWithDownloadIdentifier:aDownloadIdentifier];
}


#pragma mark - Download Notifications


- (void)onDownloadDidComplete:(NSNotification *)aNotification
{
    DemoDownloadItem *aDownloadItem = (DemoDownloadItem *)aNotification.object;
    
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    __block BOOL found = NO;
    NSUInteger aCompletedDownloadItemIndex = [[theAppDelegate downloadStore].downloadItemsArray indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        if ([[(DemoDownloadItem *)obj downloadIdentifier] isEqualToString:aDownloadItem.downloadIdentifier]) {
            *stop = YES;
            found = YES;
            return YES;
        }
        return NO;
    }];
    if (found)
    {
        NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:aCompletedDownloadItemIndex inSection:0];
        [self.tableView reloadRowsAtIndexPaths:@[anIndexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
    else
    {
        NSLog(@"WARN: Completed download item not found (%s, %d)", __FILE__, __LINE__);
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
        [self.tableView reloadData];
        self.lastProgressChangedUpdate = [NSDate date];
    }
}


#pragma mark - Table View


- (void)onRefreshTable
{
    [self.refreshControl endRefreshing];
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [theAppDelegate.downloadStore restartDownload];
    [self.tableView reloadData];
}


- (void)prepareTableViewCell:(UITableViewCell *)aTableViewCell withDownloadItem:(DemoDownloadItem *)aDownloadItem
{
    UILabel *aFileNameLabel = (UILabel *)[aTableViewCell viewWithTag:self.fileNameLabelTag];
    UILabel *anInfoTextLabel = (UILabel *)[aTableViewCell viewWithTag:self.infoTextLabelTag];
    
    UIButton *aPauseOrResumeButton = (UIButton *)[aTableViewCell viewWithTag:self.pauseOrResumeButtonTag];
    UIButton *aDownloadCancelOrStateButton = (UIButton *)[aTableViewCell viewWithTag:self.downloadCancelOrStateButtonTag];
    
    AppDelegate *theAppDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    UIProgressView *aProgressView = (UIProgressView *)[aTableViewCell viewWithTag:self.progressViewTag];
    [aProgressView setHidden:YES];
    
    aFileNameLabel.text = aDownloadItem.remoteURL.absoluteString;
    
    [self prepareDownloadCancelOrStateButton:aDownloadCancelOrStateButton forDemoDownloadItemStatus:aDownloadItem.status];
    [self preparePauseResumeButton:aPauseOrResumeButton forDemoDownloadItemStatus:aDownloadItem.status];
    
    if (aDownloadItem.status == DemoDownloadItemStatusNotStarted)
    {
        anInfoTextLabel.text = @"Not started";
    }
    else if (aDownloadItem.status == DemoDownloadItemStatusStarted)
    {
        BOOL isWaitingForDownload = [theAppDelegate.fileDownloader isWaitingForDownloadOfIdentifier:aDownloadItem.downloadIdentifier];
        if (isWaitingForDownload)
        {
            aProgressView.progress = 0.0;
            anInfoTextLabel.text = @"Waiting for download";
        }
        else
        {
            HWIFileDownloadProgress *aFileDownloadProgress = [theAppDelegate.fileDownloader downloadProgressForIdentifier:aDownloadItem.downloadIdentifier];
            if (aFileDownloadProgress)
            {
                [aProgressView setHidden:NO];
                float aProgress = 0.0;
                if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
                {
                    aProgress = aFileDownloadProgress.nativeProgress.fractionCompleted;
                }
                else
                {
                    aProgress = aFileDownloadProgress.downloadProgress;
                }
                aProgressView.progress = aProgress;
                if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
                {
                    anInfoTextLabel.text = aFileDownloadProgress.nativeProgress.localizedAdditionalDescription;
                }
                else
                {
                    anInfoTextLabel.text = [DownloadTableViewController displayStringForRemainingTime:aFileDownloadProgress.estimatedRemainingTime];
                }
            }
        }
    }
    else if (aDownloadItem.status == DemoDownloadItemStatusCompleted)
    {
        aFileNameLabel.text = [NSString stringWithFormat:@"%@", aDownloadItem.remoteURL.lastPathComponent];
        anInfoTextLabel.text = @"Completed";
    }
    else if (aDownloadItem.status == DemoDownloadItemStatusPaused)
    {
        [aProgressView setHidden:NO];
        aProgressView.progress = aDownloadItem.progress.downloadProgress;
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            anInfoTextLabel.text = aDownloadItem.progress.lastLocalizedAdditionalDescription;
        }
        else
        {
            anInfoTextLabel.text = [DownloadTableViewController displayStringForRemainingTime:aDownloadItem.progress.estimatedRemainingTime];
        }
    }
    else if (aDownloadItem.status == DemoDownloadItemStatusCancelled)
    {
        anInfoTextLabel.text = @"Cancelled";
    }
    else if (aDownloadItem.status == DemoDownloadItemStatusError)
    {
        if (aDownloadItem.downloadError)
        {
            anInfoTextLabel.text = aDownloadItem.downloadError.localizedDescription;
        }
        else
        {
            anInfoTextLabel.text = @"Error";
        }
    }
}


- (void)prepareDownloadCancelOrStateButton:(UIButton *)aButton forDemoDownloadItemStatus:(DemoDownloadItemStatus)aStatus
{
    NSString *aButtonTitle = [aButton titleForState:UIControlStateNormal];
    
    switch (aStatus) {
            
        case DemoDownloadItemStatusNotStarted:
            if ([aButtonTitle isEqualToString:self.downloadChar] == NO)
            {
                [aButton setEnabled:YES];
                [aButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
                [aButton addTarget:self action:@selector(onStartIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
                [aButton setTitle:self.downloadChar forState:UIControlStateNormal];
            }
            break;
            
        case DemoDownloadItemStatusStarted:
        case DemoDownloadItemStatusPaused:
            if ([aButtonTitle isEqualToString:self.cancelChar] == NO)
            {
                [aButton setEnabled:YES];
                [aButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
                [aButton addTarget:self action:@selector(onCancelIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
                [aButton setTitle:self.cancelChar forState:UIControlStateNormal];
            }
            break;
            
        case DemoDownloadItemStatusCompleted:
            if ([aButtonTitle isEqualToString:self.completedChar] == NO)
            {
                [aButton setEnabled:NO];
                [aButton setTitle:self.completedChar forState:UIControlStateNormal];
            }
            break;
            
        case DemoDownloadItemStatusCancelled:
            if ([aButtonTitle isEqualToString:self.cancelledChar] == NO)
            {
                [aButton setEnabled:NO];
                [aButton setTitle:self.cancelledChar forState:UIControlStateNormal];
            }
            break;
            
        case DemoDownloadItemStatusError:
            if ([aButtonTitle isEqualToString:self.errorChar] == NO)
            {
                [aButton setEnabled:NO];
                [aButton setTitle:self.errorChar forState:UIControlStateNormal];
            }
            break;
            
        default:
            NSLog(@"ERR: Invalid status %@ (%s, %d)", @(aStatus), __FILE__, __LINE__);
            break;
    }
}


- (void)preparePauseResumeButton:(UIButton *)aButton forDemoDownloadItemStatus:(DemoDownloadItemStatus)aStatus
{
    switch (aStatus) {
            
        case DemoDownloadItemStatusStarted:
        {
            NSString *aButtonTitle = [aButton titleForState:UIControlStateNormal];
            if ([aButtonTitle isEqualToString:self.pauseChar] == NO)
            {
                [aButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
                [aButton addTarget:self action:@selector(onPauseResumeIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
                [aButton setHidden:NO];
                [aButton setTitle:self.pauseChar forState:UIControlStateNormal];
            }
        }
            break;
            
        case DemoDownloadItemStatusPaused:
        {
            NSString *aButtonTitle = [aButton titleForState:UIControlStateNormal];
            if ([aButtonTitle isEqualToString:self.resumeChar] == NO)
            {
                [aButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
                [aButton addTarget:self action:@selector(onPauseResumeIndividualDownload:) forControlEvents:UIControlEventTouchUpInside];
                [aButton setHidden:NO];
                [aButton setTitle:self.resumeChar forState:UIControlStateNormal];
            }
        }
            break;
            
        default:
        {
            NSString *aButtonTitle = [aButton titleForState:UIControlStateNormal];
            if (aButtonTitle.length > 0)
            {
                [aButton setHidden:YES];
                [aButton setTitle:@"" forState:UIControlStateNormal];
            }
        }
            
            break;
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

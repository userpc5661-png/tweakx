%config(generator=internal);
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Security/Security.h>
#import <WebKit/WebKit.h>
#import <AVKit/AVKit.h>
#import <UserNotifications/UserNotifications.h>
#import "headers/RiseYTHeaders.h"

// ═══════════════════════════════════════════════════════
//  MARK: — AD BLOCKING
// ═══════════════════════════════════════════════════════

%hook YTMainAppAblateAdsCenter
- (BOOL)isAdFree { return YES; }
- (BOOL)areAdsEnabled { return NO; }
%end

%hook YTAdsInnerTubeContextDecoratorImpl
- (id)decorateContext:(id)ctx { return ctx; }
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (id)decorateContext:(id)ctx { return ctx; }
%end

%hook YTContentVideoPlayerResponseSlotOpportunityAdapterImpl
- (void)didReceiveResponse:(id)response { }
- (void)handleResponse:(id)response { }
%end

%hook YTThrottledAdBreakResponseSlotOpportunityAdapterImpl
- (void)didReceiveResponse:(id)response { }
%end

%hook YTAdSlotRegistrationAPIImpl
- (void)registerAdSlot:(id)slot { }
- (void)registerOpportunity:(id)opp { }
%end

%hook YTAdsControlFlowPlaybackCoordinator
- (void)startAdBreak:(id)adBreak { }
- (void)playAdBreak:(id)adBreak { }
- (BOOL)shouldShowAds { return NO; }
%end

%hook YTDAIAdsControlFlowPlaybackCoordinator
- (void)startAdBreak:(id)adBreak { }
- (BOOL)shouldShowAds { return NO; }
%end

%hook YTInstreamAdTrackingController
- (void)trackImpression:(id)imp { }
- (void)trackClick:(id)click { }
- (void)startTracking { }
%end

%hook YTPremiumAdsSeenEventLogger
- (void)logEvent:(id)event { }
%end

%hook YTAdCuepointEventCenter
- (void)fireCuepoint:(id)cp { }
- (void)broadcastCuepoint:(id)cp { }
%end

%hook YTAdElementsCellController
- (void)loadData:(id)data { }
%end

%hook YTAdElementsCellExternallyManagedSlotAdapterImpl
- (void)didReceiveResponse:(id)resp { }
%end

%hook YTPromotedVideoCellController
- (void)loadData:(id)data { }
%end

%hook YTCompactPromotedVideoCellController
- (void)loadData:(id)data { }
%end

%hook YTCompactPromotedItemCellController
- (void)loadData:(id)data { }
%end

%hook YTPlayerBytesSlotAdapter
- (void)didReceiveResponse:(id)resp { }
%end

%hook YTPlayerBytesSequenceItemExternallyManagedSlotAdapterImpl
- (void)didReceiveResponse:(id)resp { }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — PREMIUM ENABLER
// ═══════════════════════════════════════════════════════

%hook YTGlobalConfig
- (BOOL)isAdsEnabled { return NO; }
- (BOOL)isPremiumUser { return YES; }
- (BOOL)isYTPremium { return YES; }
- (BOOL)isYoutubePremium { return YES; }
- (BOOL)isBackgroundPlaybackEnabled { return YES; }
- (BOOL)isPictureInPictureEnabled { return YES; }
- (BOOL)isOfflineEnabled { return YES; }
%end

%hook YTColdConfig
- (BOOL)isPremiumUser { return YES; }
- (BOOL)isYTPremium { return YES; }
- (BOOL)isAdsEnabled { return NO; }
- (BOOL)isBackgroundPlaybackEnabled { return YES; }
- (BOOL)isOfflineEnabled { return YES; }
- (BOOL)isPictureInPictureEnabled { return YES; }
- (BOOL)isLiveChatEnabled { return YES; }
- (BOOL)isHD1080pEnabled { return YES; }
- (BOOL)is1440pEnabled { return YES; }
- (BOOL)is2160pEnabled { return YES; }
%end

%hook YTHotConfig
- (BOOL)isAdsEnabled { return NO; }
- (BOOL)isPremiumUser { return YES; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — BACKGROUND PLAYBACK
// ═══════════════════════════════════════════════════════

%hook YTBackgroundabilityPolicyImpl
- (BOOL)isBackgroundable { return YES; }
- (BOOL)canPlayInBackground { return YES; }
%end

%hook YTPlayerViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}
%end

%hook YTIPlayerViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:0
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — PICTURE IN PICTURE
// ═══════════════════════════════════════════════════════

%hook AVPictureInPictureController
+ (BOOL)isPictureInPictureSupported { return YES; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — LIQUID GLASS UI
// ═══════════════════════════════════════════════════════

static void applyLiquidGlass(UIView *view) {
    if (!view) return;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:blur];
    ev.frame = view.bounds;
    ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ev.alpha = 0.85f;
    ev.layer.cornerRadius = 18.0f;
    ev.clipsToBounds = YES;
    ev.layer.masksToBounds = YES;
    [view insertSubview:ev atIndex:0];

    view.layer.cornerRadius = 18.0f;
    view.layer.masksToBounds = YES;
    view.layer.borderWidth = 0.5f;
    view.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
}

%hook YTPivotBarView
- (void)didMoveToSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        applyLiquidGlass(self);
    });
}
%end

%hook YTFloatingPivotBarView
- (void)didMoveToSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        applyLiquidGlass(self);
    });
}
%end

%hook YTFrostedGlassView
- (void)didMoveToSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.cornerRadius = 14.0f;
        self.layer.masksToBounds = YES;
    });
}
%end

%hook YTTabBarViewController
- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        applyLiquidGlass(self.view);
    });
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOAD MANAGER IMPLEMENTATION
// ═══════════════════════════════════════════════════════

@interface RiseYT_DownloadManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RiseYTDownloadTask *> *activeTasks;
@property (nonatomic, strong) NSMutableArray<RiseYTDownloadTask *> *taskQueue;
@end

@implementation RiseYTDownloadTask
@end

@implementation RiseYT_DownloadManager

+ (instancetype)sharedManager {
    static RiseYT_DownloadManager *inst = nil;
    static dispatch_once_t tok;
    dispatch_once(&tok, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.riseyt.downloads"];
        cfg.discretionary = NO;
        cfg.sessionSendsLaunchEvents = YES;
        _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
        _activeTasks = [NSMutableDictionary new];
        _taskQueue = [NSMutableArray new];
    }
    return self;
}

- (NSString *)downloadsDirectory {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [docs stringByAppendingPathComponent:@"RiseYTDownloads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (void)addDownloadWithURL:(NSURL *)url title:(NSString *)title quality:(NSString *)quality {
    RiseYTDownloadTask *task = [[RiseYTDownloadTask alloc] init];
    task.url = url;
    task.title = title ?: @"Untitled";
    task.quality = quality ?: @"720p";
    task.progress = 0.0f;
    task.isPaused = NO;
    task.isCompleted = NO;

    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    task.sessionTask = [_session downloadTaskWithRequest:req];

    NSString *key = [url absoluteString];
    _activeTasks[key] = task;
    [_taskQueue addObject:task];
    [task.sessionTask resume];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"RiseYTDownloadStarted" object:task];
}

- (void)pauseDownload:(RiseYTDownloadTask *)task {
    task.isPaused = YES;
    [task.sessionTask cancelByProducingResumeData:^(NSData *resumeData) {
        if (resumeData) {
            task.resumeData = resumeData;
        }
    }];
}

- (void)resumeDownload:(RiseYTDownloadTask *)task {
    if (!task.resumeData) return;
    task.isPaused = NO;
    task.sessionTask = [_session downloadTaskWithResumeData:task.resumeData];
    [task.sessionTask resume];
}

- (void)cancelDownload:(RiseYTDownloadTask *)task {
    [task.sessionTask cancel];
    NSString *key = [task.url absoluteString];
    [_activeTasks removeObjectForKey:key];
    [_taskQueue removeObject:task];
}

- (NSArray<RiseYTDownloadTask *> *)allDownloads {
    return [_taskQueue copy];
}

- (void)cancelDownloadAtIndex:(NSUInteger)index {
    if (index >= _taskQueue.count) return;
    [self cancelDownload:_taskQueue[index]];
}
- (void)pauseDownloadAtIndex:(NSUInteger)index {
    if (index >= _taskQueue.count) return;
    [self pauseDownload:_taskQueue[index]];
}
- (void)resumeDownloadAtIndex:(NSUInteger)index {
    if (index >= _taskQueue.count) return;
    [self resumeDownload:_taskQueue[index]];
}
- (NSArray *)activeDownloads {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(RiseYTDownloadTask *task, NSDictionary *bindings) {
        return !task.isCompleted;
    }];
    return [_taskQueue filteredArrayUsingPredicate:predicate];
}
- (NSArray *)completedDownloads {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(RiseYTDownloadTask *task, NSDictionary *bindings) {
        return task.isCompleted;
    }];
    return [_taskQueue filteredArrayUsingPredicate:predicate];
}
- (NSString *)downloadDirectory {
    return [self downloadsDirectory];
}

// NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *key = [downloadTask.originalRequest.URL absoluteString];
    RiseYTDownloadTask *task = _activeTasks[key];
    if (!task) return;

    NSString *fileName = [NSString stringWithFormat:@"%@_%@.mp4", task.title, task.quality];
    NSString *destPath = [[self downloadsDirectory] stringByAppendingPathComponent:fileName];
    NSURL *destURL = [NSURL fileURLWithPath:destPath];

    NSError *err;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&err];

    task.isCompleted = YES;
    task.localPath = destPath;

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:destURL];
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RiseYTDownloadCompleted" object:task];
            UNMutableNotificationContent *content = [UNMutableNotificationContent new];
            content.title = @"RiseYT";
            content.body = [NSString stringWithFormat:@"Downloaded: %@", task.title];
            content.sound = UNNotificationSound.defaultSound;
            UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString] content:content trigger:nil];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:req withCompletionHandler:nil];
        });
    }];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSString *key = [downloadTask.originalRequest.URL absoluteString];
    RiseYTDownloadTask *task = _activeTasks[key];
    if (!task || totalBytesExpectedToWrite <= 0) return;
    task.progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RiseYTDownloadProgress" object:task];
    });
}

@end

// ═══════════════════════════════════════════════════════
//  MARK: — HLS DOWNLOAD
// ═══════════════════════════════════════════════════════

@implementation RiseYTHLSDownload

- (instancetype)initWithHLSURL:(NSString *)url title:(NSString *)title quality:(NSString *)quality {
    self = [super init];
    if (self) {
        self.hlsURL = url;
        self.title = title;
        self.quality = quality;
    }
    return self;
}
- (void)startDownload {
    if (!self.hlsURL || !self.title) return;
    NSURL *url = [NSURL URLWithString:self.hlsURL];
    [[RiseYT_DownloadManager sharedManager] addDownloadWithURL:url title:self.title quality:self.quality ?: @"HLS"];
}

@end

// ═══════════════════════════════════════════════════════
//  MARK: — QUALITY SHEET
// ═══════════════════════════════════════════════════════

@implementation RiseYTQualitySheet
+ (void)presentWithOptions:(NSArray<RiseYTQualityOption *> *)options
            fromController:(UIViewController *)controller
               completion:(void (^)(RiseYTQualityOption *selected))completion {
    if (!controller) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Download quality"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (RiseYTQualityOption *option in options) {
        [sheet addAction:[UIAlertAction actionWithTitle:option.label ?: @"Quality"
            style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                if (completion) completion(option);
            }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = controller.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(controller.view.bounds), CGRectGetMidY(controller.view.bounds), 1, 1);
    }
    [controller presentViewController:sheet animated:YES completion:nil];
}

- (instancetype)initWithVideoID:(NSString *)videoID title:(NSString *)title completion:(void(^)(NSString *quality, NSString *url))completion {
    self = [super init];
    if (self) {
        _videoID = [videoID copy];
        _videoTitle = [title copy];
        _completion = [completion copy];
        _qualities = @[
            [RiseYTQualityOption optionWithLabel:@"4K (2160p)" itag:@"337" resolution:@"3840x2160"],
            [RiseYTQualityOption optionWithLabel:@"1440p" itag:@"264" resolution:@"2560x1440"],
            [RiseYTQualityOption optionWithLabel:@"1080p HD" itag:@"137" resolution:@"1920x1080"],
            [RiseYTQualityOption optionWithLabel:@"720p HD" itag:@"136" resolution:@"1280x720"],
            [RiseYTQualityOption optionWithLabel:@"480p" itag:@"135" resolution:@"854x480"],
            [RiseYTQualityOption optionWithLabel:@"360p" itag:@"134" resolution:@"640x360"],
            [RiseYTQualityOption optionWithLabel:@"240p" itag:@"133" resolution:@"426x240"],
            [RiseYTQualityOption optionWithLabel:@"144p" itag:@"160" resolution:@"256x144"],
            [RiseYTQualityOption optionWithLabel:@"Audio Only (M4A)" itag:@"140" resolution:@"audio"],
        ];
    }
    return self;
}

- (void)presentFromViewController:(UIViewController *)vc {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"RiseYT — Download"
                                                                   message:_videoTitle
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (RiseYTQualityOption *opt in _qualities) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:opt.label style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if (_completion) _completion(opt.label, opt.itag);
        }];
        [sheet addAction:action];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [sheet addAction:cancel];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = vc.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width/2, vc.view.bounds.size.height, 1, 1);
    }
    [vc presentViewController:sheet animated:YES completion:nil];
}

@end

@implementation RiseYTQualityOption
- (instancetype)initWithLabel:(NSString *)label url:(NSString *)url bitrate:(NSInteger)bitrate {
    self = [super init];
    if (self) {
        self.label = label;
        self.url = url;
        self.bitrate = bitrate;
    }
    return self;
}
+ (instancetype)optionWithLabel:(NSString *)label itag:(NSString *)itag resolution:(NSString *)resolution {
    RiseYTQualityOption *o = [self new];
    o.label = label;
    o.itag = itag;
    o.resolution = resolution;
    return o;
}
@end

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOAD BUTTON HOOK (Player)
// ═══════════════════════════════════════════════════════

%hook YTWatchNextResultsViewController
- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self riseyt_addDownloadButton];
    });
}

%new
- (void)riseyt_addDownloadButton {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
    [btn setImage:img forState:UIControlStateNormal];
    btn.tintColor = [UIColor whiteColor];
    btn.frame = CGRectMake(0, 0, 44, 44);
    [btn addTarget:self action:@selector(riseyt_downloadTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:btn];
    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray new];
    [items insertObject:item atIndex:0];
    self.navigationItem.rightBarButtonItems = items;
}

%new
- (void)riseyt_downloadTapped:(id)sender {
    NSString *videoID = [self riseyt_currentVideoID];
    NSString *title = [self riseyt_currentVideoTitle];
    if (!videoID) return;

    RiseYTQualitySheet *sheet = [[RiseYTQualitySheet alloc] initWithVideoID:videoID title:title completion:^(NSString *quality, NSString *itag) {
        NSString *urlStr = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", videoID];
        NSURL *url = [NSURL URLWithString:urlStr];
        [[RiseYT_DownloadManager sharedManager] addDownloadWithURL:url title:title quality:quality];
    }];
    [sheet presentFromViewController:self];
}

%new
- (NSString *)riseyt_currentVideoID {
    @try {
        return [self valueForKeyPath:@"videoID"];
    } @catch (...) { return nil; }
}

%new
- (NSString *)riseyt_currentVideoTitle {
    @try {
        return [self valueForKeyPath:@"videoTitle"];
    } @catch (...) { return @"Video"; }
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOADS VIEW CONTROLLER
// ═══════════════════════════════════════════════════════

@interface RiseYTDownloadsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<RiseYTDownloadTask *> *downloads;
@end

@implementation RiseYTDownloadsViewController
+ (instancetype)sharedController {
    static RiseYTDownloadsViewController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ controller = [RiseYTDownloadsViewController new]; });
    return controller;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RiseYT Downloads";
    self.view.backgroundColor = [UIColor blackColor];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor blackColor];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:@"RiseYTDownloadProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:@"RiseYTDownloadCompleted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:@"RiseYTDownloadStarted" object:nil];
    [self reloadData];
}

- (void)reloadData {
    _downloads = [[RiseYT_DownloadManager sharedManager] allDownloads];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_tableView reloadData];
    });
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return _downloads.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_downloads.count == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"No downloads yet";
        cell.textLabel.textColor = [UIColor grayColor];
        cell.backgroundColor = [UIColor clearColor];
        return cell;
    }

    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"RiseYTCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RiseYTCell"];

    RiseYTDownloadTask *task = _downloads[indexPath.row];
    cell.textLabel.text = task.title;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (task.isCompleted) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"✅ %@ — Saved", task.quality];
        cell.detailTextLabel.textColor = [UIColor systemGreenColor];
    } else if (task.isPaused) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"⏸ %@ — Paused (%.0f%%)", task.quality, task.progress * 100];
        cell.detailTextLabel.textColor = [UIColor systemYellowColor];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"⬇️ %@ — %.0f%%", task.quality, task.progress * 100];
        cell.detailTextLabel.textColor = [UIColor systemBlueColor];
    }

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_downloads.count == 0) return;
    RiseYTDownloadTask *task = _downloads[indexPath.row];
    if (task.isCompleted && task.localPath) {
        NSURL *url = [NSURL fileURLWithPath:task.localPath];
        UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        [self presentViewController:avc animated:YES completion:nil];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tv trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_downloads.count == 0) return nil;
    RiseYTDownloadTask *task = _downloads[indexPath.row];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Cancel" handler:^(UIContextualAction *a, UIView *v, void(^c)(BOOL)){
        [[RiseYT_DownloadManager sharedManager] cancelDownload:task];
        [self reloadData];
        c(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end

// ═══════════════════════════════════════════════════════
//  MARK: — SETTINGS PANEL
// ═══════════════════════════════════════════════════════

static NSString * const kRiseYTPrefsKey = @"com.riseyt.prefs";

static NSMutableDictionary *riseyt_prefs() {
    static NSMutableDictionary *p = nil;
    if (!p) {
        NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kRiseYTPrefsKey];
        p = stored ? [stored mutableCopy] : [NSMutableDictionary new];
        // defaults
        if (!p[@"riseyt_premium_enabled"])    p[@"riseyt_premium_enabled"]    = @YES;
        if (!p[@"riseyt_adblock_enabled"])    p[@"riseyt_adblock_enabled"]    = @YES;
        if (!p[@"riseyt_bgplay_enabled"])     p[@"riseyt_bgplay_enabled"]     = @YES;
        if (!p[@"riseyt_pip_enabled"])        p[@"riseyt_pip_enabled"]        = @YES;
        if (!p[@"riseyt_hq_enabled"])         p[@"riseyt_hq_enabled"]         = @YES;
        if (!p[@"riseyt_liquid_glass"])       p[@"riseyt_liquid_glass"]       = @YES;
        if (!p[@"riseyt_save_photos"])        p[@"riseyt_save_photos"]        = @YES;
    }
    return p;
}

static void riseyt_savePrefs() {
    [[NSUserDefaults standardUserDefaults] setObject:riseyt_prefs() forKey:kRiseYTPrefsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static BOOL riseyt_pref(NSString *key) {
    return [riseyt_prefs()[key] boolValue];
}

%hook YTSettingsViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    [self riseyt_injectSettings];
}

%new
- (void)riseyt_injectSettings {
    @try {
        // Build RiseYT settings section items
        NSMutableArray *items = [NSMutableArray new];

        // Premium toggle
        YTSettingsSectionItem *premItem = [%c(YTSettingsSectionItem) checkboxItemWithTitle:@"🎖️ Premium Features"
                                                                               titleDescription:@"Enable premium account simulation"
                                                                                  accessibilityIdentifier:@"riseyt_premium"
                                                                                        switchOn:riseyt_pref(@"riseyt_premium_enabled")
                                                                                  switchBlock:^(id c, BOOL on) {
            riseyt_prefs()[@"riseyt_premium_enabled"] = @(on);
            riseyt_savePrefs();
        }];
        if (premItem) [items addObject:premItem];

        // Ad block toggle
        YTSettingsSectionItem *adItem = [%c(YTSettingsSectionItem) checkboxItemWithTitle:@"🚫 Block Ads"
                                                                              titleDescription:@"Remove all ads from YouTube"
                                                                                 accessibilityIdentifier:@"riseyt_adblock"
                                                                                       switchOn:riseyt_pref(@"riseyt_adblock_enabled")
                                                                                 switchBlock:^(id c, BOOL on) {
            riseyt_prefs()[@"riseyt_adblock_enabled"] = @(on);
            riseyt_savePrefs();
        }];
        if (adItem) [items addObject:adItem];

        // Background play
        YTSettingsSectionItem *bgItem = [%c(YTSettingsSectionItem) checkboxItemWithTitle:@"🎵 Background Playback"
                                                                               titleDescription:@"Play audio when app is in background"
                                                                                  accessibilityIdentifier:@"riseyt_bgplay"
                                                                                        switchOn:riseyt_pref(@"riseyt_bgplay_enabled")
                                                                                  switchBlock:^(id c, BOOL on) {
            riseyt_prefs()[@"riseyt_bgplay_enabled"] = @(on);
            riseyt_savePrefs();
        }];
        if (bgItem) [items addObject:bgItem];

        // PiP
        YTSettingsSectionItem *pipItem = [%c(YTSettingsSectionItem) checkboxItemWithTitle:@"🖼️ Picture in Picture"
                                                                                titleDescription:@"Enable PiP for all videos"
                                                                                   accessibilityIdentifier:@"riseyt_pip"
                                                                                         switchOn:riseyt_pref(@"riseyt_pip_enabled")
                                                                                   switchBlock:^(id c, BOOL on) {
            riseyt_prefs()[@"riseyt_pip_enabled"] = @(on);
            riseyt_savePrefs();
        }];
        if (pipItem) [items addObject:pipItem];

        // Liquid Glass UI
        YTSettingsSectionItem *glassItem = [%c(YTSettingsSectionItem) checkboxItemWithTitle:@"💎 Liquid Glass UI"
                                                                                  titleDescription:@"Apply frosted glass effect to navigation"
                                                                                     accessibilityIdentifier:@"riseyt_glass"
                                                                                           switchOn:riseyt_pref(@"riseyt_liquid_glass")
                                                                                     switchBlock:^(id c, BOOL on) {
            riseyt_prefs()[@"riseyt_liquid_glass"] = @(on);
            riseyt_savePrefs();
        }];
        if (glassItem) [items addObject:glassItem];

        // Downloads VC button
        YTSettingsSectionItem *dlItem = [%c(YTSettingsSectionItem) itemWithTitle:@"📥 My Downloads"
                                                                      titleDescription:@"View downloaded videos"
                                                                   accessibilityIdentifier:@"riseyt_downloads"
                                                                           detailText:nil
                                                                       selectBlock:^(id c, NSIndexPath *ip) {
            RiseYTDownloadsViewController *dlVC = [RiseYTDownloadsViewController new];
            dlVC.modalPresentationStyle = UIModalPresentationFormSheet;
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dlVC];
            nav.navigationBar.barStyle = UIBarStyleBlack;
            nav.navigationBar.translucent = YES;
            [self presentViewController:nav animated:YES completion:nil];
        }];
        if (dlItem) [items addObject:dlItem];

        // Version info
        YTSettingsSectionItem *verItem = [%c(YTSettingsSectionItem) itemWithTitle:@"RiseYT v1.3.4"
                                                                       titleDescription:@"Enhanced YouTube experience"
                                                                    accessibilityIdentifier:@"riseyt_version"
                                                                            detailText:@"riseyt.dev"
                                                                        selectBlock:nil];
        if (verItem) [items addObject:verItem];

        if (items.count > 0) {
            [self setSectionItems:items forCategory:999 title:@"🌟 RiseYT"];
            [self reloadData];
        }
    } @catch (NSException *e) {
        NSLog(@"[RiseYT] Settings injection error: %@", e);
    }
}

%end

// ═══════════════════════════════════════════════════════
//  MARK: — HIGH QUALITY THUMBNAILS
// ═══════════════════════════════════════════════════════

%hook YTThumbnailView
- (void)setImageURL:(NSURL *)url {
    if (!url) { %orig(url); return; }
    NSString *str = url.absoluteString;
    // Replace low-res thumbnail with maxresdefault
    for (NSString *suffix in @[@"mqdefault", @"hqdefault", @"sddefault", @"default"]) {
        if ([str containsString:suffix]) {
            str = [str stringByReplacingOccurrencesOfString:suffix withString:@"maxresdefault"];
            url = [NSURL URLWithString:str];
            break;
        }
    }
    %orig(url);
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — OPEN LINKS IN APP (no browser redirect)
// ═══════════════════════════════════════════════════════

%hook YTIAppCommandHandlerImpl
- (void)openURL:(NSURL *)url options:(NSDictionary *)opts completionHandler:(void(^)(BOOL))completion {
    NSString *host = url.host;
    if ([host containsString:@"youtube.com"] || [host containsString:@"youtu.be"] || [host containsString:@"googlevideo.com"]) {
        %orig(url, opts, completion);
    } else {
        %orig(url, opts, completion);
    }
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — SHORTS: SHOW DISLIKE COUNT (SponsorBlock style)
// ═══════════════════════════════════════════════════════

%hook YTShortsPlayerViewController
- (void)viewDidLoad {
    %orig;
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — NO AUTOPLAY OVERLAY
// ═══════════════════════════════════════════════════════

%hook YTAutonavEndscreenViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    // dismiss autoplay countdown
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:NO completion:nil];
    });
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — RETURN YOUTUBE DISLIKE (UI injection)
// ═══════════════════════════════════════════════════════

%hook YTVideoActionBarView
- (void)didMoveToSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.backgroundColor = [UIColor clearColor];
    });
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — FORCE HIGHEST QUALITY DEFAULT
// ═══════════════════════════════════════════════════════

%hook YTPlaybackQualitySettingViewController
- (NSInteger)selectedQuality {
    return 2160; // 4K
}
%end

%hook YTPlaybackResolutionVariantInfo
- (NSInteger)height {
    return MAX(%orig, 1080);
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — CASTBAR GLASS EFFECT
// ═══════════════════════════════════════════════════════

%hook YTCastDeviceView
- (void)didMoveToSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.cornerRadius = 12.0f;
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    });
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — CTOR
// ═══════════════════════════════════════════════════════

%ctor {
    NSLog(@"[RiseYT] v1.3.4 — Loaded ✅");
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                      completionHandler:^(BOOL granted, NSError *error) {
        if (error) NSLog(@"[RiseYT] Notification authorization failed: %@", error);
    }];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    %init;
}

%dtor {
    NSLog(@"[RiseYT] Unloaded");
}

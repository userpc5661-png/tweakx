%config(generator=internal);
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Photos/Photos.h>
#import <AVKit/AVKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "headers/RiseYTHeaders.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define RISEYT_VERSION @"1.4.0"

// RiseYT palette: black, white and yellow.
#define RY_YELLOW [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1.0]
#define RY_BLACK  [UIColor colorWithWhite:0.0 alpha:1.0]
#define RY_CARD   [UIColor colorWithWhite:0.12 alpha:1.0]
#define RY_WHITE  [UIColor whiteColor]
#define RY_MUTED  [UIColor colorWithWhite:0.62 alpha:1.0]

// ═══════════════════════════════════════════════════════
//  MARK: — PREFERENCES
//  Every hook below reads these flags at call time, so a
//  switch in the RiseYT settings section takes effect at
//  once (Liquid Glass needs an app restart).
// ═══════════════════════════════════════════════════════

typedef NS_ENUM(NSUInteger, RiseYTPref) {
    RYAdBlock = 0,
    RYPremium,
    RYBackground,
    RYPiP,
    RYHighRes,
    RYGlass,
    RYThumbs,
    RYHideEndscreen,
    RYDownloadButton,
    RYSavePhotos,
    RYPrefCount
};

static NSString * const kRiseYTPrefsKey = @"com.riseyt.prefs";
static BOOL gPrefs[RYPrefCount];

static NSString *riseyt_prefKey(RiseYTPref pref) {
    switch (pref) {
        case RYAdBlock:        return @"riseyt_adblock_enabled";
        case RYPremium:        return @"riseyt_premium_enabled";
        case RYBackground:     return @"riseyt_bgplay_enabled";
        case RYPiP:            return @"riseyt_pip_enabled";
        case RYHighRes:        return @"riseyt_hq_enabled";
        case RYGlass:          return @"riseyt_liquid_glass";
        case RYThumbs:         return @"riseyt_hq_thumbnails";
        case RYHideEndscreen:  return @"riseyt_hide_endscreen";
        case RYDownloadButton: return @"riseyt_download_button";
        case RYSavePhotos:     return @"riseyt_save_photos";
        default:               return @"riseyt_unknown";
    }
}

static void riseyt_loadPrefs(void) {
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kRiseYTPrefsKey];
    for (NSUInteger i = 0; i < RYPrefCount; i++) {
        id value = stored[riseyt_prefKey((RiseYTPref)i)];
        gPrefs[i] = value ? [value boolValue] : YES;
    }
}

static void riseyt_setPref(RiseYTPref pref, BOOL on) {
    if (pref >= RYPrefCount) return;
    gPrefs[pref] = on;
    NSMutableDictionary *dict = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < RYPrefCount; i++) dict[riseyt_prefKey((RiseYTPref)i)] = @(gPrefs[i]);
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kRiseYTPrefsKey];
}

#define PREF(p) (gPrefs[(p)])

// ═══════════════════════════════════════════════════════
//  MARK: — HELPERS
// ═══════════════════════════════════════════════════════

static id riseyt_kvc(id obj, NSString *key) {
    if (!obj || !key) return nil;
    if ([obj isKindOfClass:[NSDictionary class]]) return ((NSDictionary *)obj)[key];
    @try { return [obj valueForKey:key]; }
    @catch (__unused NSException *e) { return nil; }
}

static NSString *riseyt_str(id obj, NSString *key) {
    id value = riseyt_kvc(obj, key);
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL riseyt_boolSel(id obj, NSString *selName) {
    SEL sel = NSSelectorFromString(selName);
    if (!obj || ![obj respondsToSelector:sel]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
}

static UIViewController *riseyt_topViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
        if (window) break;
    }
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        vc = vc.presentedViewController;
    }
    return vc;
}


static void riseyt_postOnMain(NSString *name, id object) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:object];
    });
}

static void riseyt_notify(NSString *body) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    // Permission is requested lazily, the first time a download finishes,
    // instead of at app launch.
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, __unused NSError *error) {
        if (!granted) return;
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = @"RiseYT";
        content.body = body ?: @"";
        content.sound = [UNNotificationSound defaultSound];
        UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                          content:content
                                                                          trigger:nil];
        [center addNotificationRequest:req withCompletionHandler:nil];
    }];
}

static __weak UIViewController *riseyt_currentPlayer = nil;

// ═══════════════════════════════════════════════════════
//  MARK: — AD BLOCKING  (switch: Block Ads)
// ═══════════════════════════════════════════════════════

static void riseyt_stripPromotedSections(id model) {
    @try {
        Class rendererClass = objc_getClass("YTISectionListRenderer");
        if (!rendererClass || ![model isKindOfClass:rendererClass]) return;
        NSMutableArray *contents = riseyt_kvc(model, @"contentsArray");
        if (![contents isKindOfClass:[NSMutableArray class]]) return;
        NSIndexSet *remove = [contents indexesOfObjectsPassingTest:^BOOL(id renderers, __unused NSUInteger idx, __unused BOOL *stop) {
            id section = riseyt_kvc(renderers, @"itemSectionRenderer");
            NSArray *items = riseyt_kvc(section, @"contentsArray");
            id first = [items isKindOfClass:[NSArray class]] ? items.firstObject : nil;
            if (!first) return NO;
            return riseyt_boolSel(first, @"hasPromotedVideoRenderer")
                || riseyt_boolSel(first, @"hasCompactPromotedVideoRenderer")
                || riseyt_boolSel(first, @"hasPromotedVideoInlineMutedRenderer");
        }];
        if (remove.count) [contents removeObjectsAtIndexes:remove];
    } @catch (__unused NSException *e) {}
}

%hook YTIPlayerResponse
- (BOOL)isMonetized { return PREF(RYAdBlock) ? NO : %orig; }
%end

%hook YTSectionListViewController
- (void)loadWithModel:(id)model {
    if (PREF(RYAdBlock)) riseyt_stripPromotedSections(model);
    %orig;
}
%end

%hook YTMainAppAblateAdsCenter
- (BOOL)isAdFree { return PREF(RYAdBlock) ? YES : %orig; }
- (BOOL)areAdsEnabled { return PREF(RYAdBlock) ? NO : %orig; }
%end

%hook YTAdsInnerTubeContextDecorator
- (id)decorateContext:(id)ctx { return PREF(RYAdBlock) ? ctx : %orig(ctx); }
%end

%hook YTAdsInnerTubeContextDecoratorImpl
- (id)decorateContext:(id)ctx { return PREF(RYAdBlock) ? ctx : %orig(ctx); }
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (id)decorateContext:(id)ctx { return PREF(RYAdBlock) ? ctx : %orig(ctx); }
%end

%hook YTContentVideoPlayerResponseSlotOpportunityAdapterImpl
- (void)didReceiveResponse:(id)response { if (!PREF(RYAdBlock)) %orig; }
- (void)handleResponse:(id)response { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTThrottledAdBreakResponseSlotOpportunityAdapterImpl
- (void)didReceiveResponse:(id)response { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTAdSlotRegistrationAPIImpl
- (void)registerAdSlot:(id)slot { if (!PREF(RYAdBlock)) %orig; }
- (void)registerOpportunity:(id)opp { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTAdsControlFlowPlaybackCoordinator
- (void)startAdBreak:(id)adBreak { if (!PREF(RYAdBlock)) %orig; }
- (void)playAdBreak:(id)adBreak { if (!PREF(RYAdBlock)) %orig; }
- (BOOL)shouldShowAds { return PREF(RYAdBlock) ? NO : %orig; }
%end

%hook YTDAIAdsControlFlowPlaybackCoordinator
- (void)startAdBreak:(id)adBreak { if (!PREF(RYAdBlock)) %orig; }
- (BOOL)shouldShowAds { return PREF(RYAdBlock) ? NO : %orig; }
%end

%hook YTInstreamAdTrackingController
- (void)trackImpression:(id)imp { if (!PREF(RYAdBlock)) %orig; }
- (void)trackClick:(id)click { if (!PREF(RYAdBlock)) %orig; }
- (void)startTracking { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTPremiumAdsSeenEventLogger
- (void)logEvent:(id)event { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTAdCuepointEventCenter
- (void)fireCuepoint:(id)cp { if (!PREF(RYAdBlock)) %orig; }
- (void)broadcastCuepoint:(id)cp { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTAdElementsCellController
- (void)loadData:(id)data { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTAdElementsCellExternallyManagedSlotAdapterImpl
- (void)didReceiveResponse:(id)resp { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTPromotedVideoCellController
- (void)loadData:(id)data { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTCompactPromotedVideoCellController
- (void)loadData:(id)data { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTCompactPromotedItemCellController
- (void)loadData:(id)data { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTPlayerBytesSlotAdapter
- (void)didReceiveResponse:(id)resp { if (!PREF(RYAdBlock)) %orig; }
%end

%hook YTPlayerBytesSequenceItemExternallyManagedSlotAdapterImpl
- (void)didReceiveResponse:(id)resp { if (!PREF(RYAdBlock)) %orig; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — CONFIG FLAGS
//  Each getter is tied to the switch it belongs to.
// ═══════════════════════════════════════════════════════

%hook YTGlobalConfig
- (BOOL)isAdsEnabled { return PREF(RYAdBlock) ? NO : %orig; }
- (BOOL)isPremiumUser { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isYTPremium { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isYoutubePremium { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isOfflineEnabled { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isBackgroundPlaybackEnabled { return PREF(RYBackground) ? YES : %orig; }
- (BOOL)isPictureInPictureEnabled { return PREF(RYPiP) ? YES : %orig; }
%end

%hook YTColdConfig
- (BOOL)isAdsEnabled { return PREF(RYAdBlock) ? NO : %orig; }
- (BOOL)isPremiumUser { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isYTPremium { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isOfflineEnabled { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isLiveChatEnabled { return PREF(RYPremium) ? YES : %orig; }
- (BOOL)isBackgroundPlaybackEnabled { return PREF(RYBackground) ? YES : %orig; }
- (BOOL)isPictureInPictureEnabled { return PREF(RYPiP) ? YES : %orig; }
- (BOOL)isHD1080pEnabled { return PREF(RYHighRes) ? YES : %orig; }
- (BOOL)is1440pEnabled { return PREF(RYHighRes) ? YES : %orig; }
- (BOOL)is2160pEnabled { return PREF(RYHighRes) ? YES : %orig; }
%end

%hook YTHotConfig
- (BOOL)isAdsEnabled { return PREF(RYAdBlock) ? NO : %orig; }
- (BOOL)isPremiumUser { return PREF(RYPremium) ? YES : %orig; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — BACKGROUND PLAYBACK  (switch: Background Playback)
//  The old version forced the audio session at launch and on
//  every player disappearance, which interrupted other apps'
//  audio. Playback eligibility is now unlocked through the
//  player's own policy objects instead.
// ═══════════════════════════════════════════════════════

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground { return PREF(RYBackground) ? YES : %orig; }
- (BOOL)isPlayableInPictureInPicture { return PREF(RYPiP) ? YES : %orig; }
%end

%hook MLVideo
- (BOOL)playableInBackground { return PREF(RYBackground) ? YES : %orig; }
%end

%hook YTBackgroundabilityPolicyImpl
- (BOOL)isBackgroundable { return PREF(RYBackground) ? YES : %orig; }
- (BOOL)canPlayInBackground { return PREF(RYBackground) ? YES : %orig; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — PICTURE IN PICTURE  (switch: Picture in Picture)
// ═══════════════════════════════════════════════════════

%hook AVPictureInPictureController
+ (BOOL)isPictureInPictureSupported { return PREF(RYPiP) ? YES : %orig; }
%end

// ═══════════════════════════════════════════════════════
//  MARK: — LIQUID GLASS UI  (switch: Liquid Glass, restart)
// ═══════════════════════════════════════════════════════

static const NSInteger kRiseYTGlassTag = 0x52595447;

static void riseyt_applyLiquidGlass(UIView *view) {
    if (!view || !PREF(RYGlass)) return;
    if ([view viewWithTag:kRiseYTGlassTag]) return; // didMoveToSuperview fires repeatedly
    UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    ev.tag = kRiseYTGlassTag;
    ev.frame = view.bounds;
    ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    ev.userInteractionEnabled = NO;
    ev.alpha = 0.85f;
    ev.layer.cornerRadius = 18.0f;
    ev.clipsToBounds = YES;
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
    if (!self.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{ riseyt_applyLiquidGlass(self); });
}
%end

%hook YTFloatingPivotBarView
- (void)didMoveToSuperview {
    %orig;
    if (!self.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{ riseyt_applyLiquidGlass(self); });
}
%end

%hook YTFrostedGlassView
- (void)didMoveToSuperview {
    %orig;
    if (!PREF(RYGlass) || !self.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.cornerRadius = 14.0f;
        self.layer.masksToBounds = YES;
    });
}
%end

%hook YTCastDeviceView
- (void)didMoveToSuperview {
    %orig;
    if (!PREF(RYGlass) || !self.superview) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.layer.cornerRadius = 12.0f;
        self.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    });
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — HIGH QUALITY THUMBNAILS  (switch: HQ Thumbnails)
//  Upgrades default/mqdefault to hqdefault, which exists for
//  every video. (maxresdefault is missing on many videos and
//  produced blank thumbnails; the old loop also turned an
//  existing "maxresdefault" into "maxresmaxresdefault".)
// ═══════════════════════════════════════════════════════

static NSURL *riseyt_upgradedThumbnailURL(NSURL *url) {
    if (!url || !PREF(RYThumbs)) return url;
    if (![url.host containsString:@"ytimg.com"]) return url;
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"/(default|mqdefault)\\.(jpg|webp)"
                                                          options:0 error:nil];
    });
    NSString *str = url.absoluteString;
    NSString *out = [regex stringByReplacingMatchesInString:str options:0
                                                      range:NSMakeRange(0, str.length)
                                               withTemplate:@"/hqdefault.$2"];
    if ([out isEqualToString:str]) return url;
    return [NSURL URLWithString:out] ?: url;
}

%hook YTThumbnailView
- (void)setImageURL:(NSURL *)url {
    %orig(riseyt_upgradedThumbnailURL(url));
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — HIDE AUTOPLAY ENDSCREEN  (switch: Hide Endscreen)
//  The old hook called dismissViewControllerAnimated: on a
//  child view controller, which UIKit forwards to the
//  presenter — it could close the whole watch page. Now the
//  overlay is simply hidden.
// ═══════════════════════════════════════════════════════

%hook YTAutonavEndscreenViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    self.view.hidden = PREF(RYHideEndscreen);
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOAD MODEL
// ═══════════════════════════════════════════════════════

@implementation RiseYTQualityOption
@end

@implementation RiseYTDownloadTask
- (BOOL)isCompleted { return self.state == RiseYTDownloadStateCompleted; }
- (BOOL)isPaused { return self.state == RiseYTDownloadStatePaused; }
- (void)updateProgress {
    int64_t expected = self.videoExpected + self.audioExpected;
    int64_t written = self.videoWritten + self.audioWritten;
    self.progress = expected > 0 ? (float)((double)written / (double)expected) : 0.0f;
}
@end

// ═══════════════════════════════════════════════════════
//  MARK: — STREAM DISCOVERY
//  Reads the stream list YouTube's own player already
//  fetched for the current video (player response →
//  streamingData). No separate page request, no HTML.
//  • Adaptive H.264 video + best AAC audio → merged to MP4
//  • Progressive MP4 (single file, has audio)
//  • Audio only → M4A
// ═══════════════════════════════════════════════════════

static NSURL *riseyt_streamURL(id format) {
    NSString *url = riseyt_str(format, @"url");
    return url.length ? [NSURL URLWithString:url] : nil;
}

// `data` is either a parsed player-response dictionary (network capture)
// or a YouTube model object exposing the same keys via KVC.
static NSArray<RiseYTQualityOption *> *riseyt_optionsFromPlayerData(id data, NSString *__autoreleasing *outTitle) {
    id streaming = riseyt_kvc(data, @"streamingData");

    NSString *title = riseyt_str(riseyt_kvc(data, @"videoDetails"), @"title");
    if (!title.length) title = @"YouTube video";
    if (outTitle) *outTitle = title;

    NSArray *progressive = riseyt_kvc(streaming, @"formatsArray") ?: riseyt_kvc(streaming, @"formats");
    NSArray *adaptive = riseyt_kvc(streaming, @"adaptiveFormatsArray") ?: riseyt_kvc(streaming, @"adaptiveFormats");
    if (![progressive isKindOfClass:[NSArray class]]) progressive = @[];
    if (![adaptive isKindOfClass:[NSArray class]]) adaptive = @[];

    NSURL *bestAudio = nil;
    long long bestAudioBitrate = -1;
    for (id f in adaptive) {
        NSString *mime = riseyt_str(f, @"mimeType");
        NSURL *url = riseyt_streamURL(f);
        if (!url || ![mime hasPrefix:@"audio/mp4"]) continue;
        long long br = [riseyt_kvc(f, @"bitrate") longLongValue];
        if (br > bestAudioBitrate) { bestAudioBitrate = br; bestAudio = url; }
    }

    NSMutableDictionary<NSNumber *, RiseYTQualityOption *> *byHeight = [NSMutableDictionary new];
    if (bestAudio) {
        for (id f in adaptive) {
            NSString *mime = riseyt_str(f, @"mimeType");
            NSURL *url = riseyt_streamURL(f);
            // H.264 in MP4 is what AVFoundation can merge without re-encoding.
            if (!url || ![mime hasPrefix:@"video/mp4"] || ![mime containsString:@"avc1"]) continue;
            NSInteger height = [riseyt_kvc(f, @"height") integerValue];
            if (height <= 0) continue;
            long long br = [riseyt_kvc(f, @"bitrate") longLongValue];
            RiseYTQualityOption *existing = byHeight[@(height)];
            if (existing && existing.bitrate >= br) continue;
            RiseYTQualityOption *opt = [RiseYTQualityOption new];
            NSString *q = riseyt_str(f, @"qualityLabel");
            opt.label = q.length ? q : [NSString stringWithFormat:@"%ldp", (long)height];
            opt.videoURL = url;
            opt.audioURL = bestAudio;
            opt.height = height;
            opt.bitrate = br;
            byHeight[@(height)] = opt;
        }
    }

    for (id f in progressive) {
        NSString *mime = riseyt_str(f, @"mimeType");
        NSURL *url = riseyt_streamURL(f);
        if (!url || ![mime hasPrefix:@"video/mp4"]) continue;
        NSInteger height = [riseyt_kvc(f, @"height") integerValue];
        if (height <= 0 || byHeight[@(height)]) continue;
        RiseYTQualityOption *opt = [RiseYTQualityOption new];
        NSString *q = riseyt_str(f, @"qualityLabel");
        opt.label = q.length ? q : [NSString stringWithFormat:@"%ldp", (long)height];
        opt.videoURL = url;
        opt.height = height;
        byHeight[@(height)] = opt;
    }

    NSMutableArray<RiseYTQualityOption *> *options = [[byHeight.allValues sortedArrayUsingComparator:
        ^NSComparisonResult(RiseYTQualityOption *a, RiseYTQualityOption *b) {
            if (a.height == b.height) return NSOrderedSame;
            return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        }] mutableCopy];

    if (bestAudio) {
        RiseYTQualityOption *audio = [RiseYTQualityOption new];
        audio.label = @"Audio only (M4A)";
        audio.audioURL = bestAudio;
        audio.audioOnly = YES;
        [options addObject:audio];
    }
    return options;
}

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOAD MANAGER
// ═══════════════════════════════════════════════════════

// Player responses captured from YouTube's own /youtubei/v1/player request.
// Reading the JSON from the network is independent of YouTube's internal
// object names, so it keeps working across app updates.
static NSObject *gPlayerLock;
static NSMutableDictionary<NSString *, NSDictionary *> *gPlayerJSON;

static void riseyt_initPlayerCache(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gPlayerLock = [NSObject new];
        gPlayerJSON = [NSMutableDictionary new];
    });
}

static void riseyt_capturePlayerJSON(NSData *data) {
    if (!data.length) return;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *root = json;
    if (![root[@"streamingData"] isKindOfClass:[NSDictionary class]]) return;
    id details = root[@"videoDetails"];
    NSString *videoID = [details isKindOfClass:[NSDictionary class]] ? details[@"videoId"] : nil;
    if (![videoID isKindOfClass:[NSString class]] || !videoID.length) return;
    riseyt_initPlayerCache();
    @synchronized (gPlayerLock) {
        if (gPlayerJSON.count > 20) [gPlayerJSON removeAllObjects];
        gPlayerJSON[videoID] = root;
    }
}

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (!handler || ![request.URL.absoluteString containsString:@"youtubei/v1/player"]) return %orig;
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        riseyt_capturePlayerJSON(data);
        handler(data, response, error);
    });
}
%end

// Uses the captured response for this exact video first, then YouTube's
// in-memory player model as a fallback.
static NSArray<RiseYTQualityOption *> *riseyt_optionsForPlayer(UIViewController *player,
                                                               NSString *__autoreleasing *outTitle,
                                                               NSString *__autoreleasing *outDebug) {
    NSString *videoID = nil;
    if ([player respondsToSelector:@selector(currentVideoID)]) videoID = [(YTPlayerViewController *)player currentVideoID];
    if (!videoID.length) videoID = riseyt_str(player, @"videoID");

    riseyt_initPlayerCache();
    NSDictionary *captured = nil;
    @synchronized (gPlayerLock) { captured = videoID.length ? gPlayerJSON[videoID] : nil; }

    NSArray<RiseYTQualityOption *> *options = captured ? riseyt_optionsFromPlayerData(captured, outTitle) : @[];
    BOOL usedFallback = NO;
    if (!options.count) {
        id response = riseyt_kvc(player, @"contentPlayerResponse") ?: riseyt_kvc(player, @"playerResponse");
        id data = riseyt_kvc(response, @"playerData");
        if (data) {
            usedFallback = YES;
            options = riseyt_optionsFromPlayerData(data, outTitle);
        }
    }
    if (outDebug) {
        *outDebug = [NSString stringWithFormat:@"video=%@ captured=%@ fallback=%@ options=%lu",
                     videoID ?: @"?", captured ? @"yes" : @"no", usedFallback ? @"yes" : @"no",
                     (unsigned long)options.count];
    }
    return options;
}

static NSString * const kRiseYTDownloadsChanged = @"RiseYTDownloadsChanged";

@interface RiseYT_DownloadManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray<RiseYTDownloadTask *> *tasks;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RiseYTDownloadTask *> *byTaskID;
@end

@implementation RiseYT_DownloadManager

+ (instancetype)sharedManager {
    static RiseYT_DownloadManager *inst = nil;
    static dispatch_once_t tok;
    dispatch_once(&tok, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _tasks = [NSMutableArray new];
        _byTaskID = [NSMutableDictionary new];
        NSURLSessionConfiguration *cfg =
            [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.riseyt.downloads"];
        cfg.discretionary = NO;
        cfg.sessionSendsLaunchEvents = NO;
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:queue];
        [self loadCompletedFromDisk];
    }
    return self;
}

- (NSString *)downloadsDirectory {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [docs stringByAppendingPathComponent:@"RiseYTDownloads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (NSString *)partsDirectory {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"RiseYTParts"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

- (void)loadCompletedFromDisk {
    NSString *dir = [self downloadsDirectory];
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *found = [NSMutableArray new];
    for (NSString *name in names) {
        NSString *ext = name.pathExtension.lowercaseString;
        if (![ext isEqualToString:@"mp4"] && ![ext isEqualToString:@"m4a"]) continue;
        NSString *path = [dir stringByAppendingPathComponent:name];
        NSDate *date = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil].fileModificationDate ?: [NSDate distantPast];
        RiseYTDownloadTask *t = [RiseYTDownloadTask new];
        t.identifier = [[NSUUID UUID] UUIDString];
        t.title = name.stringByDeletingPathExtension;
        t.quality = ext.uppercaseString;
        t.audioOnly = [ext isEqualToString:@"m4a"];
        t.localPath = path;
        t.progress = 1.0f;
        t.state = RiseYTDownloadStateCompleted;
        [found addObject:@[date, t]];
    }
    [found sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [b[0] compare:a[0]]; }];
    for (NSArray *pair in found) [_tasks addObject:pair[1]];
}

- (NSString *)uniquePathForTitle:(NSString *)title quality:(NSString *)quality ext:(NSString *)ext {
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:?*\"<>|\n\r\t"];
    NSString *clean = [[title componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"_"];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (clean.length > 80) clean = [clean substringToIndex:80];
    if (!clean.length) clean = @"video";
    NSString *base = quality.length ? [NSString stringWithFormat:@"%@ [%@]", clean, quality] : clean;
    NSString *dir = [self downloadsDirectory];
    NSString *path = [dir stringByAppendingPathComponent:[base stringByAppendingPathExtension:ext]];
    NSUInteger n = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *name = [NSString stringWithFormat:@"%@ (%lu)", base, (unsigned long)n++];
        path = [dir stringByAppendingPathComponent:[name stringByAppendingPathExtension:ext]];
    }
    return path;
}

#pragma mark Public API

- (NSArray<RiseYTDownloadTask *> *)allDownloads {
    @synchronized (self) { return [_tasks copy]; }
}

- (RiseYTDownloadTask *)startDownloadWithOption:(RiseYTQualityOption *)option title:(NSString *)title {
    if (!option) return nil;
    RiseYTDownloadTask *t = [RiseYTDownloadTask new];
    t.identifier = [[NSUUID UUID] UUIDString];
    t.title = title.length ? title : @"YouTube video";
    t.quality = option.label;
    t.audioOnly = option.audioOnly;
    t.videoURL = option.audioOnly ? nil : option.videoURL;
    t.audioURL = option.audioURL;
    t.state = RiseYTDownloadStateDownloading;
    @synchronized (self) {
        [_tasks insertObject:t atIndex:0];
        [self startPartsForTask:t];
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);
    return t;
}

- (void)pauseDownload:(RiseYTDownloadTask *)t {
    @synchronized (self) {
        if (t.state != RiseYTDownloadStateDownloading) return;
        t.state = RiseYTDownloadStatePaused;
        __weak RiseYTDownloadTask *weakTask = t;
        if (t.videoTask) {
            [t.videoTask cancelByProducingResumeData:^(NSData *data) {
                @synchronized (self) { weakTask.videoResumeData = data; }
            }];
        }
        if (t.audioTask) {
            [t.audioTask cancelByProducingResumeData:^(NSData *data) {
                @synchronized (self) { weakTask.audioResumeData = data; }
            }];
        }
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);
}

- (void)resumeDownload:(RiseYTDownloadTask *)t {
    @synchronized (self) {
        if (t.state != RiseYTDownloadStatePaused && t.state != RiseYTDownloadStateFailed) return;
        t.state = RiseYTDownloadStateDownloading;
        t.errorMessage = nil;
        [self startPartsForTask:t];
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);
}

- (void)removeDownload:(RiseYTDownloadTask *)t {
    @synchronized (self) {
        [t.videoTask cancel];
        [t.audioTask cancel];
        [self deletePartsForTask:t];
        if (t.isCompleted && t.localPath) [[NSFileManager defaultManager] removeItemAtPath:t.localPath error:nil];
        [_tasks removeObject:t];
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);
}

#pragma mark Internals (call with @synchronized(self) held)

- (void)startPartsForTask:(RiseYTDownloadTask *)t {
    if (t.videoURL && !t.videoFile) {
        t.videoTask = [self makeTaskWithURL:t.videoURL resumeData:t.videoResumeData];
        t.videoResumeData = nil;
        _byTaskID[@(t.videoTask.taskIdentifier)] = t;
        [t.videoTask resume];
    }
    if (t.audioURL && !t.audioFile) {
        t.audioTask = [self makeTaskWithURL:t.audioURL resumeData:t.audioResumeData];
        t.audioResumeData = nil;
        _byTaskID[@(t.audioTask.taskIdentifier)] = t;
        [t.audioTask resume];
    }
}

- (NSURLSessionDownloadTask *)makeTaskWithURL:(NSURL *)url resumeData:(NSData *)resumeData {
    NSURLSessionDownloadTask *task = nil;
    if (resumeData) task = [_session downloadTaskWithResumeData:resumeData];
    if (!task) task = [_session downloadTaskWithRequest:[NSURLRequest requestWithURL:url]];
    return task;
}

- (void)deletePartsForTask:(RiseYTDownloadTask *)t {
    if (t.videoFile) [[NSFileManager defaultManager] removeItemAtPath:t.videoFile error:nil];
    if (t.audioFile) [[NSFileManager defaultManager] removeItemAtPath:t.audioFile error:nil];
    t.videoFile = nil;
    t.audioFile = nil;
}

- (void)failTask:(RiseYTDownloadTask *)t message:(NSString *)message {
    @synchronized (self) {
        if (![_tasks containsObject:t] || t.state == RiseYTDownloadStateFailed) return;
        t.state = RiseYTDownloadStateFailed;
        t.errorMessage = message;
        [t.videoTask cancel];
        [t.audioTask cancel];
        t.videoTask = nil;
        t.audioTask = nil;
        [self deletePartsForTask:t];
        t.videoWritten = t.audioWritten = 0;
        [t updateProgress];
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);
}

- (void)finalizeTask:(RiseYTDownloadTask *)t {
    NSString *ext = t.audioOnly ? @"m4a" : @"mp4";
    NSString *dest;
    @synchronized (self) {
        t.state = RiseYTDownloadStateMerging;
        dest = [self uniquePathForTitle:t.title quality:t.quality ext:ext];
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);

    NSString *single = t.audioOnly ? t.audioFile : (t.audioURL ? nil : t.videoFile);
    if (single) {
        NSError *err = nil;
        if ([[NSFileManager defaultManager] moveItemAtPath:single toPath:dest error:&err]) {
            [self completeTask:t path:dest];
        } else {
            [self failTask:t message:err.localizedDescription ?: @"Could not save the file"];
        }
        return;
    }
    [self mergeVideo:t.videoFile audio:t.audioFile to:dest completion:^(NSError *error) {
        if (error) [self failTask:t message:error.localizedDescription ?: @"Merge failed"];
        else [self completeTask:t path:dest];
    }];
}

- (void)mergeVideo:(NSString *)videoPath audio:(NSString *)audioPath to:(NSString *)dest completion:(void (^)(NSError *))completion {
    NSError *(^makeError)(NSString *) = ^NSError *(NSString *msg) {
        return [NSError errorWithDomain:@"RiseYT" code:1 userInfo:@{NSLocalizedDescriptionKey: msg}];
    };
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    AVAssetTrack *audioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    if (!videoTrack) { completion(makeError(@"Downloaded video stream is unreadable")); return; }

    AVMutableComposition *comp = [AVMutableComposition composition];
    NSError *err = nil;
    CMTime duration = videoAsset.duration;
    AVMutableCompositionTrack *cv = [comp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    if (![cv insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&err]) {
        completion(err ?: makeError(@"Could not read the video track"));
        return;
    }
    cv.preferredTransform = videoTrack.preferredTransform;
    if (audioTrack) {
        CMTime audioDuration = CMTimeMinimum(audioAsset.duration, duration);
        AVMutableCompositionTrack *ca = [comp addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [ca insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:comp presetName:AVAssetExportPresetPassthrough];
    if (!exporter) { completion(makeError(@"Could not start merging")); return; }
    exporter.outputURL = [NSURL fileURLWithPath:dest];
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        if (exporter.status == AVAssetExportSessionStatusCompleted) completion(nil);
        else completion(exporter.error ?: makeError(@"Merge failed"));
    }];
}

- (void)completeTask:(RiseYTDownloadTask *)t path:(NSString *)path {
    @synchronized (self) {
        [self deletePartsForTask:t];
        t.localPath = path;
        t.progress = 1.0f;
        t.state = RiseYTDownloadStateCompleted;
        t.videoTask = nil;
        t.audioTask = nil;
    }
    riseyt_postOnMain(kRiseYTDownloadsChanged, t);

    if (!t.audioOnly && PREF(RYSavePhotos) && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
        NSURL *fileURL = [NSURL fileURLWithPath:path];
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) return;
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            } completionHandler:nil];
        }];
    }
    riseyt_notify([NSString stringWithFormat:@"Downloaded: %@", t.title]);
}

#pragma mark NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)dt
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)written totalBytesExpectedToWrite:(int64_t)expected {
    RiseYTDownloadTask *t;
    BOOL post = NO;
    @synchronized (self) {
        t = _byTaskID[@(dt.taskIdentifier)];
        if (!t) return;
        if (dt == t.videoTask) { t.videoWritten = written; if (expected > 0) t.videoExpected = expected; }
        else { t.audioWritten = written; if (expected > 0) t.audioExpected = expected; }
        [t updateProgress];
        if (fabsf(t.progress - t.lastPostedProgress) >= 0.01f) { t.lastPostedProgress = t.progress; post = YES; }
    }
    if (post) riseyt_postOnMain(kRiseYTDownloadsChanged, t);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)dt didFinishDownloadingToURL:(NSURL *)location {
    RiseYTDownloadTask *t;
    @synchronized (self) { t = _byTaskID[@(dt.taskIdentifier)]; }
    if (!t) return;

    NSHTTPURLResponse *http = [dt.response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)dt.response : nil;
    if (http && (http.statusCode < 200 || http.statusCode >= 300)) {
        [self failTask:t message:[NSString stringWithFormat:@"Server returned HTTP %ld — the stream link may have expired; open the video again and retry.", (long)http.statusCode]];
        return;
    }

    BOOL isVideo = (dt == t.videoTask);
    NSString *name = [NSString stringWithFormat:@"%@.%@", t.identifier, isVideo ? @"video.mp4" : @"audio.m4a"];
    NSString *dest = [[self partsDirectory] stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] removeItemAtPath:dest error:nil];
    NSError *err = nil;
    // Must move synchronously: the temp file is deleted when this method returns.
    if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:dest] error:&err]) {
        [self failTask:t message:err.localizedDescription ?: @"Could not store the download"];
        return;
    }
    @synchronized (self) {
        if (isVideo) t.videoFile = dest; else t.audioFile = dest;
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    RiseYTDownloadTask *t;
    BOOL ready = NO;
    @synchronized (self) {
        t = _byTaskID[@(task.taskIdentifier)];
        [_byTaskID removeObjectForKey:@(task.taskIdentifier)];
        if (!t || ![_tasks containsObject:t]) return;
        if (task == t.videoTask) t.videoTask = nil;
        if (task == t.audioTask) t.audioTask = nil;
        if (error) {
            if (error.code == NSURLErrorCancelled && t.state != RiseYTDownloadStateDownloading) return; // paused / failed
        } else {
            ready = t.state == RiseYTDownloadStateDownloading
                && (!t.videoURL || t.videoFile)
                && (!t.audioURL || t.audioFile);
        }
    }
    if (error) { [self failTask:t message:error.localizedDescription]; return; }
    if (ready) [self finalizeTask:t];
}

@end

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOADS SCREEN
// ═══════════════════════════════════════════════════════

@interface RiseYTDownloadsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<RiseYTDownloadTask *> *downloads;
@end

@implementation RiseYTDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RiseYT Downloads";
    self.view.backgroundColor = RY_BLACK;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData)
                                                 name:kRiseYTDownloadsChanged object:nil];
    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadData {
    _downloads = [[RiseYT_DownloadManager sharedManager] allDownloads];
    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return _downloads.count ?: 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"RiseYTCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RiseYTCell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.detailTextLabel.numberOfLines = 2;

    if (_downloads.count == 0) {
        cell.textLabel.text = @"No downloads yet";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.text = @"Tap the download button on the video player.";
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        return cell;
    }

    RiseYTDownloadTask *t = _downloads[indexPath.row];
    cell.textLabel.text = t.title;
    cell.textLabel.textColor = [UIColor labelColor];
    switch (t.state) {
        case RiseYTDownloadStateCompleted:
            cell.detailTextLabel.text = [NSString stringWithFormat:@"✅ %@ — tap to share", t.quality];
            cell.detailTextLabel.textColor = [UIColor systemGreenColor];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        case RiseYTDownloadStatePaused:
            cell.detailTextLabel.text = [NSString stringWithFormat:@"⏸ %@ — paused at %.0f%%", t.quality, t.progress * 100];
            cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
            break;
        case RiseYTDownloadStateMerging:
            cell.detailTextLabel.text = [NSString stringWithFormat:@"⚙️ %@ — merging audio and video…", t.quality];
            cell.detailTextLabel.textColor = [UIColor systemBlueColor];
            break;
        case RiseYTDownloadStateFailed:
            cell.detailTextLabel.text = [NSString stringWithFormat:@"⚠️ %@ — %@", t.quality, t.errorMessage ?: @"failed"];
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
            break;
        default:
            cell.detailTextLabel.text = [NSString stringWithFormat:@"⬇️ %@ — %.0f%%", t.quality, t.progress * 100];
            cell.detailTextLabel.textColor = [UIColor systemBlueColor];
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tv deselectRowAtIndexPath:indexPath animated:YES];
    if (_downloads.count == 0) return;
    RiseYTDownloadTask *t = _downloads[indexPath.row];
    if (!t.isCompleted || !t.localPath) return;
    UIActivityViewController *avc = [[UIActivityViewController alloc]
        initWithActivityItems:@[[NSURL fileURLWithPath:t.localPath]] applicationActivities:nil];
    UITableViewCell *cell = [tv cellForRowAtIndexPath:indexPath];
    avc.popoverPresentationController.sourceView = cell ?: self.view;
    avc.popoverPresentationController.sourceRect = cell ? cell.bounds : self.view.bounds;
    [self presentViewController:avc animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tv trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_downloads.count == 0) return nil;
    RiseYTDownloadTask *t = _downloads[indexPath.row];
    NSString *title = t.isCompleted ? @"Delete" : @"Cancel";
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:title
        handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
            [[RiseYT_DownloadManager sharedManager] removeDownload:t];
            done(YES);
        }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tv leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_downloads.count == 0) return nil;
    RiseYTDownloadTask *t = _downloads[indexPath.row];
    UIContextualAction *action = nil;
    if (t.state == RiseYTDownloadStateDownloading) {
        action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Pause"
            handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
                [[RiseYT_DownloadManager sharedManager] pauseDownload:t];
                done(YES);
            }];
        action.backgroundColor = [UIColor systemOrangeColor];
    } else if (t.state == RiseYTDownloadStatePaused || t.state == RiseYTDownloadStateFailed) {
        action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                         title:(t.isPaused ? @"Resume" : @"Retry")
            handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
                [[RiseYT_DownloadManager sharedManager] resumeDownload:t];
                done(YES);
            }];
        action.backgroundColor = [UIColor systemBlueColor];
    }
    return action ? [UISwipeActionsConfiguration configurationWithActions:@[action]] : nil;
}

@end

// ═══════════════════════════════════════════════════════
//  MARK: — RISEYT UI SHARED PIECES
// ═══════════════════════════════════════════════════════

static void riseyt_presentDownloads(UIViewController *from);

static void riseyt_styleNav(UINavigationController *nav) {
    nav.view.backgroundColor = RY_BLACK;
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = RY_BLACK;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: RY_WHITE};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: RY_WHITE};
    nav.navigationBar.standardAppearance = appearance;
    nav.navigationBar.scrollEdgeAppearance = appearance;
    nav.navigationBar.tintColor = RY_YELLOW;
}

static UIView *riseyt_padded(UILabel *label) {
    UIView *container = [UIView new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:8],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8],
    ]];
    return container;
}

// Download picker: lists the qualities for the video that is playing.
@interface RiseYTQualityViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSArray<RiseYTQualityOption *> *options;
@property (nonatomic, copy) NSString *debugInfo;
@end

@implementation RiseYTQualityViewController {
    UITableView *_table;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Download";
    self.view.backgroundColor = RY_BLACK;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    _table.backgroundColor = RY_BLACK;
    _table.dataSource = self;
    _table.delegate = self;
    [self.view addSubview:_table];
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.options.count > 0 ? (NSInteger)self.options.count : 1;
    return 1;
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [UILabel new];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    label.textColor = RY_YELLOW;
    label.numberOfLines = 2;
    if (section == 0) {
        NSString *text = self.videoTitle.length ? self.videoTitle : @"Choose a quality";
        label.text = [text uppercaseString];
    } else {
        label.text = @"LIBRARY";
    }
    return riseyt_padded(label);
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == 0 && self.options.count == 0) {
        NSString *base = @"YouTube didn't expose a downloadable stream for this video. Live streams, premieres and some protected videos aren't supported.";
        return self.debugInfo.length ? [base stringByAppendingFormat:@"\n\n[%@]", self.debugInfo] : base;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = RY_CARD;
    cell.textLabel.textColor = RY_WHITE;
    cell.detailTextLabel.textColor = RY_YELLOW;
    cell.tintColor = RY_YELLOW;

    if (ip.section == 0) {
        if (self.options.count == 0) {
            cell.textLabel.text = @"No downloadable stream";
            cell.textLabel.textColor = RY_MUTED;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        RiseYTQualityOption *opt = self.options[ip.row];
        cell.textLabel.text = opt.label;
        cell.detailTextLabel.text = opt.audioOnly ? @"M4A" : @"MP4";
    } else {
        cell.textLabel.text = @"My downloads";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UIViewController *presenter = self.navigationController.presentingViewController;
    if (ip.section == 1) {
        [self dismissViewControllerAnimated:YES completion:^{ riseyt_presentDownloads(presenter); }];
        return;
    }
    if (self.options.count == 0) return;
    RiseYTQualityOption *opt = self.options[ip.row];
    NSString *title = self.videoTitle;
    [self dismissViewControllerAnimated:YES completion:^{
        [[RiseYT_DownloadManager sharedManager] startDownloadWithOption:opt title:title];
    }];
}

@end

static void riseyt_presentQualityPicker(UIViewController *host, NSArray<RiseYTQualityOption *> *options,
                                        NSString *title, NSString *debug) {
    if (!host) return;
    RiseYTQualityViewController *vc = [RiseYTQualityViewController new];
    vc.videoTitle = title;
    vc.options = options;
    vc.debugInfo = debug;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    riseyt_styleNav(nav);
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent],
                          [UISheetPresentationControllerDetent largeDetent]];
        sheet.prefersGrabberVisible = YES;
    }
    [host presentViewController:nav animated:YES completion:nil];
}

static void riseyt_presentDownloads(UIViewController *from) {
    UIViewController *host = from ?: riseyt_topViewController();
    if (!host) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[RiseYTDownloadsViewController new]];
    riseyt_styleNav(nav);
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [host presentViewController:nav animated:YES completion:nil];
}

static void riseyt_presentDownloadSheet(void) {
    UIViewController *host = riseyt_topViewController();
    if (!host) return;
    UIViewController *player = riseyt_currentPlayer;
    NSString *title = nil;
    NSString *debug = nil;
    NSArray<RiseYTQualityOption *> *options = @[];
    if (player) {
        options = riseyt_optionsForPlayer(player, &title, &debug);
    } else {
        debug = @"Start playing a video first.";
    }
    riseyt_presentQualityPicker(host, options, title ?: @"Video", debug);
}

// ═══════════════════════════════════════════════════════
//  MARK: — DOWNLOAD BUTTON ON THE PLAYER  (switch: Download Button)
// ═══════════════════════════════════════════════════════

static const NSInteger kRiseYTDownloadButtonTag = 0x52594442;

%hook YTPlayerViewController
- (void)viewDidLoad {
    %orig;
    riseyt_currentPlayer = self;
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    riseyt_currentPlayer = self;
}
%end

%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
    %orig;
    UIButton *btn = (UIButton *)[self viewWithTag:kRiseYTDownloadButtonTag];
    if (!PREF(RYDownloadButton)) { btn.hidden = YES; return; }
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = kRiseYTDownloadButtonTag;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
        [btn setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill" withConfiguration:cfg] forState:UIControlStateNormal];
        btn.backgroundColor = RY_YELLOW;
        btn.layer.cornerRadius = 22.0f;
        btn.tintColor = RY_BLACK;
        btn.accessibilityLabel = @"Download video";
        [btn addTarget:self action:@selector(riseyt_downloadTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
    }
    btn.hidden = NO;
    CGFloat size = 44.0f;
    btn.frame = CGRectMake(CGRectGetWidth(self.bounds) - size - 12.0f, 6.0f, size, size);
    [self bringSubviewToFront:btn];
}

%new
- (void)riseyt_downloadTapped:(id)sender {
    riseyt_presentDownloadSheet();
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — SETTINGS SECTION
//  Uses YouTube's own settings registry: the section is
//  registered in the category order and built when YouTube
//  asks for it. (The old code called selectors that don't
//  exist, so the section never appeared.)
// ═══════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════
//  MARK: — RISEYT SETTINGS SCREEN
//  Full-screen page opened from YouTube's settings list.
//  Black background, white text, yellow accents and a Hello banner.
// ═══════════════════════════════════════════════════════

@interface RiseYTSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end

@implementation RiseYTSettingsViewController {
    UITableView *_table;
    UIView *_banner;
    NSArray<NSDictionary *> *_sections;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RiseYT";
    self.view.backgroundColor = RY_BLACK;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];

    _sections = @[
        @{@"title": @"Downloads", @"rows": @[
            @{@"pref": @(RYDownloadButton), @"title": @"Download button", @"detail": @"Show the download button on the player"},
            @{@"pref": @(RYSavePhotos), @"title": @"Save to Photos", @"detail": @"Also copy finished videos to the Photos app"},
            @{@"action": @"downloads", @"title": @"My downloads", @"detail": @"Progress, pause, resume, share and delete"},
        ]},
        @{@"title": @"Playback", @"rows": @[
            @{@"pref": @(RYBackground), @"title": @"Background playback", @"detail": @"Keep audio playing when the app is in the background"},
            @{@"pref": @(RYPiP), @"title": @"Picture in Picture", @"detail": @"Allow Picture in Picture for videos"},
            @{@"pref": @(RYPremium), @"title": @"Premium features", @"detail": @"Enable client-side premium feature flags"},
            @{@"pref": @(RYHighRes), @"title": @"High resolutions", @"detail": @"Show 1440p and 4K where the video offers them"},
        ]},
        @{@"title": @"Ads & clutter", @"rows": @[
            @{@"pref": @(RYAdBlock), @"title": @"Block ads", @"detail": @"Remove video, feed and banner ads"},
            @{@"pref": @(RYHideEndscreen), @"title": @"Hide autoplay endscreen", @"detail": @"Hide the end-of-video autoplay overlay"},
        ]},
        @{@"title": @"Appearance", @"rows": @[
            @{@"pref": @(RYGlass), @"title": @"Liquid Glass", @"detail": @"Frosted tab bar (restart YouTube to apply)"},
            @{@"pref": @(RYThumbs), @"title": @"High-quality thumbnails", @"detail": @"Load sharper video thumbnails"},
        ]},
    ];

    _banner = [self buildBanner];
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    _table.backgroundColor = RY_BLACK;
    _table.dataSource = self;
    _table.delegate = self;
    _table.tableHeaderView = _banner;
    [self.view addSubview:_table];
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Table header views are sized by frame, so keep the banner as wide as the table.
    CGFloat width = _table.bounds.size.width;
    if (width > 0 && _banner.frame.size.width != width) {
        CGRect frame = _banner.frame;
        frame.size = CGSizeMake(width, 200);
        _banner.frame = frame;
        _table.tableHeaderView = _banner;
    }
}

- (UIView *)buildBanner {
    UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    banner.backgroundColor = RY_BLACK;

    UIView *accent = [UIView new];
    accent.backgroundColor = RY_YELLOW;
    accent.layer.cornerRadius = 3.0f;
    accent.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *hello = [UILabel new];
    hello.text = @"Hello";
    hello.font = [UIFont systemFontOfSize:46 weight:UIFontWeightHeavy];
    hello.textColor = RY_WHITE;

    UILabel *welcome = [UILabel new];
    welcome.text = @"Welcome to RiseYT";
    welcome.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    welcome.textColor = RY_YELLOW;

    UILabel *tagline = [UILabel new];
    tagline.text = @"Your YouTube, tuned the way you like it.";
    tagline.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    tagline.textColor = RY_MUTED;
    tagline.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[hello, welcome, tagline]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6.0f;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [banner addSubview:accent];
    [banner addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [accent.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:20],
        [accent.topAnchor constraintEqualToAnchor:banner.topAnchor constant:28],
        [accent.widthAnchor constraintEqualToConstant:56],
        [accent.heightAnchor constraintEqualToConstant:6],
        [stack.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:accent.bottomAnchor constant:18],
    ]];
    return banner;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"rows"] count];
}

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [UILabel new];
    label.text = [[_sections[section][@"title"] description] uppercaseString];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    label.textColor = RY_YELLOW;
    return riseyt_padded(label);
}

- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    return section == (NSInteger)_sections.count - 1 ? @"RiseYT 1.4.0" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *row = _sections[ip.section][@"rows"][ip.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = RY_CARD;
    cell.textLabel.text = row[@"title"];
    cell.textLabel.textColor = RY_WHITE;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = row[@"detail"];
    cell.detailTextLabel.textColor = RY_MUTED;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.numberOfLines = 0;

    if (row[@"pref"]) {
        RiseYTPref pref = (RiseYTPref)[row[@"pref"] unsignedIntegerValue];
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = RY_YELLOW;
        toggle.on = PREF(pref);
        toggle.tag = (NSInteger)pref;
        [toggle addTarget:self action:@selector(togglePref:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.tintColor = RY_YELLOW;
    }
    return cell;
}

- (void)togglePref:(UISwitch *)sender {
    riseyt_setPref((RiseYTPref)sender.tag, sender.on);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *row = _sections[ip.section][@"rows"][ip.row];
    if ([row[@"action"] isEqualToString:@"downloads"]) riseyt_presentDownloads(self);
}

@end

static void riseyt_presentSettings(UIViewController *host) {
    if (!host) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[RiseYTSettingsViewController new]];
    riseyt_styleNav(nav);
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [host presentViewController:nav animated:YES completion:nil];
}

static const NSInteger kRiseYTSection = 1201;

static void riseyt_setSection(UIViewController *vc, NSMutableArray *items) {
    NSString *title = @"RiseYT";
    SEL withIcon = @selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:);
    SEL noIcon = @selector(setSectionItems:forCategory:title:titleDescription:headerHidden:);
    if ([vc respondsToSelector:withIcon]) {
        Class iconClass = objc_getClass("YTIIcon");
        id icon = iconClass ? [iconClass new] : nil;
        ((void (*)(id, SEL, NSMutableArray *, NSInteger, NSString *, id, NSString *, BOOL))objc_msgSend)
            (vc, withIcon, items, kRiseYTSection, title, icon, nil, NO);
    } else if ([vc respondsToSelector:noIcon]) {
        ((void (*)(id, SEL, NSMutableArray *, NSInteger, NSString *, NSString *, BOOL))objc_msgSend)
            (vc, noIcon, items, kRiseYTSection, title, nil, NO);
    } else {
        NSLog(@"[RiseYT] This YouTube version has no known settings section API");
    }
}

static NSMutableArray *riseyt_buildSettingsItems(UIViewController *settingsVC) {
    NSMutableArray *items = [NSMutableArray new];
    Class itemClass = objc_getClass("YTSettingsSectionItem");
    if (!itemClass) return items;
    SEL actionSel = @selector(itemWithTitle:titleDescription:accessibilityIdentifier:detailTextBlock:selectBlock:);
    if (![itemClass respondsToSelector:actionSel]) return items;

    __weak UIViewController *weakVC = settingsVC;
    // One entry in YouTube's settings list. Everything else lives on the
    // RiseYT screen, which is styled independently of YouTube's cells.
    id entry = [itemClass itemWithTitle:@"RiseYT"
                       titleDescription:@"Downloads, playback, ads and appearance"
                accessibilityIdentifier:@"riseyt_open"
                        detailTextBlock:nil
                            selectBlock:^BOOL(__unused YTSettingsCell *cell, __unused NSUInteger arg1) {
        riseyt_presentSettings(weakVC ?: riseyt_topViewController());
        return YES;
    }];
    if (entry) [items addObject:entry];
    return items;
}

// Older YouTube: flat category list.
%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    if ([order containsObject:@(kRiseYTSection)]) return order;
    NSMutableArray *m = [order mutableCopy] ?: [NSMutableArray new];
    NSUInteger idx = [m indexOfObject:@(1)];
    [m insertObject:@(kRiseYTSection) atIndex:(idx == NSNotFound ? 0 : idx + 1)];
    return m;
}
%end

// Newer YouTube: grouped settings.
%hook YTSettingsGroupData
- (NSArray *)orderedCategories {
    NSArray *orig = %orig;
    if (![self respondsToSelector:@selector(type)] || [self type] != 1) return orig;
    if ([orig containsObject:@(kRiseYTSection)]) return orig;
    NSMutableArray *m = [orig mutableCopy] ?: [NSMutableArray new];
    [m insertObject:@(kRiseYTSection) atIndex:0];
    return m;
}
%end

%hook YTSettingsSectionItemManager
- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == (NSUInteger)kRiseYTSection) {
        [self riseyt_updateSectionWithEntry:entry];
        return;
    }
    %orig;
}

%new
- (void)riseyt_updateSectionWithEntry:(id)entry {
    @try {
        UIViewController *settingsVC = riseyt_kvc(self, @"_dataDelegate") ?: riseyt_kvc(self, @"_settingsViewControllerDelegate");
        if (![settingsVC isKindOfClass:[UIViewController class]]) return;
        riseyt_setSection(settingsVC, riseyt_buildSettingsItems(settingsVC));
    } @catch (NSException *e) {
        NSLog(@"[RiseYT] Settings section error: %@", e);
    }
}
%end

// ═══════════════════════════════════════════════════════
//  MARK: — CTOR
//  No permission prompts or audio-session changes at launch.
// ═══════════════════════════════════════════════════════

%ctor {
    riseyt_loadPrefs();
    %init;
    NSLog(@"[RiseYT] v%@ loaded", RISEYT_VERSION);
}

// Beegram.x — Instagram Tweak (Logos/Theos)
// Target: com.burbn.instagram | iOS 14.0+ | arm64/arm64e

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "BeegramHeaders.h"

// ─── MARK: Globals ────────────────────────────────────────────────
static BOOL bg_ghostMode          = NO;
static BOOL bg_showDeletedMsgs    = YES;
static BOOL bg_disableReceipts    = YES;
static BOOL bg_disableTyping      = YES;
static BOOL bg_copyDM             = YES;
static BOOL bg_downloadMedia      = YES;
static BOOL bg_aiAutoReply        = NO;
static BOOL bg_ttsEnabled         = NO;
static BOOL bg_noAds              = YES;
static BOOL bg_keepAwake          = YES;
static BOOL bg_zoomProfile        = YES;
static BOOL bg_disableScreenshot  = NO;
static BOOL bg_callRecording      = NO;

#define BGS(k) [[BGSettings shared] boolForKey:(k)]

// ─── MARK: Utilities ──────────────────────────────────────────────
static void BGToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        UILabel *lbl = [[UILabel alloc] init];
        lbl.text = msg;
        lbl.textColor = UIColor.whiteColor;
        lbl.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        lbl.layer.cornerRadius = 12;
        lbl.layer.masksToBounds = YES;
        lbl.alpha = 0;
        [lbl sizeToFit];
        lbl.frame = CGRectMake(0, 0, lbl.frame.size.width + 24, 36);
        lbl.center = CGPointMake(window.center.x, window.frame.size.height - 100);
        [window addSubview:lbl];
        [UIView animateWithDuration:0.3 animations:^{ lbl.alpha = 1; } completion:^(BOOL f) {
            [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{ lbl.alpha = 0; } completion:^(BOOL f2) {
                [lbl removeFromSuperview];
            }];
        }];
    });
}

static NSString *BGLocalizedString(NSString *ar, NSString *en) {
    NSString *lang = NSLocale.preferredLanguages.firstObject ?: @"en";
    return [lang hasPrefix:@"ar"] ? ar : en;
}

// ─── MARK: BGSettings ─────────────────────────────────────────────
@interface BGSettings : NSObject
+ (instancetype)shared;
- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)val forKey:(NSString *)key;
@end

@implementation BGSettings
+ (instancetype)shared {
    static BGSettings *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BGSettings new]; });
    return s;
}
- (NSUserDefaults *)ud { return [[NSUserDefaults alloc] initWithSuiteName:@"com.beegram.settings"]; }
- (BOOL)boolForKey:(NSString *)key { return [[self ud] boolForKey:key]; }
- (void)setBool:(BOOL)val forKey:(NSString *)key { [[self ud] setBool:val forKey:key]; }
@end

// ─── MARK: 1. Ghost Mode / Read Receipts ──────────────────────────
%hook IGDirectThread
- (void)markAsSeenIfNeeded {
    if (BGS(@"ghostMode") || BGS(@"disableReceipts")) return;
    %orig;
}
- (void)sendReadReceiptIfNeeded {
    if (BGS(@"disableReceipts")) return;
    %orig;
}
%end

%hook IGDirectMessagingActionHandler
- (void)markThreadAsSeen:(id)thread {
    if (BGS(@"ghostMode")) return;
    %orig;
}
%end

// ─── MARK: 2. Typing Indicator ────────────────────────────────────
%hook IGDirectTypingStatusManager
- (void)startTypingForThread:(id)thread {
    if (BGS(@"disableTyping")) return;
    %orig;
}
- (void)stopTypingForThread:(id)thread {
    if (BGS(@"disableTyping")) return;
    %orig;
}
%end

// ─── MARK: 3. Deleted Messages Recovery ───────────────────────────
%hook IGDirectThreadItem
- (void)deleteWithCompletion:(id)completion {
    if (BGS(@"showDeletedMsgs")) {
        [[DeletedMessagesManager sharedManager] saveMessageBeforeDeletion:self];
    }
    %orig;
}
%end

// ─── MARK: 4. Copy DM Text ────────────────────────────────────────
%hook IGDirectTextMessageCell
- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    %orig;
    if (!BGS(@"copyDM")) return;
    if (sender.state != UIGestureRecognizerStateBegan) return;
    id item = [self valueForKey:@"_viewModel"];
    NSString *text = [item valueForKey:@"text"];
    if (text.length > 0) {
        UIPasteboard.generalPasteboard.string = text;
        BGToast(BGLocalizedString(@"تم نسخ الرسالة", @"Message copied"));
    }
}
%end

// ─── MARK: 5. Media Download ──────────────────────────────────────
%hook IGPhotoMediaCell
- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    %orig;
    if (!BGS(@"downloadMedia") || g.state != UIGestureRecognizerStateBegan) return;
    id media = [self valueForKey:@"_media"];
    NSString *url = [[[media valueForKey:@"imageVersions2"] valueForKey:@"candidates"] firstObject];
    if (url) {
        [[BeegramDASHDownloader sharedDownloader] downloadDASHVideoWithURL:[url valueForKey:@"url"] completion:^(NSURL *local, NSError *err) {
            if (!err) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:local];
                } completionHandler:^(BOOL ok, NSError *e) {
                    BGToast(ok ? BGLocalizedString(@"تم حفظ الصورة", @"Image saved") : BGLocalizedString(@"فشل الحفظ", @"Save failed"));
                }];
            }
        }];
    }
}
%end

%hook IGVideoCell
- (void)handleLongPress:(UILongPressGestureRecognizer *)g {
    %orig;
    if (!BGS(@"downloadMedia") || g.state != UIGestureRecognizerStateBegan) return;
    id media = [self valueForKey:@"_media"];
    NSString *dashUrl = [media valueForKey:@"videoUrl"];
    if (!dashUrl) dashUrl = [[[media valueForKey:@"videoVersions"] firstObject] valueForKey:@"url"];
    if (dashUrl) {
        [[BeegramDASHDownloader sharedDownloader] downloadDASHVideoWithURL:dashUrl completion:^(NSURL *local, NSError *err) {
            if (!err) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:local];
                } completionHandler:^(BOOL ok, NSError *e) {
                    BGToast(ok ? BGLocalizedString(@"تم حفظ الفيديو", @"Video saved") : BGLocalizedString(@"فشل الحفظ", @"Save failed"));
                }];
            }
        }];
    }
}
%end

// ─── MARK: 6. No Ads ──────────────────────────────────────────────
%hook IGAdUnitViewModel
- (BOOL)shouldShow { return BGS(@"noAds") ? NO : %orig; }
- (BOOL)isSponsored { return BGS(@"noAds") ? NO : %orig; }
%end

%hook IGFeedAd
- (BOOL)isSponsoredContent { return BGS(@"noAds") ? NO : %orig; }
%end

%hook IGExploreAdUnitViewModel
- (BOOL)shouldShow { return BGS(@"noAds") ? NO : %orig; }
%end

// ─── MARK: 7. Keep Screen Awake ───────────────────────────────────
%hook UIApplication
- (void)setIdleTimerDisabled:(BOOL)disabled {
    %orig(BGS(@"keepAwake") ? YES : disabled);
}
%end

// ─── MARK: 8. Profile Zoom / HD ───────────────────────────────────
%hook IGUserAvatarView
- (void)setProfilePictureURI:(NSString *)uri {
    if (BGS(@"zoomProfile")) {
        uri = [uri stringByReplacingOccurrencesOfString:@"150x150" withString:@"1080x1080"];
        uri = [uri stringByReplacingOccurrencesOfString:@"320x320" withString:@"1080x1080"];
    }
    %orig(uri);
}
%end

%hook IGUserProfileHeaderViewController
- (void)handleProfilePictureTap:(id)sender {
    if (!BGS(@"zoomProfile")) { %orig; return; }
    id user = [self valueForKey:@"_user"];
    NSString *url = [user valueForKey:@"hdProfilePicUrlInfo"];
    if (!url) url = [user valueForKey:@"profilePicUrl"];
    if (url) {
        // Present full-screen viewer
        UIImageView *iv = [[UIImageView alloc] initWithFrame:UIScreen.mainScreen.bounds];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.backgroundColor = UIColor.blackColor;
        iv.userInteractionEnabled = YES;
        [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            if (d) dispatch_async(dispatch_get_main_queue(), ^{
                iv.image = [UIImage imageWithData:d];
            });
        }].resume;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:iv action:@selector(removeFromSuperview)];
        [iv addGestureRecognizer:tap];
        [UIApplication.sharedApplication.keyWindow addSubview:iv];
    }
}
%end

// ─── MARK: 9. Stories Stealth View ───────────────────────────────
%hook IGStoryViewerViewController
- (void)viewStoryAtIndex:(NSInteger)idx {
    %orig;
    if (BGS(@"ghostMode")) {
        // Cancel any queued seen notifications
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_markStoriesAsSeen) object:nil];
    }
}
- (void)_markStoriesAsSeen {
    if (BGS(@"ghostMode")) return;
    %orig;
}
%end

// ─── MARK: 10. Screenshot Notifications Block ─────────────────────
%hook IGScreenshotDetectionManager
- (void)userDidTakeScreenshotForMedia:(id)media {
    if (BGS(@"disableScreenshot")) return;
    %orig;
}
%end

// ─── MARK: 11. DM Screenshot No Notify ───────────────────────────
%hook IGDirectMessageScreenshotController
- (void)sendScreenshotNotificationForThread:(id)thread {
    if (BGS(@"disableScreenshot")) return;
    %orig;
}
%end

// ─── MARK: 12. Call Recording ─────────────────────────────────────
%hook IGVideoCallViewController
- (void)viewDidLoad {
    %orig;
    if (!BGS(@"callRecording")) return;
    UIButton *recBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [recBtn setTitle:@"⏺" forState:UIControlStateNormal];
    recBtn.frame = CGRectMake(20, 60, 44, 44);
    recBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    recBtn.layer.cornerRadius = 22;
    [recBtn addTarget:self action:@selector(bg_toggleRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recBtn];
}

%new
- (void)bg_toggleRecording {
    BeegramCallRecorderHelper *rec = [BeegramCallRecorderHelper sharedHelper];
    if ([rec isRecording]) {
        [rec stopRecording];
        BGToast(BGLocalizedString(@"توقف التسجيل", @"Recording stopped"));
    } else {
        NSString *callId = [[self valueForKey:@"_callId"] ?: @"call" stringByAppendingFormat:@"_%@", @(NSDate.date.timeIntervalSince1970)];
        [rec startRecordingCallWithId:callId];
        BGToast(BGLocalizedString(@"بدأ التسجيل", @"Recording started"));
    }
}
%end

// ─── MARK: 13. AI Auto Reply (BAI/Gemini) ─────────────────────────
%hook IGDirectMessagingViewController
- (void)didReceiveNewMessage:(IGDirectThreadItem *)item forThread:(IGDirectThread *)thread {
    %orig;
    if (!BGS(@"aiAutoReply")) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[BAIAutoReplyManager sharedManager] processIncomingMessage:item inThread:thread];
    });
}
%end

// ─── MARK: 14. TTS for DMs ────────────────────────────────────────
%hook IGDirectMessageCell
- (void)setViewModel:(id)vm {
    %orig;
    if (!BGS(@"ttsEnabled")) return;
    NSString *text = [vm valueForKey:@"text"];
    if (text.length < 1) return;
    [[ElevenLabsAPIManager sharedManager] synthesizeText:text voiceId:@"Rachel" completion:^(NSData *audio, NSError *err) {
        if (!err && audio) {
            AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithData:audio error:nil];
            [player play];
        }
    }];
}
%end

// ─── MARK: 15. Profile Analyzer ───────────────────────────────────
%hook IGUserProfileHeaderViewController
%new
- (void)bg_analyzeProfile {
    id user = [self valueForKey:@"_user"];
    NSString *userId = [user valueForKey:@"pk"];
    [[BGProfileAnalyzer sharedAnalyzer] analyzeUserWithId:userId completion:^(NSDictionary *result, NSError *err) {
        if (err || !result) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:
                BGLocalizedString(@"متابعين: %@ | منشورات: %@ | معدل التفاعل: %@%%",
                                  @"Followers: %@ | Posts: %@ | Engagement: %@%%"),
                result[@"followerCount"], result[@"mediaCount"], result[@"engagementRate"]];
            BGToast(msg);
        });
    }];
}
%end

// ─── MARK: 16. Settings VC Injection ──────────────────────────────
%hook IGSettingsViewController
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return %orig + 1;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (section == [self numberOfSectionsInTableView:tv] - 1) return 1;
    return %orig;
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger bgSection = [self numberOfSectionsInTableView:tv] - 1;
    if (ip.section == bgSection) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BGCell"];
        cell.textLabel.text = @"⚙️ Beegram";
        cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    return %orig;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger bgSection = [self numberOfSectionsInTableView:tv] - 1;
    if (ip.section == bgSection) {
        [tv deselectRowAtIndexPath:ip animated:YES];
        BGSettingsViewController *vc = [BGSettingsViewController new];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    %orig;
}
%end

// ─── MARK: 17. Beegram Settings UI ───────────────────────────────
@interface BGSettingsViewController : UITableViewController
@end

@implementation BGSettingsViewController {
    NSArray<NSDictionary *> *_items;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Beegram";
    _items = @[
        @{@"key":@"ghostMode",        @"title_ar":@"وضع الشبح",          @"title_en":@"Ghost Mode"},
        @{@"key":@"disableReceipts",  @"title_ar":@"إخفاء إشعار القراءة", @"title_en":@"Hide Read Receipts"},
        @{@"key":@"disableTyping",    @"title_ar":@"إخفاء الكتابة",       @"title_en":@"Hide Typing"},
        @{@"key":@"showDeletedMsgs",  @"title_ar":@"عرض الرسائل المحذوفة","@title_en":@"Show Deleted Msgs"},
        @{@"key":@"copyDM",           @"title_ar":@"نسخ الرسائل",         @"title_en":@"Copy DMs"},
        @{@"key":@"downloadMedia",    @"title_ar":@"تحميل الوسائط",       @"title_en":@"Download Media"},
        @{@"key":@"noAds",            @"title_ar":@"إخفاء الإعلانات",     @"title_en":@"No Ads"},
        @{@"key":@"keepAwake",        @"title_ar":@"الشاشة دائماً مضاءة", @"title_en":@"Keep Awake"},
        @{@"key":@"zoomProfile",      @"title_ar":@"تكبير الصور الشخصية", @"title_en":@"Zoom Profiles"},
        @{@"key":@"disableScreenshot",@"title_ar":@"إخفاء إشعار لقطة",   @"title_en":@"Screenshot Privacy"},
        @{@"key":@"callRecording",    @"title_ar":@"تسجيل المكالمات",     @"title_en":@"Record Calls"},
        @{@"key":@"aiAutoReply",      @"title_ar":@"رد تلقائي بالذكاء",   @"title_en":@"AI Auto Reply"},
        @{@"key":@"ttsEnabled",       @"title_ar":@"قراءة الرسائل صوتياً","@title_en":@"TTS Messages"},
    ];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"C"];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _items.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"C" forIndexPath:ip];
    NSDictionary *item = _items[ip.row];
    NSString *lang = NSLocale.preferredLanguages.firstObject ?: @"en";
    cell.textLabel.text = [lang hasPrefix:@"ar"] ? item[@"title_ar"] : item[@"title_en"];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = BGS(item[@"key"]);
    sw.tag = ip.row;
    [sw addTarget:self action:@selector(toggleSwitch:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)toggleSwitch:(UISwitch *)sw {
    NSString *key = _items[sw.tag][@"key"];
    [[BGSettings shared] setBool:sw.on forKey:key];
}
@end

// ─── MARK: 18. Reels Download Button ──────────────────────────────
%hook IGReelsViewController
- (void)viewDidLoad {
    %orig;
    if (!BGS(@"downloadMedia")) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle.fill"];
    [btn setImage:icon forState:UIControlStateNormal];
    btn.tintColor = UIColor.whiteColor;
    btn.frame = CGRectMake(self.view.frame.size.width - 56, 160, 44, 44);
    [btn addTarget:self action:@selector(bg_downloadReel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

%new
- (void)bg_downloadReel {
    id media = [self valueForKey:@"_media"];
    NSString *url = [[[media valueForKey:@"videoVersions"] firstObject] valueForKey:@"url"];
    if (!url) { BGToast(BGLocalizedString(@"لا يوجد رابط", @"No URL found")); return; }
    [[BeegramDASHDownloader sharedDownloader] downloadDASHVideoWithURL:url completion:^(NSURL *local, NSError *err) {
        if (err) { BGToast(BGLocalizedString(@"فشل التحميل", @"Download failed")); return; }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:local];
        } completionHandler:^(BOOL ok, NSError *e2) {
            BGToast(ok ? BGLocalizedString(@"تم حفظ الريل", @"Reel saved") : BGLocalizedString(@"فشل الحفظ", @"Save failed"));
        }];
    }];
}
%end

// ─── MARK: 19. Stories Download ───────────────────────────────────
%hook IGStoriesViewController
- (void)viewDidLoad {
    %orig;
    if (!BGS(@"downloadMedia")) return;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *icon = [UIImage systemImageNamed:@"arrow.down.to.line"];
    [btn setImage:icon forState:UIControlStateNormal];
    btn.tintColor = UIColor.whiteColor;
    btn.frame = CGRectMake(self.view.frame.size.width - 56, 50, 44, 44);
    btn.layer.shadowColor = UIColor.blackColor.CGColor;
    btn.layer.shadowOpacity = 0.6;
    btn.layer.shadowRadius = 3;
    [btn addTarget:self action:@selector(bg_downloadStory) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

%new
- (void)bg_downloadStory {
    id item = [self valueForKey:@"_currentStoryItem"];
    NSString *videoUrl = [[[item valueForKey:@"videoVersions"] firstObject] valueForKey:@"url"];
    NSString *imageUrl = [[[item valueForKey:@"imageVersions2"] valueForKey:@"candidates"] firstObject];
    if (videoUrl) {
        [[BeegramDASHDownloader sharedDownloader] downloadDASHVideoWithURL:videoUrl completion:^(NSURL *l, NSError *e) {
            if (!e) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:l];
                } completionHandler:^(BOOL ok, NSError *e2) {
                    BGToast(ok ? BGLocalizedString(@"تم حفظ الستوري", @"Story saved") : BGLocalizedString(@"فشل", @"Failed"));
                }];
            }
        }];
    } else if (imageUrl) {
        NSString *url = [imageUrl valueForKey:@"url"] ?: imageUrl;
        [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
            if (!e && d) {
                UIImage *img = [UIImage imageWithData:d];
                if (img) UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
                BGToast(BGLocalizedString(@"تم حفظ الستوري", @"Story saved"));
            }
        }].resume;
    }
}
%end

// ─── MARK: 20. Spoof Device / User-Agent ──────────────────────────
%hook IGUserAgent
- (NSString *)userAgentString {
    if (!BGS(@"spoofDevice")) return %orig;
    return @"Instagram 300.0.0.29.109 (iPhone15,2; iOS 17.0; en_US; en-US; scale=3.00; 1179x2556; 123456789)";
}
%end

// ─── MARK: 21. Unsend Confirmation Skip ───────────────────────────
%hook IGDirectMessageActionSheetController
- (void)confirmUnsend:(id)thread itemId:(NSString *)itemId {
    // Skip confirmation dialog, unsend directly
    %orig;
}
%end

// ─── MARK: 22. DASH Downloader Implementation ─────────────────────
@implementation BeegramDASHDownloader

+ (instancetype)sharedDownloader {
    static BeegramDASHDownloader *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BeegramDASHDownloader new]; });
    return s;
}

- (void)downloadDASHVideoWithURL:(NSString *)urlStr completion:(void(^)(NSURL *localURL, NSError *error))completion {
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        completion(nil, [NSError errorWithDomain:@"BeegramDASH" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }
    NSURLSessionDownloadTask *task = [NSURLSession.sharedSession downloadTaskWithURL:url completionHandler:^(NSURL *tmp, NSURLResponse *r, NSError *e) {
        if (e) { completion(nil, e); return; }
        NSString *ext = tmp.pathExtension.length ? tmp.pathExtension : @"mp4";
        NSURL *dest = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"BG_%@.%@", NSUUID.UUID.UUIDString, ext]]];
        NSError *mvErr;
        [[NSFileManager defaultManager] moveItemAtURL:tmp toURL:dest error:&mvErr];
        completion(mvErr ? nil : dest, mvErr);
    }];
    [task resume];
}
@end

// ─── MARK: 23. Deleted Messages Manager ───────────────────────────
@implementation DeletedMessagesManager {
    NSMutableDictionary<NSString *, NSMutableArray *> *_store;
}

+ (instancetype)sharedManager {
    static DeletedMessagesManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [DeletedMessagesManager new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    _store = [NSMutableDictionary new];
    return self;
}

- (void)saveMessageBeforeDeletion:(IGDirectThreadItem *)item {
    NSString *threadId = [item valueForKey:@"threadId"] ?: @"unknown";
    if (!_store[threadId]) _store[threadId] = [NSMutableArray new];
    [_store[threadId] addObject:item];
}

- (NSArray<IGDirectThreadItem *> *)deletedMessagesForThreadId:(NSString *)threadId {
    return _store[threadId] ?: @[];
}
@end

// ─── MARK: 24. BAI Gemini Service ─────────────────────────────────
@implementation BAIGeminiService

+ (instancetype)sharedService {
    static BAIGeminiService *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BAIGeminiService new]; });
    return s;
}

- (void)sendPrompt:(NSString *)prompt completion:(void(^)(NSString *response, NSError *error))completion {
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"BGGeminiAPIKey"] ?: @"";
    NSURL *url = [NSURL URLWithString:@"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:apiKey forHTTPHeaderField:@"x-goog-api-key"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"contents":@[@{@"parts":@[@{@"text":prompt}]}]};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { completion(nil, e); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *text = json[@"candidates"][0][@"content"][@"parts"][0][@"text"] ?: @"";
        completion(text, nil);
    }] resume];
}
@end

// ─── MARK: 25. BAI Auto Reply Manager ─────────────────────────────
@implementation BAIAutoReplyManager

+ (instancetype)sharedManager {
    static BAIAutoReplyManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BAIAutoReplyManager new]; });
    return s;
}

- (void)processIncomingMessage:(IGDirectThreadItem *)item inThread:(IGDirectThread *)thread {
    NSString *text = [item valueForKey:@"text"];
    if (!text.length) return;
    NSString *prompt = [NSString stringWithFormat:@"Reply to this message naturally and briefly: %@", text];
    [[BAIGeminiService sharedService] sendPrompt:prompt completion:^(NSString *reply, NSError *err) {
        if (err || !reply.length) return;
        // Inject reply via DM send
        dispatch_async(dispatch_get_main_queue(), ^{
            id composer = [NSClassFromString(@"IGDirectMessageComposer") new];
            [composer performSelector:@selector(sendTextMessage:inThread:) withObject:reply withObject:thread];
        });
    }];
}
@end

// ─── MARK: 26. ElevenLabs TTS Manager ────────────────────────────
@implementation ElevenLabsAPIManager

+ (instancetype)sharedManager {
    static ElevenLabsAPIManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [ElevenLabsAPIManager new]; });
    return s;
}

- (NSString *)apiKey {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"BGElevenLabsKey"] ?: @"";
}

- (void)synthesizeText:(NSString *)text voiceId:(NSString *)voiceId completion:(void(^)(NSData *audioData, NSError *error))completion {
    NSString *urlStr = [NSString stringWithFormat:@"https://api.elevenlabs.io/v1/text-to-speech/%@", voiceId];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:self.apiKey forHTTPHeaderField:@"xi-api-key"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"text":text, @"model_id":@"eleven_multilingual_v2", @"voice_settings":@{@"stability":@0.5, @"similarity_boost":@0.75}};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        completion(e ? nil : d, e);
    }] resume];
}
@end

// ─── MARK: 27. Call Recorder Helper ───────────────────────────────
@implementation BeegramCallRecorderHelper {
    AVAudioRecorder *_recorder;
    BOOL _recording;
}

+ (instancetype)sharedHelper {
    static BeegramCallRecorderHelper *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BeegramCallRecorderHelper new]; });
    return s;
}

- (BOOL)isRecording { return _recording; }

- (void)startRecordingCallWithId:(NSString *)callId {
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"BG_Call_%@.m4a", callId]]];
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };
    NSError *err;
    _recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&err];
    if (!err) { [_recorder record]; _recording = YES; }
}

- (void)stopRecording {
    [_recorder stop];
    _recording = NO;
    NSURL *url = _recorder.url;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:nil];
}
@end

// ─── MARK: 28. Profile Analyzer ───────────────────────────────────
@implementation BGProfileAnalyzer

+ (instancetype)sharedAnalyzer {
    static BGProfileAnalyzer *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [BGProfileAnalyzer new]; });
    return s;
}

- (void)analyzeUserWithId:(NSString *)userId completion:(void(^)(NSDictionary *result, NSError *error))completion {
    // Build analysis data from Instagram's private API endpoint
    NSString *urlStr = [NSString stringWithFormat:@"https://i.instagram.com/api/v1/users/%@/info/", userId];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [req setValue:@"Instagram 300.0.0.29.109" forHTTPHeaderField:@"User-Agent"];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (e) { completion(nil, e); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSDictionary *user = json[@"user"];
        NSInteger followers = [user[@"follower_count"] integerValue];
        NSInteger following = [user[@"following_count"] integerValue];
        NSInteger posts     = [user[@"media_count"] integerValue];
        double engagement   = posts > 0 ? (double)followers / posts / 100.0 : 0;
        NSDictionary *result = @{
            @"followerCount": @(followers),
            @"followingCount": @(following),
            @"mediaCount": @(posts),
            @"engagementRate": [NSString stringWithFormat:@"%.2f", engagement],
            @"isVerified": user[@"is_verified"] ?: @NO,
            @"isPrivate": user[@"is_private"] ?: @NO,
        };
        completion(result, nil);
    }] resume];
}
@end

// ─── MARK: Constructor ─────────────────────────────────────────────
%ctor {
    NSLog(@"[Beegram] Loaded ✓");
    // Initialize settings defaults if first launch
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:@"com.beegram.settings"];
    NSDictionary *defaults = @{
        @"ghostMode": @NO, @"disableReceipts": @YES, @"disableTyping": @YES,
        @"showDeletedMsgs": @YES, @"copyDM": @YES, @"downloadMedia": @YES,
        @"noAds": @YES, @"keepAwake": @NO, @"zoomProfile": @YES,
        @"disableScreenshot": @NO, @"callRecording": @NO,
        @"aiAutoReply": @NO, @"ttsEnabled": @NO, @"spoofDevice": @NO,
    };
    [defaults enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *s) {
        if (![ud objectForKey:k]) [ud setObject:v forKey:k];
    }];
}

%dtor {
    NSLog(@"[Beegram] Unloaded");
}

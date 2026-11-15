#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// ─────────────────────────────────────────
//  YouTube Internal Classes
// ─────────────────────────────────────────

@interface YTGlobalConfig : NSObject
- (BOOL)isAdsEnabled;
- (void)setIsAdsEnabled:(BOOL)enabled;
@end

@interface YTColdConfig : NSObject
- (BOOL)isPremiumUser;
- (void)setIsPremiumUser:(BOOL)premium;
- (BOOL)isBackgroundPlaybackEnabled;
- (void)setIsBackgroundPlaybackEnabled:(BOOL)enabled;
@end

@interface YTHotConfig : NSObject
- (BOOL)isAdsEnabled;
- (void)setIsAdsEnabled:(BOOL)enabled;
@end

@interface YTBackgroundabilityPolicyImpl : NSObject
- (BOOL)isBackgroundable;
- (void)setIsBackgroundable:(BOOL)backgroundable;
@end

@interface YTOfflineVideoDownloader : NSObject
+ (instancetype)sharedInstance;
- (void)downloadVideoWithID:(NSString *)videoID quality:(NSString *)quality;
@end

// ─── Settings ───────────────────────────

@interface YTSettingsSectionItem : NSObject
+ (instancetype)itemWithTitle:(NSString *)title
                     accessoryType:(NSInteger)accessoryType
               accessibilityLabel:(NSString *)accessibilityLabel
                       detailText:(NSString *)detailText
                      selectBlock:(void (^)(id cell))selectBlock;
@end

@interface YTSettingsGroupData : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSMutableArray *items;
- (instancetype)initWithTitle:(NSString *)title items:(NSArray *)items;
@end

@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSArray *)items forCategory:(NSInteger)category title:(NSString *)title;
- (void)reloadData;
@end

// ─── UI Classes ─────────────────────────

@interface YTPivotBarView : UIView
@end

@interface YTPivotBarViewController : UIViewController
@end

@interface YTFloatingPivotBarView : UIView
@end

@interface YTFrostedGlassView : UIView
@end

@interface YTHeaderView : UIView
@end

@interface YTTabTitlesView : UIView
@end

@interface YTHomeTabTitlesView : UIView
@end

@interface YTSubheaderContainerView : UIView
@end

@interface YTHeaderContentComboView : UIView
@end

@interface YTFloatingBarExperiment : NSObject
- (BOOL)isEnabled;
@end

// ─── Ad Classes ─────────────────────────

@interface YTMainAppAblateAdsCenter : NSObject
- (BOOL)isAdFree;
- (void)setIsAdFree:(BOOL)adFree;
@end

@interface YTInstreamAdTrackingController : NSObject
@end

@interface YTPremiumAdsSeenEventLogger : NSObject
@end

@interface YTAdCuepointEventCenter : NSObject
@end

@interface YTAdElementsCellController : NSObject
@end

@interface YTPromotedVideoCellController : NSObject
@end

@interface YTCompactPromotedVideoCellController : NSObject
@end

@interface YTCompactPromotedItemCellController : NSObject
@end

// ─────────────────────────────────────────
//  RiseYT Classes
// ─────────────────────────────────────────

@class RiseYTDownloadTask;
@interface RiseYT_DownloadManager : NSObject
+ (instancetype)sharedManager;
- (void)addDownloadWithURL:(NSURL *)url title:(NSString *)title quality:(NSString *)quality;
- (void)cancelDownload:(RiseYTDownloadTask *)task;
- (void)pauseDownload:(RiseYTDownloadTask *)task;
- (void)resumeDownload:(RiseYTDownloadTask *)task;
- (NSArray<RiseYTDownloadTask *> *)allDownloads;
- (NSString *)downloadsDirectory;
- (void)cancelDownloadAtIndex:(NSUInteger)index;
- (void)pauseDownloadAtIndex:(NSUInteger)index;
- (void)resumeDownloadAtIndex:(NSUInteger)index;
- (NSArray *)activeDownloads;
- (NSArray *)completedDownloads;
- (NSString *)downloadDirectory;
@end

@interface RiseYTDownloadTask : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *quality;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isCompleted;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, strong) NSURLSessionDownloadTask *sessionTask;
@property (nonatomic, strong) NSData *resumeData;
@end

@interface RiseYTDownloadsViewController : UIViewController
+ (instancetype)sharedController;
- (void)reloadData;
@end

@interface RiseYTHLSDownload : NSObject
@property (nonatomic, strong) NSString *hlsURL;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *quality;
- (instancetype)initWithHLSURL:(NSString *)url title:(NSString *)title quality:(NSString *)quality;
- (void)startDownload;
@end

@interface RiseYTQualityOption : NSObject
+ (instancetype)optionWithLabel:(NSString *)label itag:(NSString *)itag resolution:(NSString *)resolution;
@property (nonatomic, copy) NSString *itag;
@property (nonatomic, copy) NSString *resolution;
@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, assign) NSInteger bitrate;
- (instancetype)initWithLabel:(NSString *)label url:(NSString *)url bitrate:(NSInteger)bitrate;
@end

@interface RiseYTQualitySheet : UIView
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) void (^completion)(NSString *quality, NSString *itag);
@property (nonatomic, copy) NSArray<RiseYTQualityOption *> *qualities;
- (instancetype)initWithVideoID:(NSString *)videoID title:(NSString *)title completion:(void(^)(NSString *, NSString *))completion;
- (void)presentFromViewController:(UIViewController *)vc;
+ (void)presentWithOptions:(NSArray<RiseYTQualityOption *> *)options
              fromController:(UIViewController *)controller
                 completion:(void (^)(RiseYTQualityOption *selected))completion;
@end

@interface RiseYTProgressBar : UIView
@property (nonatomic, assign) float progress;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)setProgress:(float)progress animated:(BOOL)animated;
@end

@interface RiseYTCircularProgressButton : UIButton
@property (nonatomic, assign) float progress;
- (void)setProgress:(float)progress animated:(BOOL)animated;
@end

@interface RiseYTLocalize : NSObject
+ (NSString *)localizedStringForKey:(NSString *)key;
@end


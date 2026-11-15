#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ─────────────────────────────────────────
//  YouTube private classes
//  Only the members RiseYT calls directly are declared here.
//  Everything else is reached defensively (respondsToSelector / KVC)
//  because YouTube renames internals between versions.
// ─────────────────────────────────────────

@class YTSettingsCell;

@interface YTSettingsSectionItem : NSObject
+ (instancetype)itemWithTitle:(NSString *)title
             titleDescription:(NSString *)titleDescription
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(id)detailTextBlock
                  selectBlock:(BOOL (^)(YTSettingsCell *cell, NSUInteger arg1))selectBlock;
+ (instancetype)switchItemWithTitle:(NSString *)title
                   titleDescription:(NSString *)titleDescription
            accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           switchOn:(BOOL)switchOn
                        switchBlock:(BOOL (^)(YTSettingsCell *cell, BOOL enabled))switchBlock
                      settingItemId:(int)settingItemId;
@end

@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSMutableArray *)sectionItems
            forCategory:(NSInteger)category
                  title:(NSString *)title
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
- (void)setSectionItems:(NSMutableArray *)sectionItems
            forCategory:(NSInteger)category
                  title:(NSString *)title
                   icon:(id)icon
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
@end

@interface YTSettingsSectionItemManager : NSObject
- (void)riseyt_updateSectionWithEntry:(id)entry;
@end

@interface YTSettingsGroupData : NSObject
- (NSInteger)type;
@end

@interface YTPlayerViewController : UIViewController
- (NSString *)currentVideoID;
@end

@interface YTMainAppControlsOverlayView : UIView
- (void)riseyt_downloadTapped:(id)sender;
@end

@interface YTAutonavEndscreenViewController : UIViewController
@end

@interface YTPivotBarView : UIView
@end

@interface YTFloatingPivotBarView : UIView
@end

@interface YTFrostedGlassView : UIView
@end

@interface YTCastDeviceView : UIView
@end

@interface YTThumbnailView : UIView
@end

// ─────────────────────────────────────────
//  RiseYT classes
// ─────────────────────────────────────────

typedef NS_ENUM(NSInteger, RiseYTDownloadState) {
    RiseYTDownloadStateDownloading = 0,
    RiseYTDownloadStatePaused,
    RiseYTDownloadStateMerging,
    RiseYTDownloadStateCompleted,
    RiseYTDownloadStateFailed,
};

@interface RiseYTQualityOption : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) NSURL *videoURL;   // nil for audio-only
@property (nonatomic, strong) NSURL *audioURL;   // nil for single-file (progressive) video
@property (nonatomic, assign) BOOL audioOnly;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) long long bitrate;
@end

@interface RiseYTDownloadTask : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *quality;
@property (nonatomic, strong) NSURL *videoURL;
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, assign) BOOL audioOnly;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) RiseYTDownloadState state;
@property (nonatomic, copy) NSString *localPath;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, readonly) BOOL isCompleted;
@property (nonatomic, readonly) BOOL isPaused;
// Internal transfer state
@property (nonatomic, strong) NSURLSessionDownloadTask *videoTask;
@property (nonatomic, strong) NSURLSessionDownloadTask *audioTask;
@property (nonatomic, strong) NSData *videoResumeData;
@property (nonatomic, strong) NSData *audioResumeData;
@property (nonatomic, copy) NSString *videoFile;
@property (nonatomic, copy) NSString *audioFile;
@property (nonatomic, assign) int64_t videoWritten;
@property (nonatomic, assign) int64_t videoExpected;
@property (nonatomic, assign) int64_t audioWritten;
@property (nonatomic, assign) int64_t audioExpected;
@property (nonatomic, assign) float lastPostedProgress;
- (void)updateProgress;
@end

@interface RiseYT_DownloadManager : NSObject
+ (instancetype)sharedManager;
- (RiseYTDownloadTask *)startDownloadWithOption:(RiseYTQualityOption *)option title:(NSString *)title;
- (void)pauseDownload:(RiseYTDownloadTask *)task;
- (void)resumeDownload:(RiseYTDownloadTask *)task;
- (void)removeDownload:(RiseYTDownloadTask *)task;
- (NSArray<RiseYTDownloadTask *> *)allDownloads;
- (NSString *)downloadsDirectory;
@end

@interface RiseYTDownloadsViewController : UIViewController
@end

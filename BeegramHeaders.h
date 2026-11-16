// BeegramHeaders.h — Instagram internal class declarations for Beegram tweak

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>

// ─── Instagram Core ───────────────────────────────────────────────────────────

@interface IGUserSession : NSObject
@property (nonatomic, retain) NSString *userId;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *sessionId;
@property (nonatomic, assign) BOOL isLoggedIn;
+ (instancetype)sharedInstance;
- (NSString *)csrfToken;
- (NSString *)deviceId;
@end

@interface IGVideoCallManager : NSObject
+ (instancetype)sharedManager;
- (void)startCallWithUserId:(NSString *)userId;
- (void)endCall;
- (BOOL)isCallActive;
@end

@interface IGVideoCallViewController : UIViewController
@property (nonatomic, retain) NSString *callId;
- (void)startRecording;
- (void)stopRecording;
@end

@interface IGVideoPlayerOverlayContainerView : UIView
@end

// ─── DM / Thread ─────────────────────────────────────────────────────────────

@interface IGDirectThreadItem : NSObject
@property (nonatomic, retain) NSString *itemId;
@property (nonatomic, retain) NSString *userId;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSDate *timestamp;
@property (nonatomic, assign) BOOL isDeleted;
@end

@interface IGDirectThread : NSObject
@property (nonatomic, retain) NSString *threadId;
@property (nonatomic, retain) NSArray *items;
@property (nonatomic, assign) BOOL isPending;
@end

@interface IGDirectInboxFeedController : NSObject
- (void)approvePendingThread:(NSString *)threadId completion:(void(^)(BOOL success))completion;
- (void)approvePendingThread:(NSString *)threadId senderPk:(NSString *)senderPk completion:(void(^)(BOOL success))completion;
- (void)approvePendingThread:(NSString *)threadId senderPk:(NSString *)senderPk force:(BOOL)force completion:(void(^)(BOOL success))completion;
- (void)approvePendingThreadIfNeeded:(NSString *)threadId completion:(void(^)(BOOL success))completion;
- (void)approvePendingThreadIfNeeded:(NSString *)threadId senderPk:(NSString *)senderPk completion:(void(^)(BOOL success))completion;
- (void)approvePendingThreadIfNeeded:(NSString *)threadId senderPk:(NSString *)senderPk isPending:(BOOL)isPending completion:(void(^)(BOOL success))completion;
- (void)allowRequestThreadsWithIds:(NSArray *)threadIds to:(id)destination pendingThreadType:(NSInteger)type originFolder:(NSString *)folder customFolderId:(NSString *)customId pendingInboxSortType:(NSInteger)sortType completion:(void(^)(BOOL success))completion;
@end

@interface IGDirectMessageSendController : NSObject
- (void)sendMessageContent:(id)content toThreadKey:(NSString *)threadKey attribution:(id)attribution privateReplyPayload:(id)payload messageSentSpeedLogger:(id)l1 messageSentSpeedMarker:(id)m1 localSendSpeedLogger:(id)l2 localSendSpeedMarker:(id)m2 foaLSSLogger:(id)l3 foaS2SLogger:(id)l4 igdS2SLogger:(id)l5 agentsPerfLogger:(id)l6 sendSilently:(BOOL)silently multiModalMetadata:(id)metadata skipGenAIEval:(BOOL)skipEval additionalData:(id)data;
- (void)sendMessageContent:(id)content toThreadKey:(NSString *)threadKey attribution:(id)attribution sendSilently:(BOOL)silently productType:(NSInteger)type additionalData:(id)data;
- (void)broadcastTextMessageViaServerAPI:(NSString *)text threadId:(NSString *)threadId;
@end

// ─── Stories ──────────────────────────────────────────────────────────────────

@interface IGStoryItem : NSObject
@property (nonatomic, retain) NSString *itemId;
@property (nonatomic, retain) NSString *reelPk;
@property (nonatomic, assign) BOOL isViewOnce;
@end

@interface IGStoryManager : NSObject
- (void)addSeenDateForStoryItem:(NSString *)itemId reelPK:(NSString *)reelPk;
- (void)reportSeenItem:(id)item sectionController:(id)controller;
@end

// ─── Comments ─────────────────────────────────────────────────────────────────

@interface IGComment : NSObject
@property (nonatomic, retain) NSString *commentId;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSString *userId;
@end

@interface IGCommentViewController : UIViewController
- (void)showJumpHUDOnCommentVC:(id)vc message:(NSString *)message;
@end

// ─── Users / Profile ─────────────────────────────────────────────────────────

@interface IGUserFragment : NSObject
@property (nonatomic, retain) NSString *pk;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *fullName;
@property (nonatomic, retain) NSString *profilePicUrl;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, assign) BOOL isVerified;
@property (nonatomic, assign) NSInteger followerCount;
@property (nonatomic, assign) NSInteger followingCount;
@end

@interface IGRelationshipActions : NSObject
- (void)toggleRestrictedStatusForUserFragment:(IGUserFragment *)fragment userSession:(IGUserSession *)session analyticsModule:(id)module analyticsExtras:(id)extras withSuccessHandler:(void(^)(void))success failureHandler:(void(^)(NSError *))failure;
- (void)closeFriendsActionForUser:(IGUserFragment *)user session:(IGUserSession *)session;
- (void)updateFavoritesWithAddedUserPKs:(NSArray *)added removedUserPKs:(NSArray *)removed source:(NSString *)source analyticsModule:(id)module completion:(void(^)(BOOL))completion;
- (void)acceptMessages:(BOOL)accept userId:(NSString *)userId completion:(void(^)(BOOL))completion;
@end

// ─── Settings (Beegram engine) ────────────────────────────────────────────────

@interface BGInternalSettingsEngine : NSObject
+ (instancetype)sharedEngine;
- (void)addSettingWithKey:(NSString *)key titleArabic:(NSString *)titleAr titleEnglish:(NSString *)titleEn categoryArabic:(NSString *)categoryAr descArabic:(NSString *)descAr defaultValue:(BOOL)defaultValue;
- (BOOL)boolValueForKey:(NSString *)key;
- (void)setBoolValue:(BOOL)value forKey:(NSString *)key;
- (NSArray *)allSettings;
- (void)fetchServerBooleanSetting:(NSString *)setting defaultsKey:(NSString *)defaultsKey verifyExpected:(BOOL)expected itemTitle:(NSString *)title;
@end

@interface BGNativeBoolToggleCell : UITableViewCell
@end

@interface BGNativeHubCell : UITableViewCell
@end

@interface BGNativeValueCell : UITableViewCell
@end

@interface BGTrackerToggleCell : UITableViewCell
@end

@interface BGTrackerClearCell : UITableViewCell
@end

@interface BGAccountFeatureItem : NSObject
@property (nonatomic, retain) NSString *title;
@property (nonatomic, assign) BOOL isEnabled;
@end

@interface BGAccountFeatureNativeCell : UITableViewCell
@end

@interface BGAccountSummaryCell : UITableViewCell
@end

@interface BGIGNativeInternalSettingsViewController : UIViewController
@end

// ─── BAI — Gemini / AI ───────────────────────────────────────────────────────

@interface BAIGeminiService : NSObject
+ (instancetype)sharedService;
- (void)sendPrompt:(NSString *)prompt completion:(void(^)(NSString *response, NSError *error))completion;
@end

@interface BAIGoogleAuthManager : NSObject
+ (instancetype)sharedManager;
- (void)authenticateWithCompletion:(void(^)(BOOL success, NSString *token))completion;
- (NSString *)currentAccessToken;
- (NSString *)currentUserEmail;
- (NSString *)currentUserName;
@end

@interface BAIAutoReplyManager : NSObject
+ (instancetype)sharedManager;
- (void)enableAutoReplyForThreadId:(NSString *)threadId;
- (void)disableAutoReplyForThreadId:(NSString *)threadId;
- (BOOL)isAutoReplyEnabledForThreadId:(NSString *)threadId;
- (void)processIncomingMessage:(IGDirectThreadItem *)item inThread:(IGDirectThread *)thread;
@end

@interface BAIAutoReplySettingsViewController : UIViewController
@end

@interface BAIChatViewController : UIViewController
+ (instancetype)sharedController;
- (void)presentFromViewController:(UIViewController *)vc;
@end

@interface BAIChatMessage : NSObject
@property (nonatomic, retain) NSString *role;
@property (nonatomic, retain) NSString *content;
@property (nonatomic, retain) NSDate *timestamp;
@end

@interface BAIChatHistoryManager : NSObject
+ (instancetype)sharedManager;
- (void)addMessage:(BAIChatMessage *)message;
- (NSArray<BAIChatMessage *> *)allMessages;
- (void)clearHistory;
@end

@interface BAISettingsViewController : UIViewController
@end

@interface BAISpeechManager : NSObject
+ (instancetype)sharedManager;
- (void)speakText:(NSString *)text completion:(void(^)(BOOL success))completion;
@end

@interface BAIBackgroundPersistenceManager : NSObject
+ (instancetype)sharedManager;
- (void)startPersistence;
- (void)stopPersistence;
@end

@interface BAIGestureManager : NSObject
+ (instancetype)sharedManager;
- (void)registerGestureOnView:(UIView *)view;
@end

@interface BAIKnowledgeViewController : UIViewController
@end

@interface BAILoginViewController : UIViewController
@end

@interface BAIAIStudioScraperViewController : UIViewController
@end

@interface BAIMetaAIBridge : NSObject
+ (instancetype)sharedBridge;
- (void)interceptMetaAIResponse:(NSString *)response completion:(void(^)(NSString *modified))completion;
@end

// ─── ElevenLabs TTS ──────────────────────────────────────────────────────────

@interface ElevenLabsAPIManager : NSObject
+ (instancetype)sharedManager;
@property (nonatomic, retain) NSString *apiKey;
- (void)synthesizeText:(NSString *)text voiceId:(NSString *)voiceId completion:(void(^)(NSData *audioData, NSError *error))completion;
- (void)fetchAvailableVoicesWithCompletion:(void(^)(NSArray *voices, NSError *error))completion;
@end

@interface ElevenLabsVoiceSettings : NSObject
@property (nonatomic, assign) float stability;
@property (nonatomic, assign) float similarityBoost;
@property (nonatomic, assign) float style;
@property (nonatomic, assign) BOOL useSpeakerBoost;
@end

// ─── Voice ────────────────────────────────────────────────────────────────────

@interface VoiceController : NSObject
+ (instancetype)sharedController;
- (void)startVoiceCapture;
- (void)stopVoiceCapture;
- (void)applyVoiceEffect:(NSString *)effectId;
@end

@interface VoiceRecorderViewController : UIViewController
@end

@interface VoiceChangerSettingsViewController : UIViewController
@end

@interface VoiceDownloadHandler : NSObject
+ (instancetype)sharedHandler;
- (void)downloadVoiceModelWithId:(NSString *)modelId completion:(void(^)(BOOL success))completion;
@end

// ─── Ghost Mode ───────────────────────────────────────────────────────────────

@interface GhostModeViewController : UIViewController
@end

@interface GhostLoginViewController : UIViewController
@end

// ─── Deleted Messages ─────────────────────────────────────────────────────────

@interface DeletedMessagesManager : NSObject
+ (instancetype)sharedManager;
- (void)saveMessageBeforeDeletion:(IGDirectThreadItem *)item;
- (NSArray<IGDirectThreadItem *> *)deletedMessagesForThreadId:(NSString *)threadId;
- (void)clearDeletedMessagesForThreadId:(NSString *)threadId;
@end

@interface BeegramMessageDeleted : NSObject
@property (nonatomic, retain) NSString *messageId;
@property (nonatomic, retain) NSString *threadId;
@property (nonatomic, retain) NSString *senderId;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSDate *deletedAt;
@end

// ─── Download ─────────────────────────────────────────────────────────────────

@interface BeegramDASHDownloader : NSObject
+ (instancetype)sharedDownloader;
- (void)downloadDASHVideoWithURL:(NSString *)url completion:(void(^)(NSURL *localURL, NSError *error))completion;
@end

@interface BeegramDownloadManager : NSObject
+ (instancetype)sharedManager;
- (void)downloadMediaFromURL:(NSString *)url mediaType:(NSInteger)type completion:(void(^)(NSURL *localURL, NSError *error))completion;
- (void)saveImageToPhotos:(UIImage *)image completion:(void(^)(BOOL success, NSError *error))completion;
@end

@interface BeegramProfilePicDownloader : NSObject
+ (instancetype)sharedDownloader;
- (void)downloadProfilePicForUserId:(NSString *)userId completion:(void(^)(UIImage *image, NSError *error))completion;
@end

@interface ASHDownloader : NSObject
+ (instancetype)sharedDownloader;
- (void)downloadFromURL:(NSString *)url toPath:(NSString *)path completion:(void(^)(BOOL success, NSError *error))completion;
@end

// ─── Profile Analyzer ────────────────────────────────────────────────────────

@interface ProfileAnalyzerService : NSObject
+ (instancetype)sharedService;
- (void)analyzeProfileForUserPk:(NSString *)pk completion:(void(^)(NSDictionary *result, NSError *error))completion;
- (void)analyzeProfileWithProgress:(void(^)(float progress))progressBlock completion:(void(^)(NSDictionary *result, NSError *error))completion;
@end

@interface ProfileAnalyzerUser : NSObject
@property (nonatomic, retain) NSString *userPk;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSDictionary *analysisData;
@end

@interface ProfileAnalyzerViewController : UIViewController
@end

@interface BeegramProfilePicViewerVC : UIViewController
@end

// ─── Call Recorder ───────────────────────────────────────────────────────────

@interface BeegramCallRecorderHelper : NSObject
+ (instancetype)sharedHelper;
- (void)startRecordingCallWithId:(NSString *)callId;
- (void)stopRecording;
- (NSURL *)currentRecordingURL;
@end

@interface BeegramCallRecordingsVC : UIViewController
@end

@interface CallRecorderSettingsViewController : UIViewController
@end

// ─── Cache / Session ─────────────────────────────────────────────────────────

@interface BeegramCacheManager : NSObject
+ (instancetype)sharedManager;
- (void)cacheValue:(id)value forKey:(NSString *)key;
- (id)cachedValueForKey:(NSString *)key;
- (void)clearCache;
- (NSUInteger)cacheSizeInBytes;
@end

@interface BeegramSessionUtils : NSObject
+ (NSString *)currentUserId;
+ (NSString *)currentUsername;
+ (IGUserSession *)currentSession;
@end

// ─── UI Helpers ───────────────────────────────────────────────────────────────

@interface BeegramProgressHUD : NSObject
+ (void)showWithTitle:(NSString *)title;
+ (void)showProgress:(float)progress title:(NSString *)title;
+ (void)dismiss;
@end

@interface BeegramNotificationPillView : UIView
- (instancetype)initWithMessage:(NSString *)message;
- (void)showInView:(UIView *)superview duration:(NSTimeInterval)duration;
@end

@interface BeeGramGoldAvatarRingView : UIView
@property (nonatomic, assign) BOOL isGold;
@end

@interface BeeGramGoldProfileBackdropView : UIView
@end

@interface BeeGramChipBar : UIView
@property (nonatomic, weak) id<NSObject> delegate;
@end

// ─── Spoofer ─────────────────────────────────────────────────────────────────

@interface UIDSpooferHandler : NSObject
+ (instancetype)sharedHandler;
- (void)spoofUID:(NSString *)uid;
- (void)resetUID;
@end

@interface UUIDSpooferHandler : NSObject
+ (instancetype)sharedHandler;
- (void)spoofUUID:(NSString *)uuid;
- (void)resetUUID;
@end

// ─── Misc BeeGram UI ─────────────────────────────────────────────────────────

@interface BeeGramAppIconManager : NSObject
+ (instancetype)sharedManager;
- (NSArray *)availableIcons;
- (void)setAppIcon:(NSString *)iconName completion:(void(^)(BOOL success))completion;
@end

@interface BeeGramBackgroundManager : NSObject
+ (instancetype)sharedManager;
- (void)setBackgroundStyle:(NSInteger)style;
@end

@interface BeeGramCommentSearchManager : NSObject
+ (instancetype)sharedManager;
- (void)searchCommentsWithQuery:(NSString *)query inMediaId:(NSString *)mediaId completion:(void(^)(NSArray *results))completion;
@end

@interface BeeGramInstantsVideoStreamer : NSObject
+ (instancetype)sharedStreamer;
- (void)startStreamingForStoryItem:(IGStoryItem *)item;
@end

@interface BeegramSidebarHelper : NSObject
+ (void)addItemWithTitle:(NSString *)title icon:(NSString *)iconName action:(void(^)(void))action;
@end

@interface BeegramMSGHelper : NSObject
+ (void)showMessageInThread:(NSString *)threadId text:(NSString *)text;
@end

@interface BeeGramAssetUtils : NSObject
+ (UIImage *)imageNamed:(NSString *)name;
+ (NSData *)videoDataForPendingInstant;
@end

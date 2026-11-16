// BeegramNSE.x
// Notification Service Extension — session bridge + keychain backup + sideload fix
// Built from BeegramNSE.dylib reverse engineering

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <Security/Security.h>

// ─── Constants ────────────────────────────────────────────────────────────────

#define kBeegramKeychainBridgeActive    @"BEEGRAM_KEYCHAIN_BRIDGE_ACTIVE"
#define kBeegramAppGroup                @"com.beegram.shared.sessionbridge"
#define kBeegramCleanSlatePending       @"com.beegram.clean.slate.pending"
#define kBeegramSessionGuardPlist       @".beegram_session_guard.plist"
#define kBeegramCFPrefsSuite            @"__beegram_cfprefs_suite_migrated_v4"

#define kBackupAuthHeaders              @"beegram_backup_authheaders_v2"
#define kBackupSessionData              @"beegram_backup_sessiondata_v2"
#define kBackupLastUserPK               @"beegram_backup_last_user_pk_v2"

#define kIGGroupSessionKey              @"ig_group_session_v1"
#define kIGSessionDataKey               @"com.instagram.usersession.sessiondata"

// ─── SPKSideloadFix ───────────────────────────────────────────────────────────

@interface SPKSideloadFixGenericEntry : NSObject
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *groupID;
@property (nonatomic, assign) BOOL isActive;
- (instancetype)initWithBundleID:(NSString *)bundleID groupID:(NSString *)groupID;
- (BOOL)validateEntitlements;
- (void)applyFix;
@end

@implementation SPKSideloadFixGenericEntry

- (instancetype)initWithBundleID:(NSString *)bundleID groupID:(NSString *)groupID {
    self = [super init];
    if (self) {
        _bundleID = bundleID;
        _groupID = groupID;
        _isActive = NO;
    }
    return self;
}

- (BOOL)validateEntitlements {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:_groupID];
    _isActive = (groupURL != nil);
    return _isActive;
}

- (void)applyFix {
    if (![self validateEntitlements]) return;
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:_groupID];
    [sharedDefaults setBool:YES forKey:kBeegramKeychainBridgeActive];
    [sharedDefaults synchronize];
}

@end

@interface SPKSideloadFix : NSObject
+ (instancetype)sharedInstance;
- (void)registerEntry:(SPKSideloadFixGenericEntry *)entry;
- (void)activateAll;
@end

@implementation SPKSideloadFix {
    NSMutableArray<SPKSideloadFixGenericEntry *> *_entries;
}

+ (instancetype)sharedInstance {
    static SPKSideloadFix *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SPKSideloadFix alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
    }
    return self;
}

- (void)registerEntry:(SPKSideloadFixGenericEntry *)entry {
    [_entries addObject:entry];
}

- (void)activateAll {
    for (SPKSideloadFixGenericEntry *entry in _entries) {
        [entry applyFix];
    }
}

@end

// ─── BGSKeychainBridge ────────────────────────────────────────────────────────

@interface BGSKeychainBridge : NSObject
+ (instancetype)sharedBridge;
- (BOOL)saveData:(NSData *)data forKey:(NSString *)key;
- (NSData *)loadDataForKey:(NSString *)key;
- (BOOL)deleteDataForKey:(NSString *)key;
- (void)performSessionBackup:(NSDictionary *)sessionInfo;
- (NSDictionary *)restoreSessionBackup;
- (void)clearSessionBackup;
@end

@implementation BGSKeychainBridge

+ (instancetype)sharedBridge {
    static BGSKeychainBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BGSKeychainBridge alloc] init];
    });
    return instance;
}

- (NSMutableDictionary *)baseQueryForKey:(NSString *)key {
    return [@{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.beegram.session.bridge",
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrAccessGroup: kBeegramAppGroup
    } mutableCopy];
}

- (BOOL)saveData:(NSData *)data forKey:(NSString *)key {
    [self deleteDataForKey:key];

    NSMutableDictionary *query = [self baseQueryForKey:key];
    query[(__bridge id)kSecValueData] = data;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return status == errSecSuccess;
}

- (NSData *)loadDataForKey:(NSString *)key {
    NSMutableDictionary *query = [self baseQueryForKey:key];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        return data;
    }
    return nil;
}

- (BOOL)deleteDataForKey:(NSString *)key {
    NSMutableDictionary *query = [self baseQueryForKey:key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    return (status == errSecSuccess || status == errSecItemNotFound);
}

- (void)performSessionBackup:(NSDictionary *)sessionInfo {
    if (!sessionInfo) return;

    id authHeaders = sessionInfo[@"authHeaders"];
    if (authHeaders) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:authHeaders
                                         requiringSecureCoding:NO
                                                         error:nil];
        [self saveData:data forKey:kBackupAuthHeaders];
    }

    id sessionData = sessionInfo[@"sessionData"];
    if (sessionData) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sessionData
                                         requiringSecureCoding:NO
                                                         error:nil];
        [self saveData:data forKey:kBackupSessionData];
    }

    id userPK = sessionInfo[@"lastUserPK"];
    if (userPK) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:userPK
                                         requiringSecureCoding:NO
                                                         error:nil];
        [self saveData:data forKey:kBackupLastUserPK];
    }
}

- (NSDictionary *)restoreSessionBackup {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    NSData *headersData = [self loadDataForKey:kBackupAuthHeaders];
    if (headersData) {
        id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSDictionary class]
                                                  fromData:headersData
                                                     error:nil];
        if (!obj) obj = [NSKeyedUnarchiver unarchivedObjectOfClasses:
                         [NSSet setWithObjects:[NSDictionary class],[NSString class],[NSArray class],nil]
                                                            fromData:headersData
                                                               error:nil];
        if (obj) result[@"authHeaders"] = obj;
    }

    NSData *sessionData = [self loadDataForKey:kBackupSessionData];
    if (sessionData) {
        id obj = [NSKeyedUnarchiver unarchivedObjectOfClasses:
                  [NSSet setWithObjects:[NSDictionary class],[NSString class],[NSData class],[NSArray class],nil]
                                                    fromData:sessionData
                                                       error:nil];
        if (obj) result[@"sessionData"] = obj;
    }

    NSData *pkData = [self loadDataForKey:kBackupLastUserPK];
    if (pkData) {
        id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class]
                                                  fromData:pkData
                                                     error:nil];
        if (obj) result[@"lastUserPK"] = obj;
    }

    return result.count > 0 ? [result copy] : nil;
}

- (void)clearSessionBackup {
    [self deleteDataForKey:kBackupAuthHeaders];
    [self deleteDataForKey:kBackupSessionData];
    [self deleteDataForKey:kBackupLastUserPK];
}

@end

// ─── BGSSettingsReader ────────────────────────────────────────────────────────

@interface BGSSettingsReader : NSObject
+ (instancetype)sharedReader;
- (BOOL)boolForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
@end

@implementation BGSSettingsReader

+ (instancetype)sharedReader {
    static BGSSettingsReader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BGSSettingsReader alloc] init];
    });
    return instance;
}

- (id)_valueForKey:(NSString *)key {
    // Try app group shared defaults first
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    id val = [sharedDefaults objectForKey:key];
    if (val) return val;

    // Fall back to CFPreferences
    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFStringRef cfSuite = (__bridge CFStringRef)kBeegramCFPrefsSuite;
    CFPropertyListRef ref = CFPreferencesCopyValue(cfKey, cfSuite,
                                                   kCFPreferencesCurrentUser,
                                                   kCFPreferencesAnyHost);
    if (ref) {
        id result = (__bridge_transfer id)ref;
        return result;
    }
    return nil;
}

- (BOOL)boolForKey:(NSString *)key {
    id val = [self _valueForKey:key];
    if ([val isKindOfClass:[NSNumber class]]) return [val boolValue];
    return NO;
}

- (NSString *)stringForKey:(NSString *)key {
    id val = [self _valueForKey:key];
    if ([val isKindOfClass:[NSString class]]) return val;
    return nil;
}

@end

// ─── BGSCleanSlateGuard ───────────────────────────────────────────────────────

@interface BGSCleanSlateGuard : NSObject
+ (instancetype)sharedGuard;
- (BOOL)isCleanSlatePending;
- (void)markCleanSlatePending;
- (void)clearCleanSlatePending;
- (void)runSessionRestoreIfNeeded;
@end

@implementation BGSCleanSlateGuard

+ (instancetype)sharedGuard {
    static BGSCleanSlateGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BGSCleanSlateGuard alloc] init];
    });
    return instance;
}

- (NSURL *)_guardPlistURL {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:kBeegramAppGroup];
    if (!groupURL) return nil;
    return [groupURL URLByAppendingPathComponent:kBeegramSessionGuardPlist];
}

- (BOOL)isCleanSlatePending {
    // Check app group defaults
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    if ([sharedDefaults boolForKey:kBeegramCleanSlatePending]) return YES;

    // Check guard plist
    NSURL *plistURL = [self _guardPlistURL];
    if (!plistURL) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:plistURL.path];
}

- (void)markCleanSlatePending {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    [sharedDefaults setBool:YES forKey:kBeegramCleanSlatePending];
    [sharedDefaults synchronize];

    NSURL *plistURL = [self _guardPlistURL];
    if (plistURL) {
        NSDictionary *info = @{@"timestamp": @([[NSDate date] timeIntervalSince1970])};
        [info writeToURL:plistURL atomically:YES];
    }
}

- (void)clearCleanSlatePending {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    [sharedDefaults removeObjectForKey:kBeegramCleanSlatePending];
    [sharedDefaults synchronize];

    NSURL *plistURL = [self _guardPlistURL];
    if (plistURL) {
        [[NSFileManager defaultManager] removeItemAtURL:plistURL error:nil];
    }
}

- (void)runSessionRestoreIfNeeded {
    if (![self isCleanSlatePending]) return;

    NSDictionary *backup = [[BGSKeychainBridge sharedBridge] restoreSessionBackup];
    if (!backup) {
        [self clearCleanSlatePending];
        return;
    }

    // Write restored session to shared group container for Instagram to pick up
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    if (backup[@"authHeaders"]) {
        [sharedDefaults setObject:backup[@"authHeaders"] forKey:@"beegram_restored_auth_headers"];
    }
    if (backup[@"sessionData"]) {
        [sharedDefaults setObject:backup[@"sessionData"] forKey:kIGGroupSessionKey];
    }
    if (backup[@"lastUserPK"]) {
        [sharedDefaults setObject:backup[@"lastUserPK"] forKey:@"beegram_restored_user_pk"];
    }
    [sharedDefaults synchronize];

    [self clearCleanSlatePending];
}

@end

// ─── UNNotificationServiceExtension Hook ─────────────────────────────────────

%hook UNNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *))contentHandler {
    // Run session restore check on every notification
    [[BGSCleanSlateGuard sharedGuard] runSessionRestoreIfNeeded];

    // Activate sideload fix if needed
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup];
    if (![sharedDefaults boolForKey:kBeegramKeychainBridgeActive]) {
        SPKSideloadFixGenericEntry *entry = [[SPKSideloadFixGenericEntry alloc]
                                             initWithBundleID:@"com.burbn.instagram"
                                                      groupID:kBeegramAppGroup];
        [[SPKSideloadFix sharedInstance] registerEntry:entry];
        [[SPKSideloadFix sharedInstance] activateAll];
    }

    %orig;
}

- (void)serviceExtensionTimeWillExpire {
    %orig;
}

%end

// ─── IGLogoutManager Hook ─────────────────────────────────────────────────────

%hook IGLogoutManager

- (void)logoutUser:(id)user completion:(id)completion {
    // On logout, clear the session backup so stale data doesn't restore
    [[BGSKeychainBridge sharedBridge] clearSessionBackup];
    [[BGSCleanSlateGuard sharedGuard] clearCleanSlatePending];
    %orig;
}

- (void)logoutCurrentUserWithCompletion:(id)completion {
    [[BGSKeychainBridge sharedBridge] clearSessionBackup];
    [[BGSCleanSlateGuard sharedGuard] clearCleanSlatePending];
    %orig;
}

%end

// ─── Constructor ──────────────────────────────────────────────────────────────

%ctor {
    @autoreleasepool {
        // Register sideload fix entry
        SPKSideloadFixGenericEntry *entry = [[SPKSideloadFixGenericEntry alloc]
                                             initWithBundleID:@"com.burbn.instagram"
                                                      groupID:kBeegramAppGroup];
        [[SPKSideloadFix sharedInstance] registerEntry:entry];

        // Activate if entitlements allow
        if ([entry validateEntitlements]) {
            [[SPKSideloadFix sharedInstance] activateAll];
        }

        // Run session restore check at load
        [[BGSCleanSlateGuard sharedGuard] runSessionRestoreIfNeeded];

        NSLog(@"[BeegramNSE] loaded — bridge: %@",
              [[NSUserDefaults alloc] initWithSuiteName:kBeegramAppGroup] != nil ? @"active" : @"inactive");
    }
}

//
//  CXLogFile.m
//  TuYooSDK
//
//  Created by DCX on 2016/11/22.
//  Copyright © 2016年 戴晨惜. All rights reserved.
//

#import "CXLog.h"
#import <UIKit/UIKit.h>

@class CXLogFileInfo;

unsigned long long const kCXDefaultLogMaxFileSize      = 50 * 1024;           // 30 KB 存一次
NSTimeInterval     const kCXDefaultLogRollingFrequency = 60 * 60 * 24;        // 24 Hours 超过此时间删除
NSUInteger         const kCXDefaultLogMaxNumLogFiles   = 20;                  // 20 Files 超过此数量删除
unsigned long long const kCXDefaultLogFilesDiskQuota   = 3 * 1024 * 1024;     // 3 MB    总大小

@interface CXLoger ()

@property (nonatomic, strong, readwrite) CXLogFileManager * logFileManager;

@property (atomic, strong, readwrite) NSMutableArray <NSString *>* logs;

@property (atomic, strong, readwrite) NSMutableString * logsString;

@end

static dispatch_queue_t _saveQueue;

static NSArray const * kTypes = nil;

@implementation CXLoger

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kTypes = @[@"Info",@"Warning",@"Error"];
    });
}

static CXLoger * _instance;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc]init];
    });
    return _instance;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    kTypes = nil;
    _saveQueue = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logFileManager = [[CXLogFileManager alloc] init];
        _logs = [NSMutableArray array];
        _logsString = [NSMutableString string];
        _saveQueue = dispatch_queue_create("com.log.queue", DISPATCH_QUEUE_SERIAL);
        
        // 添加 crash时 log处理
        NSSetUncaughtExceptionHandler (&CXUncaughtExceptionHandler);
        // 添加 app kill 时 log处理
        [[NSNotificationCenter defaultCenter] addObserver:_instance selector:@selector(saveLog) name:UIApplicationWillTerminateNotification object:nil];
    }
    return self;
}

void CXUncaughtExceptionHandler(NSException *exception) {
    NSArray *arr = [exception callStackSymbols];//得到当前调用栈信息
    NSString *reason = [exception reason];//非常重要，就是崩溃的原因
    NSString *name = [exception name];//异常类型
    [_instance.logsString appendFormat:@" exception type : %@ \n crash reason : %@ \n call stack info : %@", name, reason, arr];
    [_instance saveLog];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _instance;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return _instance;
}

- (void)logFunction:(const char *)function type:(NSUInteger )type format:(NSString *)format,... {
#ifdef DEBUG
    va_list args;
    if (format) {
        va_start(args, format);
        
        NSString * message = [[NSString alloc] initWithFormat:format arguments:args];
        
        NSString * typeString = type < 3 ? kTypes[type] : @"";
        
        const char * fun = function;
//          如果不需要log function
//        if ([[[NSBundle mainBundle] bundleIdentifier] rangeOfString:@"com.loger.demo"].location == NSNotFound) {
//            fun = "";
//        }
        
        NSLog(@"%@ %s %@",typeString,fun,message);
        
        [self save_logtype:typeString message:message];
        
        va_end(args);
    }
#else
    return;
#endif
}

- (void)save_logtype:(NSString *)type message:(NSString *)message {
    
    dispatch_async(_saveQueue, ^{
        NSDateFormatter *dateFormatter = [self.logFileManager logFileDateFormatter];
        
        NSString *formattedDate = [dateFormatter stringFromDate:[NSDate date]];
        
        NSString * logString = [NSString stringWithFormat:@"%@ %@ %@",formattedDate,type,message];
        
        [self.logsString appendFormat:@"%@ \n",logString];
        
        [self.logs addObject:logString];
        
        if ([self.logsString dataUsingEncoding:NSUTF8StringEncoding].length > kCXDefaultLogMaxFileSize) {
            [self saveLog];
        }
    });
}

- (void)saveLog {
    [self.logsString writeToFile:[self.logFileManager createNewLogFile] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self.logs removeAllObjects];
    self.logsString = [NSMutableString string];
}

@end


@interface CXLogFileManager()

@property (nonatomic, copy, readwrite) NSString * logsPath;

@property (strong, nonatomic, readwrite) NSArray <NSString *>* logFilePaths;
@property (strong, nonatomic, readwrite) NSArray <NSString *>* logFileNames;
@property (strong, nonatomic, readwrite) NSArray <CXLogFileInfo *>* logFileInfos;

@end

@implementation CXLogFileManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _logsPath = _logsPath ? _logsPath : [self defaultLogsPath];
        _logFileDiskQuota = _logFileDiskQuota != 0 ? _logFileDiskQuota : kCXDefaultLogFilesDiskQuota;
        _maxNumberOfLogFiles = _maxNumberOfLogFiles != 0 ? _maxNumberOfLogFiles : kCXDefaultLogMaxNumLogFiles;
    }
    return self;
}

- (NSString *)applicationName {
    static NSString *_appName;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        
        if (!_appName) {
            _appName = [[NSProcessInfo processInfo] processName];
        }
        
        if (!_appName) {
            _appName = @"";
        }
    });
    
    return _appName;
}
static NSDateFormatter * kFormatter ;

- (NSDateFormatter *)logFileDateFormatter {
    
    if (!kFormatter) {
        NSMutableDictionary *dictionary = [[NSThread currentThread]
                                           threadDictionary];
        NSString *dateFormat = @"yyyy'-'MM'-'dd' 'HH'-'mm'";
        NSString *key = [NSString stringWithFormat:@"logFileDateFormatter.%@", dateFormat];
        NSDateFormatter *dateFormatter = dictionary[key];
        
        if (dateFormatter == nil) {
            dateFormatter = [[NSDateFormatter alloc] init];
//            [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
            [dateFormatter setDateFormat:dateFormat];
//            [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            dictionary[key] = dateFormatter;
        }
        kFormatter = dateFormatter;
    }
    return kFormatter;
}

- (NSString *)newLogFileName {
    NSString *appName = [self applicationName];
    
    NSDateFormatter *dateFormatter = [self logFileDateFormatter];
    NSString *formattedDate = [dateFormatter stringFromDate:[NSDate date]];
    
    return [NSString stringWithFormat:@"%@ %@.log", appName, formattedDate];
}

- (NSString *)defaultLogsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *logsPath = [baseDir stringByAppendingPathComponent:@"Logs"];
    return logsPath;
}

- (NSString *)logsPath {
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_logsPath]) {
        NSError *err = nil;
        
        if (![[NSFileManager defaultManager] createDirectoryAtPath:_logsPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&err]) {
        }
    }
    
    return _logsPath;
}

- (NSString *)createNewLogFile {
    NSString *fileName = [self newLogFileName];
    NSString *logsPath = [self logsPath];
    
    NSUInteger attempt = 1;
    
    /** 创建新的文件 */
    do {
        NSString *actualFileName = fileName;
        if (attempt > 1) {
            // 2.fileName已经存在 更换fileName（.log之前加上 attempt 做区分）
            NSString *extension = [actualFileName pathExtension];
            
            actualFileName = [actualFileName stringByDeletingPathExtension];
            actualFileName = [actualFileName stringByAppendingFormat:@" %lu", (unsigned long)attempt];
            
            if (extension.length) { // 如果是文件类型（包含.log后缀）
                actualFileName = [actualFileName stringByAppendingPathExtension:extension];
            }
        }
        
        NSString * filePath = [logsPath stringByAppendingPathComponent:actualFileName];
        // 1. 判断文件是否存在
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
         
            NSString *value = doesAppRunInBackground() ? NSFileProtectionCompleteUntilFirstUserAuthentication : NSFileProtectionCompleteUnlessOpen;
            
            NSDictionary * attributes = @{
                                          NSFileProtectionKey: value
                                          };
            // 3.创建文件
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:attributes];
            
            // 删除旧文件
            [self deleteOldLogFiles];
            
            return filePath;
            
        }else {
            attempt += 1;
        }
    }while (YES);
    
    return @"";
}

- (NSArray *)logFilePaths {
    NSString *logsPath = [self logsPath];
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsPath error:nil];
    
    NSMutableArray * tempArray = [NSMutableArray arrayWithCapacity:fileNames.count];
    [fileNames enumerateObjectsUsingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self isLogFile:obj]) {
            NSString * filePath = [logsPath stringByAppendingPathComponent:obj];
            [tempArray addObject:filePath];
        }
    }];
    
    return tempArray;
}

- (NSArray *)logFileNames {
    NSArray *logFilePaths = [self logFilePaths];
    NSMutableArray *logFileNames = [NSMutableArray arrayWithCapacity:[logFilePaths count]];
    for (NSString *filePath in logFilePaths) {
        [logFileNames addObject:[filePath lastPathComponent]];
    }
    return logFileNames;
}

- (NSArray <CXLogFileInfo *>*)logFileInfos {
    NSArray *logFilePaths = [self logFilePaths];
    NSMutableArray *logFileInfos = [NSMutableArray arrayWithCapacity:[logFilePaths count]];
    for (NSString *filePath in logFilePaths) {
        CXLogFileInfo *logFileInfo = [CXLogFileInfo logFileWithPath:filePath];
        [logFileInfos addObject:logFileInfo];
    }
    return logFileInfos;
}

- (NSArray *)sortedLogFilePaths {
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
    NSMutableArray *sortedLogFilePaths = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
    for (CXLogFileInfo *logFileInfo in sortedLogFileInfos) {
        [sortedLogFilePaths addObject:[logFileInfo filePath]];
    }
    return sortedLogFilePaths;
}

- (NSArray *)sortedLogFileNames {
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
    NSMutableArray *sortedLogFileNames = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
    for (CXLogFileInfo *logFileInfo in sortedLogFileInfos) {
        [sortedLogFileNames addObject:[logFileInfo fileName]];
    }
    return sortedLogFileNames;
}

- (NSArray *)sortedLogFileInfos {
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wundeclared-selector"
    return [[self logFileInfos] sortedArrayUsingSelector:@selector(reverseCompareByCreationDate:)];
#pragma clang diagnostic pop
}

- (BOOL)isLogFile:(NSString *)fileName {
    NSString *appName = [self applicationName];
    
    BOOL hasProperPrefix = [fileName hasPrefix:appName];
    BOOL hasProperSuffix = [fileName hasSuffix:@".log"];
 
    return hasProperPrefix && hasProperSuffix;
}

- (void)deleteOldLogFiles {
    
    NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
    NSUInteger firstIndexToDelete = NSNotFound;
    
    const unsigned long long diskQuota = self.logFileDiskQuota;
    const NSUInteger maxNumLogFiles = self.maxNumberOfLogFiles;
    
    if (diskQuota) {
        unsigned long long used = 0;
        
        for (NSUInteger i = 0; i < sortedLogFileInfos.count; i++) {
            CXLogFileInfo *info = sortedLogFileInfos[i];
            used += info.fileSize;
            
            if (used > diskQuota) {
                firstIndexToDelete = i;
                break;
            }
            
            if (info.age > kCXDefaultLogRollingFrequency) {
                firstIndexToDelete = i;
                break;
            }
        }
    }
    
    if (maxNumLogFiles) {
        if (firstIndexToDelete == NSNotFound) {
            firstIndexToDelete = maxNumLogFiles;
        } else {
            firstIndexToDelete = MIN(firstIndexToDelete, maxNumLogFiles);
        }
    }
    
    if (firstIndexToDelete != NSNotFound) {
        for (NSUInteger i = firstIndexToDelete; i < sortedLogFileInfos.count; i++) {
            CXLogFileInfo *logFileInfo = sortedLogFileInfos[i];
            [[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:nil];
        }
    }
    
}

/** 判断 app 是否在后台 */
BOOL doesAppRunInBackground() {
    BOOL answer = NO;
    
    NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
    
    for (NSString *mode in backgroundModes) {
        if (mode.length > 0) {
            answer = YES;
            break;
        }
    }
    return answer;
}

@end

@interface CXLogFileInfo()

@property (strong, nonatomic, readwrite) NSString *filePath;
@property (strong, nonatomic, readwrite) NSString *fileName;
@property (strong, nonatomic, readwrite) NSDictionary<NSString *, id> *fileAttributes;
@property (strong, nonatomic, readwrite) NSDate *creationDate;
@property (strong, nonatomic, readwrite) NSDate *modificationDate;
@property (nonatomic, readwrite) unsigned long long fileSize;
@property (nonatomic, readwrite) NSTimeInterval age;

@end

@implementation CXLogFileInfo

+ (instancetype)logFileWithPath:(NSString *)filePath {
    return [[CXLogFileInfo alloc] initWithPath:filePath];
}

- (instancetype)initWithPath:(NSString *)filePath {
    self = [super init];
    if (self) {
        self.filePath = [filePath copy];
    }
    return self;
}

- (NSDictionary<NSString *,id> *)fileAttributes {
    if (!_fileAttributes) {
        _fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil];
    }
    return _fileAttributes;
}

- (NSString *)fileName {
    if (!_fileName) {
        _fileName = [self.filePath lastPathComponent];
    }
    return _fileName;
}

- (NSDate *)creationDate {
    if (!_creationDate) {
        _creationDate = self.fileAttributes[NSFileCreationDate];
    }
    return _creationDate;
}

- (NSDate *)modificationDate {
    if (!_modificationDate) {
        _modificationDate = self.fileAttributes[NSFileModificationDate];
    }
    return _modificationDate;
}

- (unsigned long long)fileSize {
    if (_fileSize == 0) {
        _fileSize = [self.fileAttributes[NSFileSize] unsignedLongLongValue];
    }
    return _fileSize;
}

- (NSTimeInterval)age {
    return [[self creationDate] timeIntervalSinceNow] * -1.0;
}

- (NSComparisonResult)reverseCompareByCreationDate:(CXLogFileInfo *)another {
    NSDate *us = [self creationDate];
    NSDate *them = [another creationDate];
    
    NSComparisonResult result = [us compare:them];
    
    if (result == NSOrderedAscending) {
        return NSOrderedDescending;
    }
    
    if (result == NSOrderedDescending) {
        return NSOrderedAscending;
    }
    return NSOrderedSame;
}

- (NSString *)description {
    return [@{ @"filePath": self.filePath ? : @"",
               @"fileName": self.fileName ? : @"",
               @"fileAttributes": self.fileAttributes ? : @"",
               @"creationDate": self.creationDate ? : @"",
               @"modificationDate": self.modificationDate ? : @"",
               @"fileSize": @(self.fileSize),
               @"age": @(self.age)} description];
}


@end

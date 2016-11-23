//
//  CXLogFile.h
//  TuYooSDK
//
//  Created by DCX on 2016/11/22.
//  Copyright © 2016年 戴晨惜. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CXLogFileInfo;
@class CXLogFileManager;
@class CXLog;

/** 
 *  CXLog log 内容存本地化处理
 *  自动处理文件数量、大小 （可配置）
 *  crash、app kill 时log处理
 */

#define CXLog(...)       [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:0 format:__VA_ARGS__];
#define CXLogWarn(...)   [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:1 format:__VA_ARGS__];
#define CXLogError(...)  [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:2 format:__VA_ARGS__];

extern unsigned long long const kCXDefaultLogMaxFileSize;       // 内存阈值 多大存一次
extern NSTimeInterval     const kCXDefaultLogRollingFrequency;  // 时间阈值 多久之前的删除
extern NSUInteger         const kCXDefaultLogMaxNumLogFiles;    // 文件数量阈值 超过此数量删除
extern unsigned long long const kCXDefaultLogFilesDiskQuota;    // 文件总占本地空间 超过删除

@interface CXLoger : NSObject

@property (nonatomic, strong, readonly) CXLogFileManager * logFileManager;
@property (atomic, strong, readonly)    NSMutableArray <NSString *>* logs;

+ (instancetype)sharedInstance;

- (void)logFunction:(const char *)function type:(NSUInteger )type format:(NSString *)format,...;

@end

@interface CXLogFileManager : NSObject

@property (atomic, readwrite, assign)   unsigned long long logFileDiskQuota;
@property (atomic, readwrite, assign)   NSUInteger maxNumberOfLogFiles;
@property (nonatomic, copy, readonly)   NSString * logsPath;
@property (strong, nonatomic, readonly) NSArray <NSString *>* logFilePaths;
@property (strong, nonatomic, readonly) NSArray <NSString *>* logFileNames;
@property (strong, nonatomic, readonly) NSArray <CXLogFileInfo *>* logFileInfos;

- (NSString *)createNewLogFile;

- (NSDateFormatter *)logFileDateFormatter;

@end

@interface CXLogFileInfo : NSObject

@property (strong, nonatomic, readonly) NSString *filePath;
@property (strong, nonatomic, readonly) NSString *fileName;
@property (strong, nonatomic, readonly) NSDictionary<NSString *, id> *fileAttributes;
@property (strong, nonatomic, readonly) NSDate *creationDate;
@property (strong, nonatomic, readonly) NSDate *modificationDate;
@property (nonatomic, readonly) unsigned long long fileSize;
@property (nonatomic, readonly) NSTimeInterval age;

+ (instancetype)logFileWithPath:(NSString *)filePath;

@end

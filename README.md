# CXLoger

---

[TOC]


调试时总会遇到没有办法及时看到log的情况，所以写了这个 log 本地化处理

* 已实现

    
    1. 本类可以自动处理文件数量、大小、（可配置）

    2. crash、以及 app kill 时本地数据不会丢失，并把crash信息存入

    3. 多线程 并发无碍

### 用法

* 利用宏 

```Objective-C

CXLog(@" %@ , %@ , %@",arg1,arg2,arg3);

```

* **声明**

```Objective-C

#define CXLog(...) [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:0 format:__VA_ARGS__];

#define CXLogWarn(...) [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:1 format:__VA_ARGS__];

#define CXLogError(...) [[CXLoger sharedInstance] logFunction:__PRETTY_FUNCTION__ type:2 format:__VA_ARGS__];

```

### 可配置项

```Objective-C

extern unsigned long long const kCXDefaultLogMaxFileSize; // 内存阈值 多大存一次

extern NSTimeInterval const kCXDefaultLogRollingFrequency; // 时间阈值 多久之前的删除

extern NSUInteger const kCXDefaultLogMaxNumLogFiles; // 文件数量阈值 超过此数量删除

extern unsigned long long const kCXDefaultLogFilesDiskQuota; // 文件总占本地空间 超过删除

```


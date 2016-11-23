//
//  ViewController.m
//  CXLoger
//
//  Created by DCX on 2016/11/23.
//  Copyright © 2016年 戴晨惜. All rights reserved.
//

#import "ViewController.h"
#import "CXLog.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    

    NSString * fileInfo = @"        \n~~~~江雪~~~~\n \
        千山鸟飞绝，万径人踪灭。\n \
        孤舟蓑笠翁，独钓寒江雪。\n";
    
    // 获得全局的并发队列
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 多线程并发无碍
    dispatch_async(queue, ^{
        for (NSInteger i = 0; i<30; i++) {
            CXLog(@"%@ , %@ , %@",fileInfo,fileInfo,fileInfo);
        }
    });
    dispatch_async(queue, ^{
        for (NSInteger i = 0; i<30; i++) {
            CXLog(@"%@ , %@ , %@",fileInfo,fileInfo,fileInfo);
        }
    });
    dispatch_async(queue, ^{
        for (NSInteger i = 0; i<30; i++) {
            CXLog(@"%@ , %@ , %@",fileInfo,fileInfo,fileInfo);
        }
    });
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    
    NSLog(@"\n\n\n  文件路径  %@", baseDir);
    
}

@end

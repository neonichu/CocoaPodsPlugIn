//
//  CocoaPodsPlugIn.m
//  CocoaPodsPlugIn
//
//  Created by Boris Bügling on 19.09.13.
//    Copyright (c) 2013 Boris Bügling. All rights reserved.
//

#import <objc/runtime.h>

#import "CocoaPodsPlugIn.h"

void Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    
    if (class_addMethod(c, orig,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, new,
                            method_getImplementation(origMethod),
                            method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

@implementation CocoaPodsPlugIn


+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

- (id)init
{
    if (self = [super init]) {
        Class clazz = NSClassFromString(@"IDECapsuleView");
        SEL newSelector = @selector(bbu_initWithCapsuleViewController:);
        SEL originalSelector = @selector(initWithCapsuleViewController:);
        
        IMP imp = imp_implementationWithBlock(^(id sself, id vc) {
            NSLog(@"IDEKit: %@\n%@", sself, vc);
            //[sself performSelector:@selector(_subtreeDescription)];
            
            return [sself performSelector:newSelector withObject:vc];
        });
        
        if (!clazz) {
            NSLog(@"IDEKit: Class not found.");
        }
        
        Method m = class_getInstanceMethod(clazz, originalSelector);
        if (!class_addMethod(clazz, newSelector, imp, method_getTypeEncoding(m))) {
            NSLog(@"IDEKit: Something went wrong!");
        }
        
        Swizzle(clazz, originalSelector, newSelector);
        
        NSLog(@"IDEKit: Added logs");
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

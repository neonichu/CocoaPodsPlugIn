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

void SwizzleWithBlock(Class clazz, SEL originalSelector, SEL newSelector, id block) {
    IMP imp = imp_implementationWithBlock(block);
    
    if (!clazz) {
        NSLog(@"CocoaPodsPlugIn: Class not found.");
    }
    
    Method m = class_getInstanceMethod(clazz, originalSelector);
    if (!class_addMethod(clazz, newSelector, imp, method_getTypeEncoding(m))) {
        NSLog(@"CocoaPodsPlugIn: Something went wrong!");
    }
    
    Swizzle(clazz, originalSelector, newSelector);
    
    NSLog(@"CocoaPodsPlugIn: Swizzled %@", NSStringFromSelector(originalSelector));
}

void LogMethods(Class clazz) {
    unsigned int methodCount;
    Method* methods = class_copyMethodList(clazz, &methodCount);
    
    for (int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        char returnType[255];
        method_getReturnType(methods[i], returnType, 255);
        NSLog(@"CocoaPodsPlugIn: %s %@", returnType, NSStringFromSelector(selector));
    }
    
    free(methods);
    
    Class superclass = class_getSuperclass(clazz);
    
    if (superclass) {
        LogMethods(superclass);
    }
}

#pragma mark -

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
        SEL newSelector = @selector(bbu_initWithCapsuleViewController:);
        SwizzleWithBlock(NSClassFromString(@"IDECapsuleView"), @selector(initWithCapsuleViewController:), newSelector,
                         ^(id sself, id vc) {
            NSLog(@"CocoaPodsPlugIn: %@\n%@", sself, vc);
            //[sself performSelector:@selector(_subtreeDescription)];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [sself performSelector:newSelector withObject:vc];
#pragma clang diagnostic pop
        });
        
        Class thing = NSClassFromString(@"SummaryTargetFrameworksViewController");
        
        LogMethods(thing);
        
        newSelector = @selector(bbu_titleForDisplay);
        SwizzleWithBlock(thing, @selector(titleForDisplay), newSelector,
                         ^(id sself) {
                             return @"YOLO!";
                             //return [sself performSelector:newSelector];
                         });
        
        newSelector = @selector(bbu_numberOfRowsInTableView:);
        SwizzleWithBlock(thing, @selector(numberOfRowsInTableView:), newSelector, ^(id sself, id tableView) {
            return 1;
        });
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

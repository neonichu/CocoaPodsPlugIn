//
//  CocoaPodsPlugIn.m
//  CocoaPodsPlugIn
//
//  Created by Boris Bügling on 19.09.13.
//    Copyright (c) 2013 Boris Bügling. All rights reserved.
//

#import <objc/runtime.h>

#import "CCPWorkspaceManager.h"
#import "CocoaPodsPlugIn.h"

@interface DVTImageAndTextCell : NSTextFieldCell

@property(copy) NSString *subtitle;

@end

@interface NSObject (Yolo)

- (NSCell *)bbu_tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
- (id)bbu_tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;

@end

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

+ (NSArray*)listOfCurrentPods {
    //NSLog(@"CocoaPodsPlugIn: podfile path: %@", [CCPWorkspaceManager currentWorkspacePodfilePath]);
    NSString* podfilePath = @"/Users/neonacho/Temp/ReplaceMinusView/Podfile"; //[CCPWorkspaceManager xx_currentWorkspacePodfilePath];
    NSString* podfile = [NSString stringWithContentsOfFile:podfilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableArray* pods = [@[] mutableCopy];
    NSString* pod;
    NSScanner* scanner = [NSScanner scannerWithString:podfile];
    while (true) {
        [scanner scanUpToString:@"pod '" intoString:nil];
        
        if (scanner.isAtEnd) {
            break;
        }
        
        [scanner setScanLocation:scanner.scanLocation + @"pod '".length];
        
        if (![scanner scanUpToString:@"'" intoString:&pod]) {
            break;
        }
        
        if (pod.length > 0) {
            [pods addObject:pod];
        }
    };
    
    return [pods copy];
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
            NSArray* pods = [[self class] listOfCurrentPods];
            //NSLog(@"Pods: %@", pods);
            return pods.count;
        });
        
#if 0
        newSelector = @selector(bbu_tableView:objectValueForTableColumn:row:);
        SwizzleWithBlock(thing, @selector(tableView:objectValueForTableColumn:row:), newSelector,
                         ^(id sself, NSTableView* tableView, NSTableColumn* col, NSInteger row) {
                             NSLog(@"%@", col.identifier);
                             
                             if ([col.identifier isEqualToString:@"name"]) {
                                
                                 
                                 //NSArray* pods = [[self class] listOfCurrentPods];
                                 //return pods[row];
                                 
                             } else {
                                 NSLog(@"fu");
                             }
                             
                             id foo = [sself bbu_tableView:tableView objectValueForTableColumn:col row:row];
                             NSLog(@"%@: %@", col.identifier, foo);
                             return foo;
                         });
#endif
        
        newSelector = @selector(bbu_tableView:dataCellForTableColumn:row:);
        SwizzleWithBlock(thing, @selector(tableView:dataCellForTableColumn:row:), newSelector,
                         ^(id sself, NSTableView* tableView, NSTableColumn* col, NSInteger row) {
                             NSCell* cell = [sself bbu_tableView:tableView dataCellForTableColumn:col row:row];
                             //cell.title = @"Superstar Marin";
                             NSLog(@"cell: %@", cell);
                             
                             if ([NSStringFromClass(cell.class) isEqualToString:@"IDENavigatorDataCell"]) {
                                 DVTImageAndTextCell* dtvCell = (DVTImageAndTextCell*)cell;
                                 dtvCell.subtitle = @"Superstar Marin";
                             }
                             
                             return cell;
                         });
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

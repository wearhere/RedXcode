//
//  RedXcode.m
//  RedXcode
//
//  Created by Orta on 21/07/2014.
//    Copyright (c) 2014 Orta Therox. All rights reserved.
//

#import "RedXcode.h"
#import "ORDebuggerCheck.h"

@import QuartzCore;

static RedXcode *sharedPlugin;

static CGFloat ORHueShiftAmount = 27.31;
static NSString *ORHueShiftKey = @"ORHueShiftKey";

@interface NSObject (IDEKit)
+ (id) workspaceWindowControllers;
@end

// https://bugs.webkit.org/attachment.cgi?id=234725&action=prettypatch
@interface NSView (AppKitDetails)
- (void)_addKnownSubview:(NSView *)subview;
@end

@implementation RedXcode

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    self = [super init];
    if (!self) return nil;
    if (!self.isRunningInGDB) return nil;

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
          ORHueShiftKey: @(ORHueShiftAmount)
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeWindows) name:NSWindowDidBecomeKeyNotification object:nil];

    NSApplication *app = [NSApplication sharedApplication];
    NSImage *appIcon = [app applicationIconImage];
    [app setApplicationIconImage:[self coloredImage:appIcon]];

    [self changeWindows];

    return self;
}

- (void)changeWindows
{
    @try {
        NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
        for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
            [self setupBannerForWindow:window];
        }
    }
    @catch (NSException *exception) { }
}

static CGFloat ORRedXcodeBannerTag = 2323;

- (void)setupBannerForWindow:(NSWindow *)window
{
    if ([window isKindOfClass:NSClassFromString(@"IDEWorkspaceWindow")]) {
        NSView *windowFrameView = [[window contentView] superview];
        NSImageView *bannerView = [windowFrameView viewWithTag:ORRedXcodeBannerTag];

        if (!bannerView) {
            CGFloat y = CGRectGetHeight(windowFrameView.bounds) - 22;
            CGFloat x = CGRectGetWidth(windowFrameView.bounds) - 22;

            bannerView = [[NSImageView alloc] initWithFrame:CGRectMake(x, y, 20, 20)];
            bannerView.image = [NSApplication sharedApplication].applicationIconImage;
            bannerView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin | NSViewWidthSizable;

            if ([windowFrameView respondsToSelector:@selector(_addKnownSubview:)]) {
                [(id)windowFrameView _addKnownSubview:bannerView];
            } else {
                [windowFrameView addSubview:bannerView];
            }

        }
    }
}

- (NSImage *)coloredImage:(NSImage *)image
{
    CIImage *inputImage = [[CIImage alloc] initWithData:[image TIFFRepresentation]];

    CIFilter *hueAdjust = [CIFilter filterWithName:@"CIHueAdjust"];
    [hueAdjust setValue: inputImage forKey: @"inputImage"];

    NSNumber *colorValue = [[NSUserDefaults standardUserDefaults] objectForKey:ORHueShiftKey];
    [hueAdjust setValue:colorValue forKey: @"inputAngle"];

    CIImage *outputImage = [hueAdjust valueForKey: @"outputImage"];
    NSImage *resultImage = [[NSImage alloc] initWithSize:[outputImage extent].size];
    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:outputImage];
    [resultImage addRepresentation:rep];

    return resultImage;
}

- (BOOL)isRunningInGDB
{
    return [ORDebuggerCheck isInDebugger];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

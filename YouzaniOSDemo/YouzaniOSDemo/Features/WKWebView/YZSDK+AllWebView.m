//
//  YZSDK+AllWebView.m
//  YouzaniOSDemo
//
//  Created by YLCHUN on 2017/7/14.
//  Copyright © 2017年 ylchun. All rights reserved.
//

#import "YZSDK+AllWebView.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "AYWKWebView.h"

static void yz_replaceMethod(Class class, SEL originSelector, SEL newSelector) {
    Method oriMethod = class_getInstanceMethod(class, originSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    BOOL isAddedMethod = class_addMethod(class, originSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (isAddedMethod) {
        class_replaceMethod(class, newSelector, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, newMethod);
    }
}

@implementation NSObject (YZUserState)
static WKProcessPool* yz_shareProcessPool() {
    static WKProcessPool *kProcessPool;;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kProcessPool = [[WKProcessPool alloc] init];
    });
    return kProcessPool;
}

static NSMutableURLRequest* yz_cookie_set_request() {
    static NSMutableURLRequest *kRequest;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://h5.youzan.com/v2/showcase/homepage?alias=juhos0"]];
    });
    return kRequest;
}

static WKWebView *webView_processPool() {
    static WKWebView* kWebView;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.processPool = yz_shareProcessPool();
        kWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    });
    return kWebView;
}

static NSMutableDictionary* yz_cookieDict() {
    static NSMutableDictionary *kDict;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kDict = [NSMutableDictionary dictionary];
    });
    return kDict;
}

static void setYZCookie(NSString *aKey, NSString*anValue) {
    WKWebView *webView = webView_processPool();
    NSMutableURLRequest *request = yz_cookie_set_request();
    [request setValue:[NSString stringWithFormat:@"%@=%@",aKey,anValue] forHTTPHeaderField:@"Cookie"];
    [webView loadRequest:request];
    yz_cookieDict()[aKey] = anValue;
    NSLog(@"YZCookie_setYZCookie");
}

static void cleYZCookie() {
    NSArray *allKeys = yz_cookieDict().allKeys;
    [yz_cookieDict() removeAllObjects];
    NSMutableString *str = [NSMutableString string];
    for (NSString* key in allKeys) {
        [str appendFormat:@"%@=%@",key,@"nil"];
    }
    WKWebView *webView = webView_processPool();
    NSMutableURLRequest *request = yz_cookie_set_request();
    [request setValue:str forHTTPHeaderField:@"Cookie"];
    [webView loadRequest:request];
    NSLog(@"YZCookie_cleYZCookie");
}


+(void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = NSClassFromString(@"YZUserState");
        yz_replaceMethod(class, NSSelectorFromString(@"setCookieValue:forCookieKey:"), @selector(yz_setCookieValue:forCookieKey:));
        yz_replaceMethod(class, NSSelectorFromString(@"logoutWithWkWebView:"), @selector(yz_logoutWithWkWebView:));
    });
}

-(void)yz_setCookieValue:(NSString*)anValue forCookieKey:(NSString*)aKey {
    setYZCookie(aKey,anValue);
    [self yz_setCookieValue:anValue forCookieKey:aKey];
}

-(void)yz_logoutWithWkWebView:(id)webView {
    cleYZCookie();
    [self yz_logoutWithWkWebView:webView];
}

@end


@implementation YZSDK (AllWebView)

+(id)webView {
    id webView = objc_getAssociatedObject(self, sel_registerName("_kWebView"));
    return webView;
}
+(void)setWebView:(id)webView {
    objc_setAssociatedObject(self, sel_registerName("_kWebView"), webView, OBJC_ASSOCIATION_ASSIGN);
}

+(void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = object_getClass(self);
        yz_replaceMethod(class.class, @selector(noticeFromYouzanWithUrl:), @selector(yz_noticeFromYouzanWithUrl:));
    });
}
+ (WKWebView*)wkWebViewWithWKClass:(WKWebViewClass)wkCls configuration:(WKWebViewConfiguration*)configuration {
    Class cls = [WKWebView class];
    if (wkCls == NULL) {
        wkCls = cls;
    }
    if (wkCls == cls || [wkCls isSubclassOfClass:cls]) {
        if (!configuration) {
            configuration = [[WKWebViewConfiguration alloc] init];
        }
        configuration.processPool = yz_shareProcessPool();
        WKWebView *webView = [[wkCls alloc] initWithFrame:CGRectZero configuration:configuration];
        return webView;
    }
    return nil;
}

+ (void)initYouzanWithWebView:(id)webView {
    [self initYouzanWithUIWebView:webView];
    self.webView = webView;
}

+ (void)shareActionWithWebView:(id)webView {
    [self shareActionWithUIWebView:webView];
}

+ (YZNotice*)yz_noticeFromYouzanWithUrl:(NSURL*)URL {
    YZNotice *yzNotice = [self yz_noticeFromYouzanWithUrl:URL];
    NSString *url = URL.absoluteString;
    if ([url containsString:@"alipay://"]) {
        id webView = self.webView;
        if ([webView isKindOfClass:[WKWebView class]] && [[UIApplication sharedApplication] canOpenURL:URL]) {
            [[UIApplication sharedApplication] openURL:URL];
            yzNotice.notice = IsYouzanNotice;
        }
    }
    return yzNotice;
}

@end



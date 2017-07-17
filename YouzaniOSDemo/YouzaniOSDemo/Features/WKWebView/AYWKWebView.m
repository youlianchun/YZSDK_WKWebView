//
//  AYWKWebView.m
//  AYWKWebView
//
//  Created by YLCHUN on 2017/5/27.
//  Copyright © 2017年 ylchun. All rights reserved.
//

#import "AYWKWebView.h"
#import <objc/runtime.h>

void aywkobjc_setAssociated(id target, SEL property, id value , BOOL retain) {
    objc_setAssociatedObject(target, property, value, retain?OBJC_ASSOCIATION_RETAIN_NONATOMIC:OBJC_ASSOCIATION_ASSIGN);
}

id aywkobjc_getAssociated(id target, SEL property) {
    return objc_getAssociatedObject(target, property);
}

void aywkw_setAssociated(id target, NSString *propertyName, id value , BOOL retain) {
    objc_setAssociatedObject(target, NSSelectorFromString(propertyName), value, retain?OBJC_ASSOCIATION_RETAIN_NONATOMIC:OBJC_ASSOCIATION_ASSIGN);
}

id aywkw_getAssociated(id target, NSString *propertyName) {
    return objc_getAssociatedObject(target, NSSelectorFromString(propertyName));
}

void aywkw_replaceMethod(Class class, SEL originSelector, SEL newSelector) {
    Method oriMethod = class_getInstanceMethod(class, originSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    BOOL isAddedMethod = class_addMethod(class, originSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (isAddedMethod) {
        class_replaceMethod(class, newSelector, method_getImplementation(oriMethod), method_getTypeEncoding(oriMethod));
    } else {
        method_exchangeImplementations(oriMethod, newMethod);
    }
}

static NSString * const kWebViewEstimatedProgress = @"estimatedProgress";
static NSString * const kWebViewCanGoBack = @"canGoBack";
static NSString * const kWebViewCanGoForward = @"canGoForward";
static NSString * const kWebViewTitle = @"title";

static NSString * const kWebViewUrl = @"URL";//请求的url
static NSString * const kWebViewLoading = @"loading";//当前是否正在加载网页
static NSString * const kWebViewCertificateChain = @"certificateChain";//当前导航的证书链
static NSString * const kWebViewHasOnlySecureContent = @"hasOnlySecureContent";//标识页面中的所有资源是否通过安全加密连接来加载

@interface WkObserver : NSObject
@end
@implementation WkObserver
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    id newValue = [change objectForKey:@"new"];
    AYWKWebView<AYWKObserverDelegate> *webView = object;
    if ([keyPath isEqualToString:kWebViewEstimatedProgress] && [webView respondsToSelector:@selector(webView:estimatedProgress:)]) {
        [webView webView:webView estimatedProgress:[newValue doubleValue]];
        return;
    }
    if ([keyPath isEqualToString:kWebViewCanGoBack] && [webView respondsToSelector:@selector(webView:canGoBackChange:)]) {
        [webView webView:webView canGoBackChange:[newValue boolValue]];
        return;
    }
    if ([keyPath isEqualToString:kWebViewCanGoForward] && [webView respondsToSelector:@selector(webView:canGoForwardChange:)]) {
        [webView webView:webView canGoForwardChange:[newValue boolValue]];
        return;
    }
    if ([keyPath isEqualToString:kWebViewTitle] && [webView respondsToSelector:@selector(webView:titleChange:)]) {
        [webView webView:webView titleChange:newValue];
        return;
    }
    if ([keyPath isEqualToString:kWebViewUrl] && [webView respondsToSelector:@selector(webView:urlChange:)]) {
        [webView webView:webView urlChange:newValue];
        return;
    }
    if ([keyPath isEqualToString:kWebViewLoading] && [webView respondsToSelector:@selector(webView:loadingChange:)]) {
        [webView webView:webView loadingChange:[newValue boolValue]];
        return;
    }
    if ([keyPath isEqualToString:kWebViewCertificateChain] && [webView respondsToSelector:@selector(webView:certificateChainChange:)]) {
        [webView webView:webView certificateChainChange:newValue];
        return;
    }
    if ([keyPath isEqualToString:kWebViewHasOnlySecureContent] && [webView.observerDelegate respondsToSelector:@selector(webView:hasOnlySecureContentChange:)]) {
        [webView webView:webView hasOnlySecureContentChange:[newValue boolValue]];
        return;
    }
}

@end


@interface AYWKWebView ()


@property (nonatomic, weak) UIScreenEdgePanGestureRecognizer *backNavigationGesture;
@property (nonatomic, weak) UIScreenEdgePanGestureRecognizer *forwardNavigationGesture;

@property (nonatomic, weak) UIGestureRecognizer *webTouchEventsGesture;

@property (nonatomic, weak) UILongPressGestureRecognizer *selectionGesture;
@property (nonatomic, weak) UILongPressGestureRecognizer *longPressGesture;

@property (nonatomic, strong) WkObserver *wkObserver;
@property (nonatomic, assign) BOOL wkObserverEnabled;

@property (nonatomic, weak) id navigationDelegateReceiver;
@property (nonatomic, weak) id UIDelegateReceiver;
@property (nonatomic, weak) id observerDelegateReceiver;

@end


@implementation UIView (WKContentView)

static NSString *kLongPressRecognizedFlag = @"_longPressRecognized:";
Class k_UITextSelectionForceGesture_Class (){
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cls = NSClassFromString(@"_UITextSelectionForceGesture");
    });
    return cls;
}
Class k_UIWebTouchEventsGestureRecognizer_Class (){
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cls = NSClassFromString(@"UIWebTouchEventsGestureRecognizer");
    });
    return cls;
}


+(void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = NSClassFromString(@"WKContentView");
        aywkw_replaceMethod(class, @selector(addGestureRecognizer:), @selector(wkContentView_addGestureRecognizer:));
        
        SEL isSecureTextEntry = NSSelectorFromString(@"isSecureTextEntry");
        SEL secureTextEntry = NSSelectorFromString(@"secureTextEntry");
        BOOL addIsSecureTextEntry = class_addMethod(class, isSecureTextEntry, (IMP)secureTextEntryIMP, "B@:");
        BOOL addSecureTextEntry = class_addMethod(class, secureTextEntry, (IMP)secureTextEntryIMP, "B@:");
        if (!addIsSecureTextEntry || !addSecureTextEntry) {
            NSLog(@"secureTextEntry-Crash->修复失败");
        }
    });
}

BOOL secureTextEntryIMP(id sender, SEL cmd) {
    return NO;
}

-(void)wkContentView_addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    id obj = self.superview.superview;
    if ([obj isKindOfClass:[AYWKWebView class]]) {
        AYWKWebView *webView = obj;
        if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] ) {
            if ([gestureRecognizer isKindOfClass:k_UITextSelectionForceGesture_Class()] ) {
                webView.selectionGesture = (UILongPressGestureRecognizer*)gestureRecognizer;
            }else if ([gestureRecognizer.description containsString:kLongPressRecognizedFlag]) {
                webView.longPressGesture = (UILongPressGestureRecognizer*)gestureRecognizer;
            }
        }else if ([gestureRecognizer isKindOfClass:k_UIWebTouchEventsGestureRecognizer_Class()]) {
            webView.webTouchEventsGesture = gestureRecognizer;
        }
    }
    [self wkContentView_addGestureRecognizer:gestureRecognizer];
}

@end

NSArray* infoUrlSchemes() {
    static NSMutableArray *kInfoUrlSchemes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kInfoUrlSchemes = [NSMutableArray array];
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
        NSMutableDictionary *dict  = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        NSArray *urlTypes = dict[@"CFBundleURLTypes"];
        for (NSDictionary *urlType in urlTypes) {
            [kInfoUrlSchemes addObjectsFromArray:urlType[@"CFBundleURLSchemes"]];
        }
    });
    return kInfoUrlSchemes;
}

NSArray* infoOpenURLs() {
    static NSMutableArray *kInfoOpenURLs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kInfoOpenURLs = [NSMutableArray array];
        [kInfoOpenURLs addObject:@"tel"];
        [kInfoOpenURLs addObject:@"telprompt"];
        [kInfoOpenURLs addObject:@"sms"];
        [kInfoOpenURLs addObject:@"mailto"];
    });
    return kInfoOpenURLs;
}


@implementation AYWKWebView
@synthesize observerDelegate = _observerDelegate;
#pragma mark - evaluateJavaScript fix

-(void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler {
    id strongSelf = self;
    [super evaluateJavaScript:javaScriptString completionHandler:^(id object, NSError *error) {
        [strongSelf title];
        if (completionHandler) {
            completionHandler(object, error);
        }
    }];
}
#pragma mark - post
-(WKNavigation *)loadRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    NSString *str = [url lowercaseString];
    BOOL hasPrefix_var = [str hasPrefix:@"/"];
    BOOL hasPrefix_file = [str hasPrefix:@"file://"];
    if (hasPrefix_var || hasPrefix_file) {
        NSURL *_url = request.URL;
        if (hasPrefix_var) {
            _url = [NSURL fileURLWithPath:url];
        }
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 9.0) {
            return [self loadFileURL:_url allowingReadAccessToURL:_url];
        }else{
            NSURLRequest *_request = request;
            if (_url != _request.URL) {
                _request = [NSURLRequest requestWithURL:_url];
            }
            return [super loadRequest:_request];
        }
    } else
        if ([[request.HTTPMethod uppercaseString] isEqualToString:@"POST"]){
            NSString *params = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            if ([params containsString:@"="]) {
                params = [params stringByReplacingOccurrencesOfString:@"=" withString:@"\":\""];
                params = [params stringByReplacingOccurrencesOfString:@"&" withString:@"\",\""];
                params = [NSString stringWithFormat:@"{\"%@\"}", params];
            }else{
                params = @"{}";
            }
            NSString *postJavaScript = [NSString stringWithFormat:@"\
                                        var url = '%@';\
                                        var params = %@;\
                                        var form = document.createElement('form');\
                                        form.setAttribute('method', 'post');\
                                        form.setAttribute('action', url);\
                                        for(var key in params) {\
                                        if(params.hasOwnProperty(key)) {\
                                        var hiddenField = document.createElement('input');\
                                        hiddenField.setAttribute('type', 'hidden');\
                                        hiddenField.setAttribute('name', key);\
                                        hiddenField.setAttribute('value', params[key]);\
                                        form.appendChild(hiddenField);\
                                        }\
                                        }\
                                        document.body.appendChild(form);\
                                        form.submit();", url, params];
            __weak typeof(self) wself = self;
            [self evaluateJavaScript:postJavaScript completionHandler:^(id object, NSError * _Nullable error) {
                if (error && [wself.navigationDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [wself.navigationDelegate webView:wself didFailProvisionalNavigation:nil withError:error];
                    });
                }
            }];
            return nil;
        }else{
            return [super loadRequest:request];
        }
}


-(instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    self = [super initWithFrame:frame configuration:configuration];
    if (self) {
        [self _customIntitialization];
    }
    return self;
}

- (void)_customIntitialization{
    self.navigationDelegate = nil;
    self.UIDelegate = nil;
    self.observerDelegate = nil;
    self.wkObserver = [[WkObserver alloc] init];
    self.wkObserverEnabled = YES;
    
    self.allowsBackNavigationGestures = YES;
    self.allowsForwardNavigationGestures = YES;
    [super setAllowsBackForwardNavigationGestures:YES];//执行后会添加手势
    
    self.allowSelectionGestures = YES;
    self.allowLongPressGestures = YES;
    UIView *wkContentView = self.scrollView.subviews.firstObject;
    NSArray *gestureRecognizers = wkContentView.gestureRecognizers;
    for (long i = 0; i<gestureRecognizers.count; i++) {
        UIGestureRecognizer *gestureRecognizer = gestureRecognizers[i];
        if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] ) {
            if ([gestureRecognizer isKindOfClass:k_UITextSelectionForceGesture_Class()] ) {
                self.selectionGesture = (UILongPressGestureRecognizer*)gestureRecognizer;
            }else if ([gestureRecognizer.description containsString:kLongPressRecognizedFlag]) {
                self.longPressGesture = (UILongPressGestureRecognizer*)gestureRecognizer;
            }
        }else if ([gestureRecognizer isKindOfClass:k_UIWebTouchEventsGestureRecognizer_Class()]) {
            self.webTouchEventsGesture = gestureRecognizer;
        }
    }
}

-(void)dealloc {
    self.wkObserverEnabled = NO;
    self.wkObserver = nil;
}

-(void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]] && [gestureRecognizer.description containsString:@"handleNavigationTransition:"]) {
        UIScreenEdgePanGestureRecognizer *navigationGestures = (UIScreenEdgePanGestureRecognizer*)gestureRecognizer;
        if (navigationGestures.edges == UIRectEdgeLeft) {
            self.backNavigationGesture = navigationGestures;
        }
        if (navigationGestures.edges == UIRectEdgeRight) {
            self.forwardNavigationGesture = navigationGestures;
        }
    }
    [super addGestureRecognizer:gestureRecognizer];
}



-(void)setWkObserverEnabled:(BOOL)wkObserverEnabled {
    if (_wkObserverEnabled == wkObserverEnabled) {
        return;
    }
    _wkObserverEnabled = wkObserverEnabled;
    if (_wkObserverEnabled) {
        [self addObserver:self.wkObserver forKeyPath:kWebViewEstimatedProgress options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewCanGoBack options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewCanGoForward options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewTitle options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewUrl options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewLoading options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewCertificateChain options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self.wkObserver forKeyPath:kWebViewHasOnlySecureContent options:NSKeyValueObservingOptionNew context:nil];
    }else{
        [self removeObserver:self.wkObserver forKeyPath:kWebViewEstimatedProgress];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewCanGoBack];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewCanGoForward];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewTitle];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewUrl];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewLoading];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewCertificateChain];
        [self removeObserver:self.wkObserver forKeyPath:kWebViewHasOnlySecureContent];
    }
}

-(void)setObserverDelegate:(id<AYWKObserverDelegate>)observerDelegate {
    id<AYWKObserverDelegate> delegate = (id<AYWKObserverDelegate>)self;
    if (delegate != observerDelegate) {
        self.observerDelegateReceiver = observerDelegate;
    }
    _observerDelegate = delegate;
}

-(id<AYWKObserverDelegate>)observerDelegate {
    return self.observerDelegateReceiver;
}
#pragma mark -

-(BOOL)allowsLinkPreview {
    if (([[[UIDevice currentDevice] systemVersion] doubleValue] >= 9.0)) {
        return [super allowsLinkPreview];
    }
    return NO;
}

-(void)setAllowsLinkPreview:(BOOL)allowsLinkPreview {
    if (([[[UIDevice currentDevice] systemVersion] doubleValue] >= 9.0)) {
        [super setAllowsLinkPreview:allowsLinkPreview];
    }
}


#pragma mark - Gestures
#pragma mark backNavigationGesture
-(void)setAllowsBackNavigationGestures:(BOOL)allowsBackNavigationGestures {
    _allowsBackNavigationGestures = allowsBackNavigationGestures;
    self.backNavigationGesture.enabled = _allowsBackNavigationGestures;
}
-(void)setBackNavigationGesture:(UIScreenEdgePanGestureRecognizer *)backNavigationGesture {
    _backNavigationGesture = backNavigationGesture;
    _backNavigationGesture.enabled = self.allowsBackNavigationGestures;
}

#pragma mark forwardNavigationGesture
-(void)setAllowsForwardNavigationGestures:(BOOL)allowsForwardNavigationGestures {
    _allowsForwardNavigationGestures = allowsForwardNavigationGestures;
    self.forwardNavigationGesture.enabled = _allowsForwardNavigationGestures;
}
-(void)setForwardNavigationGesture:(UIScreenEdgePanGestureRecognizer *)forwardNavigationGesture {
    _forwardNavigationGesture = forwardNavigationGesture;
    _forwardNavigationGesture.enabled = self.allowsForwardNavigationGestures;
}

#pragma mark selectionGesture
-(void)setAllowSelectionGestures:(BOOL)allowSelectionGestures {
    _allowSelectionGestures = allowSelectionGestures;
    self.selectionGesture.enabled = _allowSelectionGestures;
}
-(void)setSelectionGesture:(UILongPressGestureRecognizer *)selectionGesture {
    _selectionGesture = selectionGesture;
    _selectionGesture.enabled = self.allowSelectionGestures;
}

#pragma mark longPressGesture
-(void)setAllowLongPressGestures:(BOOL)allowLongPressGestures {
    _allowLongPressGestures = allowLongPressGestures;
    self.longPressGesture.enabled = _allowLongPressGestures;
}
-(void)setLongPressGesture:(UILongPressGestureRecognizer *)longPressGesture {
    _longPressGesture = longPressGesture;
    _selectionGesture.enabled = self.allowLongPressGestures;
}

#pragma mark - webTouchEventsGesture

-(void)setWebTouchEventsGesture:(UIGestureRecognizer *)webTouchEventsGesture {
    _webTouchEventsGesture = webTouchEventsGesture;
    //...
}

#pragma mark - 滚动速率
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView.contentSize.height>scrollView.bounds.size.height*1.5) {//html页面高度小于1.5倍webView高度时候不做速率处理
        scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    }
}
#pragma mark - js调用

-(id)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString {
    __block NSString* result = nil;
    if (javaScriptString.length>0) {
        __block BOOL isExecuted = NO;
        [self evaluateJavaScript:javaScriptString completionHandler:^(id obj, NSError *error) {
            result = obj;
            isExecuted = YES;
        }];
        
        while (isExecuted == NO) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    return result;
}

#pragma mark - 代理拦截

-(void)setNavigationDelegate:(id<WKNavigationDelegate>)navigationDelegate {
    id<WKNavigationDelegate> delegate = (id<WKNavigationDelegate>)self;
    if (delegate != navigationDelegate) {
        self.navigationDelegateReceiver = navigationDelegate;
    }
    [super setNavigationDelegate:delegate];
}

-(void)setUIDelegate:(id<WKUIDelegate>)UIDelegate {
    id<WKUIDelegate> delegate = (id<WKUIDelegate>)self;
    if (delegate != UIDelegate) {
        self.UIDelegateReceiver = UIDelegate;
    }
    [super setUIDelegate:delegate];
}

-(id<WKNavigationDelegate>)navigationDelegate {
    return self.navigationDelegateReceiver;
}

-(id<WKUIDelegate>)UIDelegate {
    return self.UIDelegateReceiver;
}


#pragma mark -
#pragma mark UrlSchemes OpenURLs拦截
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if([infoOpenURLs() containsObject:url.scheme]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIApplication *app = [UIApplication sharedApplication];
            if ([app canOpenURL:url]){
                [self userInteractionDisableWithTime:0.2];
                [app openURL:url];
            }
        });
        return;
    }
    
    if([infoUrlSchemes() containsObject:url.scheme] ||
       [url.absoluteString containsString:@"itunes.apple.com"] ||
       [url.absoluteString isEqualToString:UIApplicationOpenSettingsURLString]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIApplication *app = [UIApplication sharedApplication];
            if ([app canOpenURL:url]){
                [app openURL:url];
            }
        });
        return;
    }
    
    if ([self.navigationDelegateReceiver respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [self.navigationDelegateReceiver webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    }else{
        decisionHandler(YES);
    }
}
#pragma mark  https
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([self.navigationDelegateReceiver respondsToSelector:@selector(webView:didReceiveAuthenticationChallenge:completionHandler:)]) {
        [self.navigationDelegateReceiver webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    }else{
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            if ([challenge previousFailureCount] == 0) {
                NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
            } else {
                completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            }
        } else {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        }
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    if ([self.navigationDelegateReceiver respondsToSelector:@selector(webViewWebContentProcessDidTerminate:)]) {
        [self.navigationDelegateReceiver webViewWebContentProcessDidTerminate:webView];
    }else{
        //    当 WKWebView 总体内存占用过大，页面即将白屏的时候，系统会调用上面的回调函数，我们在该函数里执行[webView reload](这个时候 webView.URL 取值尚不为 nil）解决白屏问题。在一些高内存消耗的页面可能会频繁刷新当前页面，H5侧也要做相应的适配操作。
        [webView reload];
    }
}

#pragma mark - 代理转发
- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) {
        return self;
    }
    if (self.navigationDelegateReceiver && [self.navigationDelegateReceiver respondsToSelector:aSelector]) {
        return self.navigationDelegateReceiver;
    }
    if (self.UIDelegateReceiver && [self.UIDelegateReceiver respondsToSelector:aSelector]) {
        return self.UIDelegateReceiver;
    }
    if (self.observerDelegateReceiver && [self.observerDelegateReceiver respondsToSelector:aSelector]) {
        return self.observerDelegateReceiver;
    }
    return nil;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    //    NSString*selName=NSStringFromSelector(aSelector);
    //    if ([selName hasPrefix:@"keyboardInput"] || [selName isEqualToString:@"customOverlayContainer"]) {//键盘输入代理过滤
    //        return NO;
    //    }
    if (self.navigationDelegateReceiver && [self.navigationDelegateReceiver respondsToSelector:aSelector]) {
        return YES;
    }
    if (self.UIDelegateReceiver && [self.UIDelegateReceiver respondsToSelector:aSelector]) {
        return YES;
    }
    if (self.observerDelegateReceiver && [self.observerDelegateReceiver respondsToSelector:aSelector]) {
        return YES;
    }
    return [super respondsToSelector:aSelector];
}


#pragma mark -

#pragma mark - 响应间隔禁止
-(void)userInteractionDisableWithTime:(double)interval {
    if(time <= 0 && !self.userInteractionEnabled) {
        return;
    }
    self.userInteractionEnabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.userInteractionEnabled = YES;
    });
}

#pragma mark - 截图
-(UIImage*)screenshot {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0);
    for (UIView *subView in self.subviews) {
        [subView drawViewHierarchyInRect:subView.bounds afterScreenUpdates:YES];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}



#pragma mark - class
#pragma mark - 缓存清理
+ (void)clearCache {
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 9.0) {
        //        NSSet *websiteDataTypes = [NSSet setWithArray:@[
        ////                                                        磁盘缓存
        //                                                        WKWebsiteDataTypeDiskCache,
        //
        ////                                                        离线APP缓存
        //                                                        //WKWebsiteDataTypeOfflineWebApplicationCache,
        //
        ////                                                        内存缓存
        //                                                        WKWebsiteDataTypeMemoryCache,
        //
        ////                                                        web LocalStorage 缓存
        //                                                        //WKWebsiteDataTypeLocalStorage,
        //
        ////                                                        web Cookies缓存
        //                                                        //WKWebsiteDataTypeCookies,
        //
        ////                                                        SessionStorage 缓存
        //                                                        //WKWebsiteDataTypeSessionStorage,
        //
        ////                                                        索引DB缓存
        //                                                        //WKWebsiteDataTypeIndexedDBDatabases,
        //
        ////                                                        数据库缓存
        //                                                        //WKWebsiteDataTypeWebSQLDatabases
        //
        //                                                        ]];
        //// All kinds of data
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        //// Date from
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        //// Execute
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
            // Done
        }];
    } else {
        
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask, YES)[0];
        NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
        
        NSString *cookiesFolderPath = [NSString stringWithFormat:@"%@/Cookies",libraryDir];
        NSString *webkitFolderInLib = [NSString stringWithFormat:@"%@/WebKit",libraryDir];
        NSString *webKitFolderInCaches = [NSString stringWithFormat:@"%@/Caches/%@/WebKit",libraryDir,bundleId];
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:cookiesFolderPath error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:webKitFolderInCaches error:&error];
        [[NSFileManager defaultManager] removeItemAtPath:webkitFolderInLib error:&error];
    }
}

@end


//
//  YZWebViewController.m
//  UPBOX
//
//  Created by YLCHUN on 2017/7/4.
//  Copyright © 2017年 ylchun Cultural Development Co., Ltd. All rights reserved.
//

#import "YZWebViewController.h"
#import "YZSDK+AllWebView.h"
#import "AYWKWebView.h"
#import "LoginViewController.h"

typedef void (^LoginResultBlock)(BOOL success);

typedef AYWKWebView YZWebView;
//typedef UIWebView YZWebView;

@interface YZWebViewController () <UIWebViewDelegate, WKNavigationDelegate>
@property (nonatomic, strong) YZWebView *webView;
@property (nonatomic, strong) UIWebView *uiwebView;
@property (nonatomic, strong) AYWKWebView *wkwebView;
@property (strong, nonatomic) UIBarButtonItem *closeBarButtonItem; /**< 关闭按钮 */
@end

@implementation YZWebViewController

-(UIWebView *)uiwebView {
    if (!_uiwebView) {
        _uiwebView = [[UIWebView alloc] initWithFrame:CGRectZero];
        _uiwebView.scalesPageToFit = YES;
        _uiwebView.delegate = self;
    }
    return _uiwebView;
}

-(AYWKWebView *)wkwebView {
    if (!_wkwebView) {
        _wkwebView = (AYWKWebView*)[YZSDK wkWebViewWithWKClass:[AYWKWebView class] configuration:nil];
        _wkwebView.navigationDelegate = self;
    }
    return _wkwebView;
}

-(YZWebView *)webView {
    if (!_webView) {
        if ([YZWebView class] == [UIWebView class]) {
            _webView = (id)self.uiwebView;
        }else {
            _webView = (id)self.wkwebView;
        }
        _webView.frame = self.view.bounds;
        [self.view addSubview:_webView];
        _webView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraint: [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_webView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
        [self.view addConstraint: [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_webView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
        [self.view addConstraint: [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_webView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        [self.view addConstraint: [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_webView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    }
    return _webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initBarButtonItem];
    self.navigationItem.rightBarButtonItem.enabled = NO;//默认分享按钮不可用
    [self loadWithString:@"https://h5.youzan.com/v2/showcase/homepage?alias=juhos0"];
    
    // Do any additional setup after loading the view.
}
-(void)dealloc {
    [YZSDK logout];
}

- (void)initBarButtonItem {
    //初始化关闭按钮
    UIButton *but = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 30)];
    [but setTitle:@"关闭" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(closeItemBarButtonAction) forControlEvents:UIControlEventTouchUpInside];
    self.closeBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:but];
    
    //    self.navigationItem.leftItemsSupplementBackButton = YES;
    //    self.navigationItem.leftBarButtonItem = self.closeBarButtonItem;
    
    //    self.closeBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(closeItemBarButtonAction)];
    
    UIBarButtonItem *reloadBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(reloadButtonAction)];
    //初始化分享按钮
    UIBarButtonItem *shareButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"分享" style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonAction)];
    self.navigationItem.rightBarButtonItems = @[shareButtonItem,reloadBarButtonItem];
}

- (void)shareButtonAction {
    [YZSDK shareActionWithWebView:self.webView];
}
- (void)reloadButtonAction {
    [self.webView reload];
}
- (void)closeItemBarButtonAction {
    [self.navigationController popViewControllerAnimated:YES];
}


- (BOOL)navigationShouldPopOnBackButton {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
        self.navigationItem.leftItemsSupplementBackButton = YES;
        self.navigationItem.leftBarButtonItem = self.closeBarButtonItem;
        return NO;
    } else {
        return YES;
    }
}
- (void)loadWithString:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:urlRequest];
}

/**
 *  显示分享数据
 *
 *  @param data
 */
- (void)shareWithData:(id)data {
    NSDictionary *shareDic = (NSDictionary *)data;
    NSString *message = [NSString stringWithFormat:@"%@\r%@" , shareDic[@"title"],shareDic[@"link"]];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"数据已经复制到黏贴版" message:message delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil];
    [alertView show];
    //复制到粘贴板
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = message;
}

/**
 登陆，等待通知结果通知
 */
- (void)presentNativeLoginViewWithBlock:(LoginResultBlock)block {
    UIStoryboard *board = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UINavigationController *navigation = [board instantiateViewControllerWithIdentifier:@"login"];
    LoginViewController *loginVC = [navigation.viewControllers objectAtIndex:0];
    loginVC.loginBlock = block; //买家登录结果
    [self presentViewController:navigation animated:YES completion:nil];
}

#pragma mark - delegate YZSDK action
- (void)initYouzanWithWebView:(YZWebView *)webView {
    [YZSDK initYouzanWithWebView:webView];
}
- (BOOL)continueWithRequest:(NSURLRequest *)request {
    NSURL *url = [request URL];
    NSLog(@"__url: %@",url.absoluteString);
    YZNotice *noticeFromYZ = [YZSDK noticeFromYouzanWithUrl:url];
    if(noticeFromYZ.notice & YouzanNoticeLogin) {//登录
        [self presentNativeLoginViewWithBlock:^(BOOL success){
            if (success) {
                [self.webView reload];
            } else {
                if ([self.webView canGoBack]) {
                    [self.webView goBack];
                }
            };
        }];
        return NO;
    } else if(noticeFromYZ.notice & YouzanNoticeShare) {//分享
        [self shareWithData:noticeFromYZ.response];
        return NO;
    } else if(noticeFromYZ.notice & YouzanNoticeReady) {//有赞环境初始化成功，分享按钮可用
        self.navigationItem.rightBarButtonItem.enabled = YES;
        return NO;
    } else if (noticeFromYZ.notice & IsYouzanNotice) {
        return NO;
    }
    //加载新链接时，分享按钮先置为不可用，直到有赞环境初始化成功方可使用
    self.navigationItem.rightBarButtonItem.enabled = NO;
    return YES;
}

#pragma mark - delegate
- (void)webView:(YZWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    [self initYouzanWithWebView:webView];
}

-(void)webView:(YZWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
    BOOL b = [self continueWithRequest:navigationAction.request];
    if (b) {
        decisionHandler(WKNavigationActionPolicyAllow);
    }else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)webViewDidFinishLoad:(YZWebView *)webView {
    [self initYouzanWithWebView:webView];
}

- (BOOL)webView:(YZWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL b = [self continueWithRequest:request];
    return b;
}

@end





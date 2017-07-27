//
//  YZSDK+AllWebView.h
//  YouzaniOSDemo
//
//  Created by YLCHUN on 2017/7/14.
//  Copyright © 2017年 ylchun. All rights reserved.
//

#import <YZBase/YZBase.h>

@class WKProcessPool, WKWebView, WKWebViewConfiguration;

typedef id ISWebView;

typedef Class WKWebViewClass;

@interface YZSDK (AllWebView)

/**
 *  页面加载完成，初始化有赞交互环境（UIWebView、WKWebView通用）
 *
 *  @param webView webview
 */
+ (void)initYouzanWithWebView:(ISWebView)webView;

/**
 *  触发分享操作（UIWebView、WKWebView通用）
 *
 *  @param webView webview
 */
+ (void)shareActionWithWebView:(ISWebView)webView;

/**
 获取 WKWebView 实例对象

 @param wkCls nil 或者 WKWebView子类型
 @param configuration configuration 或 nil（configuration.processPool会被重置成共享processPool，禁止独自设置）
 @return wkCls 类型的WKWebView
 */
+ (WKWebView *)wkWebViewWithWKClass:(WKWebViewClass)wkCls configuration:(WKWebViewConfiguration*)configuration;

@end

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "WVJBWebView.h"

#import <UIKit/UIKit.h>

#import <React/RCTAutoInsetsProtocol.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>


NSString *const WVJBJSNavigationScheme = @"react-js-navigation";
NSString *const WVJBJSPostMessageHost = @"postMessage";

@interface WVJBWebView () <UIWebViewDelegate, RCTAutoInsetsProtocol>

@property (nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property (nonatomic, copy) RCTDirectEventBlock onShouldStartLoadWithRequest;
@property (nonatomic, copy) RCTDirectEventBlock onMessage;
  
//code start
@property (nonatomic, strong) WebViewJavascriptBridge *bridge;
//code end

@end

@implementation WVJBWebView
{
  UIWebView *_webView;
  NSString *_injectedJavaScript;
}

- (void)dealloc
{
  _webView.delegate = nil;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    super.backgroundColor = [UIColor clearColor];
    _automaticallyAdjustContentInsets = YES;
    _contentInset = UIEdgeInsetsZero;
    _webView = [[UIWebView alloc] initWithFrame:self.bounds];
    _webView.delegate = self;
    [self addSubview:_webView];
    
    
    //code start
    _bridge = [WebViewJavascriptBridge bridgeForWebView:_webView];
    [_bridge setWebViewDelegate:self];
      self.responseCallbacks = [[NSMutableDictionary dictionary] mutableCopy];
    //code end
  }
  return self;
}
  
  //code start
  - (void)registerHandler:(NSString*)handlerName handler:(WVJBHandler)handler {
    [_bridge registerHandler:handlerName handler:handler];
  }
  -(void) callHandler:(NSString *) handlerName data:(NSDictionary *) data responseCallback:(WVJBResponseCallback)responseCallback {
    [_bridge callHandler:handlerName data:data responseCallback:responseCallback];
  }
  //code end

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (void)goForward
{
  [_webView goForward];
}

- (void)goBack
{
  [_webView goBack];
}

- (void)reload
{
  NSURLRequest *request = [RCTConvert NSURLRequest:self.source];
  if (request.URL && (!_webView.request.URL.absoluteString.length || [_webView.request.URL.absoluteString isEqualToString:@"about:blank"])) {
    [_webView loadRequest:request];
  }
  else {
    [_webView reload];
  }
}

- (void)stopLoading
{
  [_webView stopLoading];
}

- (void)postMessage:(NSString *)message
{
  NSDictionary *eventInitDict = @{
    @"data": message,
  };
  NSString *source = [NSString
    stringWithFormat:@"document.dispatchEvent(new MessageEvent('message', %@));",
    RCTJSONStringify(eventInitDict, NULL)
  ];
  [_webView stringByEvaluatingJavaScriptFromString:source];
}

- (void)injectJavaScript:(NSString *)script
{
  [_webView stringByEvaluatingJavaScriptFromString:script];
}

- (void)setSource:(NSDictionary *)source
{
  if (![_source isEqualToDictionary:source]) {
    _source = [source copy];

    // Check for a static html source first
    NSString *html = [RCTConvert NSString:source[@"html"]];
    if (html) {
      NSURL *baseURL = [RCTConvert NSURL:source[@"baseUrl"]];
      if (!baseURL) {
        baseURL = [NSURL URLWithString:@"about:blank"];
      }
      [_webView loadHTMLString:html baseURL:baseURL];
      return;
    }

      //修改缓存策略
    NSURLRequest *req = [RCTConvert NSURLRequest:source];
      NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:req.URL];
      request.HTTPBody = req.HTTPBody;
      request.HTTPMethod = req.HTTPMethod;
      request.allHTTPHeaderFields = req.allHTTPHeaderFields;
      request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    // Because of the way React works, as pages redirect, we actually end up
    // passing the redirect urls back here, so we ignore them if trying to load
    // the same url. We'll expose a call to 'reload' to allow a user to load
    // the existing page.
    if ([request.URL isEqual:_webView.request.URL]) {
      return;
    }
    if (!request.URL) {
      // Clear the webview
      [_webView loadHTMLString:@"" baseURL:nil];
      return;
    }
    [_webView loadRequest:request];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _webView.frame = self.bounds;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
  _contentInset = contentInset;
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:NO];
}

- (void)setScalesPageToFit:(BOOL)scalesPageToFit
{
  if (_webView.scalesPageToFit != scalesPageToFit) {
    _webView.scalesPageToFit = scalesPageToFit;
    [_webView reload];
  }
}

- (BOOL)scalesPageToFit
{
  return _webView.scalesPageToFit;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
  self.opaque = _webView.opaque = (alpha == 1.0);
  _webView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor
{
  return _webView.backgroundColor;
}

- (NSMutableDictionary<NSString *, id> *)baseEvent
{
  NSMutableDictionary<NSString *, id> *event = [[NSMutableDictionary alloc] initWithDictionary:@{
    @"url": _webView.request.URL.absoluteString ?: @"",
    @"loading" : @(_webView.loading),
    @"title": [_webView stringByEvaluatingJavaScriptFromString:@"document.title"],
    @"canGoBack": @(_webView.canGoBack),
    @"canGoForward" : @(_webView.canGoForward),
  }];

  return event;
}

- (void)refreshContentInset
{
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:YES];
}

#pragma mark - UIWebViewDelegate methods

- (BOOL)webView:(__unused UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
  BOOL isJSNavigation = [request.URL.scheme isEqualToString:WVJBJSNavigationScheme];

  static NSDictionary<NSNumber *, NSString *> *navigationTypes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    navigationTypes = @{
      @(UIWebViewNavigationTypeLinkClicked): @"click",
      @(UIWebViewNavigationTypeFormSubmitted): @"formsubmit",
      @(UIWebViewNavigationTypeBackForward): @"backforward",
      @(UIWebViewNavigationTypeReload): @"reload",
      @(UIWebViewNavigationTypeFormResubmitted): @"formresubmit",
      @(UIWebViewNavigationTypeOther): @"other",
    };
  });

  // skip this for the JS Navigation handler
  if (!isJSNavigation && _onShouldStartLoadWithRequest) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary: @{
      @"url": (request.URL).absoluteString,
      @"navigationType": navigationTypes[@(navigationType)]
    }];
    if (![self.delegate webView:self
      shouldStartLoadForRequest:event
                   withCallback:_onShouldStartLoadWithRequest]) {
      return NO;
    }
  }

  if (_onLoadingStart) {
    // We have this check to filter out iframe requests and whatnot
    BOOL isTopFrame = [request.URL isEqual:request.mainDocumentURL];
    if (isTopFrame) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary: @{
        @"url": (request.URL).absoluteString,
        @"navigationType": navigationTypes[@(navigationType)]
      }];
      _onLoadingStart(event);
    }
  }

  if (isJSNavigation && [request.URL.host isEqualToString:WVJBJSPostMessageHost]) {
    NSString *data = request.URL.query;
    data = [data stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    data = [data stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary: @{
      @"data": data,
    }];
    _onMessage(event);
  }

  // JS Navigation handler
  return !isJSNavigation;
}

- (void)webView:(__unused UIWebView *)webView didFailLoadWithError:(NSError *)error
{
  if (_onLoadingError) {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
      // NSURLErrorCancelled is reported when a page has a redirect OR if you load
      // a new URL in the WebView before the previous one came back. We can just
      // ignore these since they aren't real errors.
      // http://stackoverflow.com/questions/1024748/how-do-i-fix-nsurlerrordomain-error-999-in-iphone-3-0-os
      return;
    }

    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102) {
      // Error code 102 "Frame load interrupted" is raised by the UIWebView if
      // its delegate returns FALSE from webView:shouldStartLoadWithRequest:navigationType
      // when the URL is from an http redirect. This is a common pattern when
      // implementing OAuth with a WebView.
      return;
    }

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"domain": error.domain,
      @"code": @(error.code),
      @"description": error.localizedDescription,
    }];
    _onLoadingError(event);
  }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
  if (_messagingEnabled) {
    #if RCT_DEV
    // See isNative in lodash
    NSString *testPostMessageNative = @"String(window.postMessage) === String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage')";
    BOOL postMessageIsNative = [
      [webView stringByEvaluatingJavaScriptFromString:testPostMessageNative]
      isEqualToString:@"true"
    ];
    if (!postMessageIsNative) {
      RCTLogError(@"Setting onMessage on a WebView overrides existing values of window.postMessage, but a previous value was defined");
    }
    #endif
    NSString *source = [NSString stringWithFormat:
      @"window.originalPostMessage = window.postMessage;"
      "window.postMessage = function(data) {"
        "window.location = '%@://%@?' + encodeURIComponent(String(data));"
      "};", WVJBJSNavigationScheme, WVJBJSPostMessageHost
    ];
    [webView stringByEvaluatingJavaScriptFromString:source];
  }
  if (_injectedJavaScript != nil) {
    NSString *jsEvaluationValue = [webView stringByEvaluatingJavaScriptFromString:_injectedJavaScript];

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    event[@"jsEvaluationValue"] = jsEvaluationValue;

    _onLoadingFinish(event);
  }
  // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
  else if (_onLoadingFinish && !webView.loading && ![webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
    _onLoadingFinish([self baseEvent]);
  }
}

@end

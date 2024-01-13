/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <React/RCTInspectorPackagerConnection.h>

#import <React/RCTDefines.h>
#import <React/RCTInspector.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <SocketRocket/SRWebSocket.h>
#import <jsinspector-modern/InspectorPackagerConnection.h>
#import <memory>
#import "RCTCxxInspectorWebSocketAdapter.h"

using namespace facebook::react::jsinspector_modern;

namespace {
NSString *NSStringFromUTF8StringView(std::string_view view)
{
  return [[NSString alloc] initWithBytes:(const char *)view.data() length:view.size() encoding:NSUTF8StringEncoding];
}
}
@interface RCTCxxInspectorWebSocketAdapter () <SRWebSocketDelegate> {
  std::weak_ptr<IWebSocketDelegate> _delegate;
  SRWebSocket *_webSocket;
}
@end

@implementation RCTCxxInspectorWebSocketAdapter
- (instancetype)initWithURL:(const std::string &)url delegate:(std::weak_ptr<IWebSocketDelegate>)delegate
{
  if ((self = [super init])) {
    _delegate = delegate;
    _webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:NSStringFromUTF8StringView(url)]];
    _webSocket.delegate = self;
    [_webSocket open];
  }
  return self;
}

- (void)send:(std::string_view)message
{
  __weak RCTCxxInspectorWebSocketAdapter *weakSelf = self;
  NSString *messageStr = NSStringFromUTF8StringView(message);
  dispatch_async(dispatch_get_main_queue(), ^{
    RCTCxxInspectorWebSocketAdapter *strongSelf = weakSelf;
    if (strongSelf) {
      [strongSelf->_webSocket send:messageStr];
    }
  });
}

- (void)close
{
  [_webSocket closeWithCode:1000 reason:@"End of session"];
}

- (void)webSocket:(__unused SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
  if (auto delegate = _delegate.lock()) {
    delegate->didFailWithError([error code], [error description].UTF8String);
  }
}

- (void)webSocket:(__unused SRWebSocket *)webSocket didReceiveMessageWithString:(NSString *)message
{
  if (auto delegate = _delegate.lock()) {
    delegate->didReceiveMessage([message UTF8String]);
  }
}

- (void)webSocket:(__unused SRWebSocket *)webSocket
    didCloseWithCode:(__unused NSInteger)code
              reason:(__unused NSString *)reason
            wasClean:(__unused BOOL)wasClean
{
  if (auto delegate = _delegate.lock()) {
    delegate->didClose();
  }
}

@end

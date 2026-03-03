// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTFirebaseAnalyticsPlugin.h"

@import FirebaseAnalytics;

#if __has_include(<firebase_core/FLTFirebasePluginRegistry.h>)
#import <firebase_core/FLTFirebasePluginRegistry.h>
#else
#import <FLTFirebasePluginRegistry.h>
#endif

NSString *const kFLTFirebaseAnalyticsName = @"name";
NSString *const kFLTFirebaseAnalyticsValue = @"value";
NSString *const kFLTFirebaseAnalyticsEnabled = @"enabled";
NSString *const kFLTFirebaseAnalyticsEventName = @"eventName";
NSString *const kFLTFirebaseAnalyticsParameters = @"parameters";
NSString *const kFLTFirebaseAnalyticsAdStorageConsentGranted = @"adStorageConsentGranted";
NSString *const kFLTFirebaseAnalyticsStorageConsentGranted = @"analyticsStorageConsentGranted";
NSString *const kFLTFirebaseAdPersonalizationSignalsConsentGranted =
    @"adPersonalizationSignalsConsentGranted";
NSString *const kFLTFirebaseAdUserDataConsentGranted = @"adUserDataConsentGranted";
NSString *const kFLTFirebaseAnalyticsUserId = @"userId";

NSString *const FLTFirebaseAnalyticsChannelName = @"plugins.flutter.io/firebase_analytics";

@interface NSData (FLTAnalyticsHex)
+ (nullable instancetype)flt_dataWithHexString:(NSString *)hexString;
@end

@implementation NSData (FLTAnalyticsHex)
+ (nullable instancetype)flt_dataWithHexString:(NSString *)hexString {
  if (hexString == nil) {
    return nil;
  }

  NSUInteger length = [hexString length];
  if (length % 2 != 0) {
    return nil;
  }

  NSMutableData *data = [NSMutableData dataWithCapacity:length / 2];
  for (NSUInteger i = 0; i < length; i += 2) {
    unichar c1 = [hexString characterAtIndex:i];
    unichar c2 = [hexString characterAtIndex:i + 1];

    int v1 = 0;
    int v2 = 0;

    if (c1 >= '0' && c1 <= '9') {
      v1 = (int)(c1 - '0');
    } else if (c1 >= 'a' && c1 <= 'f') {
      v1 = (int)(c1 - 'a' + 10);
    } else if (c1 >= 'A' && c1 <= 'F') {
      v1 = (int)(c1 - 'A' + 10);
    } else {
      return nil;
    }

    if (c2 >= '0' && c2 <= '9') {
      v2 = (int)(c2 - '0');
    } else if (c2 >= 'a' && c2 <= 'f') {
      v2 = (int)(c2 - 'a' + 10);
    } else if (c2 >= 'A' && c2 <= 'F') {
      v2 = (int)(c2 - 'A' + 10);
    } else {
      return nil;
    }

    UInt8 byte = (UInt8)((v1 << 4) | v2);
    [data appendBytes:&byte length:1];
  }

  return [data copy];
}
@end

@implementation FLTFirebaseAnalyticsPlugin

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static FLTFirebaseAnalyticsPlugin *instance;
  dispatch_once(&onceToken, ^{
    instance = [[FLTFirebaseAnalyticsPlugin alloc] init];
    [[FLTFirebasePluginRegistry sharedInstance] registerFirebasePlugin:instance];
  });
  return instance;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:FLTFirebaseAnalyticsChannelName
                                  binaryMessenger:[registrar messenger]];
  FLTFirebaseAnalyticsPlugin *instance = [FLTFirebaseAnalyticsPlugin sharedInstance];
  [registrar addMethodCallDelegate:instance channel:channel];
#if !TARGET_OS_OSX
  [registrar publish:instance];
#endif
  SEL sel = NSSelectorFromString(@"registerLibrary:withVersion:");
  if ([FIRApp respondsToSelector:sel]) {
    [FIRApp performSelector:sel withObject:@LIBRARY_NAME withObject:@LIBRARY_VERSION];
  }
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  FLTFirebaseMethodCallErrorBlock errorBlock =
      ^(NSString *_Nullable code, NSString *_Nullable message, NSDictionary *_Nullable details,
        NSError *_Nullable error) {
        result(nil);
      };

  FLTFirebaseMethodCallResult *methodCallResult =
      [FLTFirebaseMethodCallResult createWithSuccess:result andErrorBlock:errorBlock];

  if ([@"Analytics#logEvent" isEqualToString:call.method]) {
    [self logEvent:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#setUserId" isEqualToString:call.method]) {
    [self setUserId:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#setUserProperty" isEqualToString:call.method]) {
    [self setUserProperty:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#setAnalyticsCollectionEnabled" isEqualToString:call.method]) {
    [self setAnalyticsCollectionEnabled:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#resetAnalyticsData" isEqualToString:call.method]) {
    [self resetAnalyticsDataWithMethodCallResult:methodCallResult];
  } else if ([@"Analytics#setConsent" isEqualToString:call.method]) {
    [self setConsent:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#setDefaultEventParameters" isEqualToString:call.method]) {
    [self setDefaultEventParameters:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Analytics#getAppInstanceId" isEqualToString:call.method]) {
    [self getAppInstanceIdWithMethodCallResult:methodCallResult];
  } else if ([@"Analytics#getSessionId" isEqualToString:call.method]) {
    [self getSessionIdWithMethodCallResult:methodCallResult];
  } else if ([@"Analytics#initiateOnDeviceConversionMeasurement" isEqualToString:call.method]) {
    [self initiateOnDeviceConversionMeasurement:call.arguments
                           withMethodCallResult:methodCallResult];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma mark - Firebase Analytics API

- (void)getSessionIdWithMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [FIRAnalytics sessionIDWithCompletion:^(int64_t sessionID, NSError *_Nullable error) {
    if (error != nil) {
      result.error(nil, nil, nil, error);
    } else {
      result.success([NSNumber numberWithLongLong:sessionID]);
    }
  }];
}

- (void)logEvent:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *eventName = arguments[kFLTFirebaseAnalyticsEventName];
  id parameterMap = arguments[kFLTFirebaseAnalyticsParameters];

  if (parameterMap != [NSNull null]) {
    [FIRAnalytics logEventWithName:eventName parameters:parameterMap];
  } else {
    [FIRAnalytics logEventWithName:eventName parameters:nil];
  }

  result.success(nil);
}

- (void)setUserId:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *userId = arguments[kFLTFirebaseAnalyticsUserId];
  [FIRAnalytics setUserID:[userId isKindOfClass:[NSNull class]] ? nil : userId];

  result.success(nil);
}

- (void)setUserProperty:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *name = arguments[kFLTFirebaseAnalyticsName];
  NSString *value = arguments[kFLTFirebaseAnalyticsValue];
  [FIRAnalytics setUserPropertyString:[value isKindOfClass:[NSNull class]] ? nil : value
                              forName:name];
  result.success(nil);
}

- (void)setAnalyticsCollectionEnabled:(id)arguments
                 withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSNumber *enabled = arguments[kFLTFirebaseAnalyticsEnabled];
  [FIRAnalytics setAnalyticsCollectionEnabled:[enabled boolValue]];
  result.success(nil);
}

- (void)resetAnalyticsDataWithMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [FIRAnalytics resetAnalyticsData];
  result.success(nil);
}

- (void)setConsent:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSNumber *adStorageGranted = arguments[kFLTFirebaseAnalyticsAdStorageConsentGranted];
  NSNumber *analyticsStorageGranted = arguments[kFLTFirebaseAnalyticsStorageConsentGranted];
  NSNumber *adPersonalizationSignalsGranted =
      arguments[kFLTFirebaseAdPersonalizationSignalsConsentGranted];
  NSNumber *adUserDataGranted = arguments[kFLTFirebaseAdUserDataConsentGranted];

  NSMutableDictionary<FIRConsentType, FIRConsentStatus> *parameters =
      [[NSMutableDictionary alloc] init];

  if (adStorageGranted != nil) {
    parameters[FIRConsentTypeAdStorage] =
        [adStorageGranted boolValue] ? FIRConsentStatusGranted : FIRConsentStatusDenied;
  }
  if (analyticsStorageGranted != nil) {
    parameters[FIRConsentTypeAnalyticsStorage] =
        [analyticsStorageGranted boolValue] ? FIRConsentStatusGranted : FIRConsentStatusDenied;
  }

  if (adPersonalizationSignalsGranted != nil) {
    parameters[FIRConsentTypeAdPersonalization] = [adPersonalizationSignalsGranted boolValue]
                                                      ? FIRConsentStatusGranted
                                                      : FIRConsentStatusDenied;
  }

  if (adUserDataGranted != nil) {
    parameters[FIRConsentTypeAdUserData] =
        [adUserDataGranted boolValue] ? FIRConsentStatusGranted : FIRConsentStatusDenied;
  }

  [FIRAnalytics setConsent:parameters];
  result.success(nil);
}

- (void)setDefaultEventParameters:(id)arguments
             withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [FIRAnalytics setDefaultEventParameters:arguments];
  result.success(nil);
}

- (void)getAppInstanceIdWithMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *appInstanceID = [FIRAnalytics appInstanceID];
  result.success(appInstanceID);
}

- (void)initiateOnDeviceConversionMeasurement:(id)arguments
                         withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *emailAddress = arguments[@"emailAddress"];
  NSString *phoneNumber = arguments[@"phoneNumber"];
  NSString *hashedEmailAddress = arguments[@"hashedEmailAddress"];
  NSString *hashedPhoneNumber = arguments[@"hashedPhoneNumber"];

  if (![emailAddress isKindOfClass:[NSNull class]]) {
    [FIRAnalytics initiateOnDeviceConversionMeasurementWithEmailAddress:emailAddress];
  }
  if (![phoneNumber isKindOfClass:[NSNull class]]) {
    [FIRAnalytics initiateOnDeviceConversionMeasurementWithPhoneNumber:phoneNumber];
  }
  if (![hashedEmailAddress isKindOfClass:[NSNull class]]) {
    NSData *data = [NSData flt_dataWithHexString:hashedEmailAddress];
    [FIRAnalytics initiateOnDeviceConversionMeasurementWithHashedEmailAddress:data];
  }
  if (![hashedPhoneNumber isKindOfClass:[NSNull class]]) {
    NSData *data = [NSData flt_dataWithHexString:hashedPhoneNumber];
    [FIRAnalytics initiateOnDeviceConversionMeasurementWithHashedPhoneNumber:data];
  }
  result.success(nil);
}

#pragma mark - FLTFirebasePlugin

- (void)didReinitializeFirebaseCore:(void (^_Nonnull)(void))completion {
  completion();
}

- (NSString *_Nonnull)firebaseLibraryName {
  return @LIBRARY_NAME;
}

- (NSString *_Nonnull)firebaseLibraryVersion {
  return @LIBRARY_VERSION;
}

- (NSString *_Nonnull)flutterChannelName {
  return FLTFirebaseAnalyticsChannelName;
}

- (NSDictionary *_Nonnull)pluginConstantsForFIRApp:(FIRApp *_Nonnull)firebaseApp {
  return @{};
}

@end

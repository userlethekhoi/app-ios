// IAPCheck.dylib — MobileSubstrate tweak
//
// Injected into:
//   * every process linking UIKit (filter: Bundles = com.apple.UIKit)
//   * storekitd / itunesstored (filter: Executables)
//
// App processes:
//   * hook SKProductsRequest / SKPaymentQueue to capture every product the
//     host app queries, then persist `<bundleId>_iap.json` snapshots into the
//     shared bridge directories that the NappStore app reads.
//   * on launch / on demand, replay a "pending_scan.json" job queue: fetch the
//     listed product ids (plus product ids harvested from the local receipt)
//     so an app's full catalogue is captured without user interaction.
//   * consume "pending_buy.json" to run a real StoreKit purchase inside the
//     addressed target app (Darwin notify: com.adr.checkiap.trigger_buy).
//   * floating HUD lists captured products inside the target app.
//
// Daemons (storekitd / itunesstored):
//   * spoof SKClient -bundleIdentifier / -clientBundleID so a products/payment
//     request issued by the companion app is resolved in the target app's
//     StoreKit context (proxy catalogue fetch / purchase handoff).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

#pragma mark - Constants

static NSString *const kIAPCheckBuyNotify     = @"com.adr.checkiap.trigger_buy";
static NSString *const kIAPCheckScanNotify    = @"com.adr.checkiap.scan";
static NSString *const kIAPCheckSnapshotNotify = @"com.adr.checkiap.snapshot";
static NSString *const kIAPCheckPendingBuyName  = @"pending_buy.json";
static NSString *const kIAPCheckPendingScanName = @"pending_scan.json";
static const NSTimeInterval kIAPCheckBuySpoofTTL  = 300.0;   // pending_buy lives 5 min
static const NSTimeInterval kIAPCheckScanTTL      = 86400.0; // pending_scan queue 1 day
static const NSTimeInterval kIAPCheckSpoofCacheTTL = 1.5;

#pragma mark - Shared state

static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSDictionary *> *> *gCatalogByBundle;
static NSMutableDictionary<NSString *, SKProduct *> *gLiveProducts;
static NSMutableArray *gActiveDelegates;
static NSMutableSet<NSValue *> *gSwizzledClasses;
static NSMutableArray<NSDictionary *> *gOwnScanQueue;
static dispatch_queue_t gWorkQueue;
static BOOL gScanInFlight = NO;
static BOOL gLaunchProbeDone = NO;
static BOOL gObserverInstalled = NO;
static NSString *gActiveProxyBundle = nil;
static NSString *gSpoofCache = nil;
static NSTimeInterval gSpoofCachedAt = 0;

static void IAPCheckLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void IAPCheckLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"[IAPCheck] " stringByAppendingString:format], args);
    va_end(args);
}

static NSTimeInterval IAPCheckNow(void) {
    return [NSDate date].timeIntervalSince1970;
}

static NSArray<NSString *> *IAPCheckBridgeDirs(void) {
    return @[
        @"/var/mobile/Documents/IAPCheck",
        @"/var/jb/var/mobile/Documents/IAPCheck",
        @"/tmp/IAPCheck",
    ];
}

#pragma mark - Pending-file IO

static NSDictionary *IAPCheckReadJSON(NSString *fileName) {
    for (NSString *dir in IAPCheckBridgeDirs()) {
        NSString *path = [dir stringByAppendingPathComponent:fileName];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) return obj;
    }
    return nil;
}

static void IAPCheckRemovePendingFile(NSString *fileName) {
    for (NSString *dir in IAPCheckBridgeDirs()) {
        NSString *path = [dir stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

static NSArray<NSDictionary *> *IAPCheckScanRequests(NSDictionary *scan) {
    if (![scan isKindOfClass:[NSDictionary class]]) return @[];
    id requests = scan[@"requests"];
    if ([requests isKindOfClass:[NSArray class]]) return requests;
    if ([scan[@"bundleId"] isKindOfClass:[NSString class]]) return @[scan];
    return @[];
}

// Remove one consumed entry and rewrite pending_scan.json in every bridge dir.
static void IAPCheckDropScanEntry(NSDictionary *consumed) {
    NSDictionary *scan = IAPCheckReadJSON(kIAPCheckPendingScanName);
    NSMutableArray<NSDictionary *> *remaining = [IAPCheckScanRequests(scan) mutableCopy];
    [remaining removeObject:consumed];

    NSData *json = nil;
    if (remaining.count) {
        NSDictionary *payload = @{
            @"mode": @"scan",
            @"timestamp": @(IAPCheckNow()),
            @"requests": remaining,
        };
        json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    }
    for (NSString *dir in IAPCheckBridgeDirs()) {
        NSString *path = [dir stringByAppendingPathComponent:kIAPCheckPendingScanName];
        if (json) {
            [json writeToFile:path options:NSDataWritingAtomic error:nil];
        } else {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }
    }
}

#pragma mark - Daemon-side spoof source

// The bundle id the store daemon should impersonate right now:
// the first queued proxy scan entry wins, then a fresh pending_buy bundle.
static NSString *IAPCheckComputeSpoofBundle(void) {
    NSDictionary *scan = IAPCheckReadJSON(kIAPCheckPendingScanName);
    NSNumber *scanTs = scan[@"timestamp"];
    BOOL scanFresh = !scanTs || fabs(IAPCheckNow() - scanTs.doubleValue) < kIAPCheckScanTTL;
    if (scanFresh) {
        for (NSDictionary *entry in IAPCheckScanRequests(scan)) {
            NSString *proxy = entry[@"proxyFor"];
            if ([proxy isKindOfClass:[NSString class]] && proxy.length) return proxy;
        }
    }

    NSDictionary *buy = IAPCheckReadJSON(kIAPCheckPendingBuyName);
    NSString *bundle = [buy[@"bundleId"] isKindOfClass:[NSString class]] ? buy[@"bundleId"] : nil;
    NSNumber *buyTs = buy[@"timestamp"];
    if (bundle.length && (!buyTs || fabs(IAPCheckNow() - buyTs.doubleValue) < kIAPCheckBuySpoofTTL)) {
        return bundle;
    }
    return nil;
}

static NSString *IAPCheckSpoofBundle(void) {
    NSTimeInterval now = IAPCheckNow();
    if (now - gSpoofCachedAt < kIAPCheckSpoofCacheTTL) return gSpoofCache;
    gSpoofCachedAt = now;
    gSpoofCache = IAPCheckComputeSpoofBundle();
    return gSpoofCache;
}

#pragma mark - Product serialisation

static NSString *IAPCheckFormatPrice(NSDecimalNumber *price, NSLocale *locale) {
    if (!price) return @"N/A";
    NSNumberFormatter *formatter = [NSNumberFormatter new];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    if (locale) formatter.locale = locale;
    NSString *text = [formatter stringFromNumber:price];
    return text ?: price.stringValue;
}

static NSString *IAPCheckPeriodCode(SKProductSubscriptionPeriod *period) {
    if (!period) return @"";
    NSString *unit;
    // The SKProductSubscriptionPeriodUnit constants were dropped from recent
    // SDK headers (StoreKit1 removal) — compare the raw enum values instead:
    // day=0, week=1, month=2, year=3.
    switch ((NSInteger)period.unit) {
        case 0:  unit = @"D"; break;
        case 1:  unit = @"W"; break;
        case 2:  unit = @"M"; break;
        case 3:  unit = @"Y"; break;
        default: unit = @"M"; break;
    }
    NSInteger units = period.numberOfUnits > 0 ? period.numberOfUnits : 1;
    return [NSString stringWithFormat:@"P%ld%@", (long)units, unit];
}

static NSDictionary *IAPCheckPhase(NSDecimalNumber *price, NSLocale *locale,
                                   NSString *billingPeriod, NSInteger cycleCount,
                                   NSString *recurrenceMode) {
    return @{
        @"formattedPrice": IAPCheckFormatPrice(price, locale) ?: @"N/A",
        @"priceAmountMicros": @((long long)(price.doubleValue * 1000000.0)),
        @"priceCurrencyCode": locale.currencyCode ?: @"",
        @"billingPeriod": billingPeriod ?: @"",
        @"recurrenceMode": recurrenceMode ?: @"",
        @"billingCycleCount": @(cycleCount),
    };
}

static NSDictionary *IAPCheckOfferFromDiscount(SKProductDiscount *discount,
                                               SKProduct *product, BOOL isIntro) {
    NSString *period = IAPCheckPeriodCode(discount.subscriptionPeriod);
    if (!period.length) period = IAPCheckPeriodCode(product.subscriptionPeriod);
    NSString *price = IAPCheckFormatPrice(discount.price, discount.priceLocale);
    NSString *offerId = discount.identifier;

    NSString *classification;
    NSString *summary;
    if (discount.paymentMode == SKProductDiscountPaymentModeFreeTrial) {
        classification = @"FREE_TRIAL";
        summary = isIntro
            ? [NSString stringWithFormat:@"FREE TRIAL (%@)", period.length ? period : @"trial"]
            : [NSString stringWithFormat:@"PROMO TRIAL: %@", offerId.length ? offerId : @"offer"];
    } else {
        // PayAsYouGo / PayUpFront both land in the app's INTRO_DISCOUNT bucket.
        classification = @"INTRO_DISCOUNT";
        summary = isIntro
            ? [NSString stringWithFormat:@"INTRO: %@ (%@)", price, period.length ? period : @"intro"]
            : [NSString stringWithFormat:@"PROMO (%@): %@", offerId.length ? offerId : @"offer", price];
    }

    NSMutableArray *phases = [NSMutableArray array];
    NSInteger periods = discount.numberOfPeriods > 0 ? discount.numberOfPeriods : 1;
    [phases addObject:IAPCheckPhase(discount.price, discount.priceLocale,
                                    period, periods, @"offer-period")];
    if (product.subscriptionPeriod) {
        [phases addObject:IAPCheckPhase(product.price, product.priceLocale,
                                        IAPCheckPeriodCode(product.subscriptionPeriod),
                                        0, @"auto-renew")];
    }

    NSMutableDictionary *offer = [@{
        @"classification": classification,
        @"summaryText": summary ?: @"",
        @"pricingPhases": phases,
    } mutableCopy];
    if (offerId.length) offer[@"offerId"] = offerId;
    return offer;
}

static NSDictionary *IAPCheckDescribeProduct(SKProduct *product) {
    BOOL isSubscription = product.subscriptionPeriod != nil;
    NSString *basePeriod = isSubscription ? IAPCheckPeriodCode(product.subscriptionPeriod) : @"ONE_TIME";

    NSMutableArray *offers = [NSMutableArray array];
    [offers addObject:@{
        @"classification": @"REGULAR",
        @"summaryText": IAPCheckFormatPrice(product.price, product.priceLocale),
        @"pricingPhases": @[ IAPCheckPhase(product.price, product.priceLocale,
                                           basePeriod, 0,
                                           isSubscription ? @"auto-renew" : @"one-time") ],
    }];

    if (product.introductoryPrice) {
        [offers addObject:IAPCheckOfferFromDiscount(product.introductoryPrice, product, YES)];
    }
    if ([product respondsToSelector:@selector(discounts)]) {
        for (SKProductDiscount *discount in product.discounts) {
            [offers addObject:IAPCheckOfferFromDiscount(discount, product, NO)];
        }
    }

    BOOL hasTrial = NO;
    BOOL hasDiscount = NO;
    for (NSDictionary *offer in offers) {
        if ([offer[@"classification"] isEqualToString:@"FREE_TRIAL"]) hasTrial = YES;
        if ([offer[@"classification"] isEqualToString:@"INTRO_DISCOUNT"]) hasDiscount = YES;
    }

    return @{
        @"productId": product.productIdentifier ?: @"",
        @"productType": isSubscription ? @"SUBS" : @"INAPP",
        @"title": product.localizedTitle ?: @"",
        @"description": product.localizedDescription ?: @"",
        @"formattedBasePrice": IAPCheckFormatPrice(product.price, product.priceLocale),
        @"hasFreeTrial": @(hasTrial),
        @"hasIntroDiscount": @(hasDiscount),
        @"offers": offers,
    };
}

#pragma mark - Capture & persistence

static void IAPCheckHUDRefresh(void);

// Products fetched by the companion app under a daemon spoof must be
// attributed to the spoofed target bundle, not to NappStore itself. The
// currently in-flight scan entry decides the attribution so batched proxy
// entries cannot leak into each other's catalog.
static NSString *IAPCheckEffectiveBundle(void) {
    if (gActiveProxyBundle.length) return gActiveProxyBundle;
    NSString *own = [[NSBundle mainBundle] bundleIdentifier];
    return own ?: @"unknown.app";
}

static void IAPCheckFlushSnapshot(NSString *bundleId) {
    NSMutableDictionary<NSString *, NSDictionary *> *store = gCatalogByBundle[bundleId];
    if (!store.count) return;

    // Merge with whatever snapshot is already on disk so partial re-scans
    // never shrink an app's catalogue.
    NSString *fileName = [NSString stringWithFormat:@"%@_iap.json", bundleId];
    for (NSString *dir in IAPCheckBridgeDirs()) {
        NSString *path = [dir stringByAppendingPathComponent:fileName];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data.length) continue;
        NSDictionary *existing = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![existing isKindOfClass:[NSDictionary class]]) continue;
        NSArray *products = existing[@"products"];
        if (![products isKindOfClass:[NSArray class]]) continue;
        for (NSDictionary *p in products) {
            NSString *pid = p[@"productId"];
            if ([pid isKindOfClass:[NSString class]] && pid.length && !store[pid]) {
                store[pid] = p;
            }
        }
        break; // merge only from the first readable snapshot
    }

    NSArray *products = [store.allValues sortedArrayUsingDescriptors:
        @[ [NSSortDescriptor sortDescriptorWithKey:@"productId" ascending:YES] ]];
    NSInteger subs = 0, trials = 0, discounts = 0;
    for (NSDictionary *p in products) {
        if ([p[@"productType"] isEqualToString:@"SUBS"]) subs++;
        if ([p[@"hasFreeTrial"] boolValue]) trials++;
        if ([p[@"hasIntroDiscount"] boolValue]) discounts++;
    }

    NSDictionary *snapshot = @{
        @"bundleId": bundleId,
        @"timestamp": @(IAPCheckNow()),
        @"totalProducts": @(products.count),
        @"totalSubscriptions": @(subs),
        @"totalFreeTrials": @(trials),
        @"totalDiscounts": @(discounts),
        @"products": products,
    };

    NSData *json = [NSJSONSerialization dataWithJSONObject:snapshot
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (!json) return;

    for (NSString *dir in IAPCheckBridgeDirs()) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
            withIntermediateDirectories:YES attributes:nil error:nil];
        [json writeToFile:[dir stringByAppendingPathComponent:fileName]
                  options:NSDataWritingAtomic error:nil];
    }
    IAPCheckLog(@"Persisted %lu products -> %@", (unsigned long)products.count, fileName);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (CFStringRef)kIAPCheckSnapshotNotify, NULL, NULL, YES);
}

static void IAPCheckCaptureProducts(NSArray *products) {
    if (!products.count) return;
    NSString *bundleId = IAPCheckEffectiveBundle();
    dispatch_async(gWorkQueue, ^{
        NSMutableDictionary<NSString *, NSDictionary *> *store = gCatalogByBundle[bundleId];
        if (!store) {
            store = [NSMutableDictionary dictionary];
            gCatalogByBundle[bundleId] = store;
        }
        for (id obj in products) {
            if (![obj isKindOfClass:[SKProduct class]]) continue;
            SKProduct *product = (SKProduct *)obj;
            NSDictionary *dict = IAPCheckDescribeProduct(product);
            NSString *pid = dict[@"productId"];
            if (!pid.length) continue;
            store[pid] = dict;
            gLiveProducts[pid] = product;
            IAPCheckLog(@"Discovered product: %@ (%@) | Trial: %d | Offers: %lu",
                        pid, dict[@"title"], [dict[@"hasFreeTrial"] boolValue],
                        (unsigned long)[dict[@"offers"] count]);
        }
        IAPCheckFlushSnapshot(bundleId);
        dispatch_async(dispatch_get_main_queue(), ^{ IAPCheckHUDRefresh(); });
    });
}

#pragma mark - Delegate swizzling (captures responses of the host's own requests)

static BOOL IAPCheckClassDefinesMethod(Class cls, SEL sel) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == sel) { found = YES; break; }
    }
    free(methods);
    return found;
}

static void IAPCheckSwizzleDelegate(id delegate) {
    if (!delegate) return;
    Class cls = object_getClass(delegate);
    SEL sel = @selector(productsRequest:didReceiveResponse:);
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;

    @synchronized (gSwizzledClasses) {
        if ([gSwizzledClasses containsObject:[NSValue valueWithPointer:(__bridge const void *)cls]]) return;
        [gSwizzledClasses addObject:[NSValue valueWithPointer:(__bridge const void *)cls]];
    }

    IMP original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    IMP interceptor = imp_implementationWithBlock(
        ^void(id self, SKProductsRequest *request, SKProductsResponse *response) {
            @try {
                IAPCheckLog(@"Intercepted %lu products in response",
                            (unsigned long)response.products.count);
                if (response.invalidProductIdentifiers.count) {
                    IAPCheckLog(@"Invalid Product Identifiers: %@",
                                response.invalidProductIdentifiers);
                }
                IAPCheckCaptureProducts(response.products);
            } @catch (__unused NSException *exception) {}
            ((void (*)(id, SEL, id, id))original)(self, sel, request, response);
        });

    if (IAPCheckClassDefinesMethod(cls, sel)) {
        method_setImplementation(method, interceptor);
    } else {
        // The delegate inherits the protocol method: install an override on
        // the delegate's own class that forwards to the inherited IMP.
        class_addMethod(cls, sel, interceptor, types);
    }
}

#pragma mark - Self-issued product requests

@interface IAPCheckFetchDelegate : NSObject <SKProductsRequestDelegate>
@property (nonatomic, copy) void (^completion)(NSArray *products);
@property (nonatomic, strong) SKProductsRequest *request;
- (instancetype)initWithCompletion:(void (^)(NSArray *products))completion;
@end

@implementation IAPCheckFetchDelegate
- (instancetype)initWithCompletion:(void (^)(NSArray *products))completion {
    self = [super init];
    if (self) _completion = [completion copy];
    return self;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    IAPCheckLog(@"Own SKProductsRequest returned %lu products",
                (unsigned long)response.products.count);
    if (response.invalidProductIdentifiers.count) {
        IAPCheckLog(@"Invalid Product Identifiers: %@", response.invalidProductIdentifiers);
    }
    IAPCheckCaptureProducts(response.products);
    if (self.completion) self.completion(response.products);
    [gActiveDelegates removeObject:self];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    IAPCheckLog(@"SKProductsRequest failed: %@", error.localizedDescription);
    if (self.completion) self.completion(@[]);
    [gActiveDelegates removeObject:self];
}
@end

static void IAPCheckFetchProducts(NSSet<NSString *> *identifiers,
                                  void (^completion)(NSArray *products)) {
    if (!identifiers.count) {
        if (completion) completion(@[]);
        return;
    }
    IAPCheckFetchDelegate *delegate =
        [[IAPCheckFetchDelegate alloc] initWithCompletion:completion];
    SKProductsRequest *request =
        [[SKProductsRequest alloc] initWithProductIdentifiers:identifiers];
    delegate.request = request;
    request.delegate = delegate;
    [gActiveDelegates addObject:delegate];
    [request start];
}

#pragma mark - Receipt product-id harvesting

static inline BOOL IAPCheckIsIDChar(unsigned char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-';
}

// The local receipt is a PKCS7 blob whose in_app attributes embed the product
// ids this Apple account has touched. Heuristically scan for identifier-like
// runs; SKProductsRequest simply rejects whatever is not a real product id.
static NSSet<NSString *> *IAPCheckReceiptProductIds(void) {
    NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    if (data.length < 100) return nil;

    const unsigned char *bytes = (const unsigned char *)data.bytes;
    NSUInteger length = data.length;
    NSMutableSet<NSString *> *ids = [NSMutableSet set];
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];

    NSUInteger i = 0;
    while (i < length && ids.count <= 240) {
        if (!IAPCheckIsIDChar(bytes[i])) { i++; continue; }
        NSUInteger start = i;
        while (i < length && IAPCheckIsIDChar(bytes[i])) i++;
        NSUInteger run = i - start;
        if (run < 10 || run > 128) continue;
        NSString *candidate = [[NSString alloc] initWithBytes:bytes + start
                                                     length:run
                                                   encoding:NSUTF8StringEncoding];
        if (!candidate.length) continue;
        BOOL hasLetter = [candidate rangeOfCharacterFromSet:letters].location != NSNotFound;
        BOOL hasSeparator = [candidate containsString:@"."] || [candidate containsString:@"_"];
        if (hasLetter && hasSeparator) [ids addObject:candidate];
    }
    return ids;
}

#pragma mark - Pending scan / buy consumers

static void IAPCheckProcessNextScanEntry(void) {
    if (gScanInFlight) return;
    NSDictionary *entry = gOwnScanQueue.firstObject;
    if (!entry) { gScanInFlight = NO; return; }
    [gOwnScanQueue removeObjectAtIndex:0];
    gScanInFlight = YES;

    NSString *proxy = [entry[@"proxyFor"] isKindOfClass:[NSString class]] ? entry[@"proxyFor"] : nil;
    NSMutableSet<NSString *> *ids = [NSMutableSet set];
    id provided = entry[@"productIds"];
    if ([provided isKindOfClass:[NSArray class]]) {
        for (id pid in provided) {
            if ([pid isKindOfClass:[NSString class]]) [ids addObject:pid];
        }
    }
    // Target-app scans enrich the request with ids harvested from the receipt.
    if (!proxy.length) {
        NSSet<NSString *> *receiptIds = IAPCheckReceiptProductIds();
        if (receiptIds.count) [ids unionSet:receiptIds];
    }

    IAPCheckLog(@"Consuming scan entry: bundle=%@ proxy=%@ ids=%lu",
                entry[@"bundleId"], proxy, (unsigned long)ids.count);
    gActiveProxyBundle = proxy;
    IAPCheckFetchProducts(ids, ^(__unused NSArray *products) {
        // Keep the entry in pending_scan.json until the fetch finished so the
        // daemon keeps spoofing the right bundle for the whole request.
        gActiveProxyBundle = nil;
        IAPCheckDropScanEntry(entry);
        gScanInFlight = NO;
        IAPCheckProcessNextScanEntry();
    });
}

static void IAPCheckConsumePendingScan(void) {
    NSDictionary *scan = IAPCheckReadJSON(kIAPCheckPendingScanName);
    NSNumber *ts = scan[@"timestamp"];
    if (ts && fabs(IAPCheckNow() - ts.doubleValue) > kIAPCheckScanTTL) return;

    NSString *own = [[NSBundle mainBundle] bundleIdentifier];
    for (NSDictionary *entry in IAPCheckScanRequests(scan)) {
        if (![entry[@"bundleId"] isEqualToString:own]) continue;
        if (![gOwnScanQueue containsObject:entry]) [gOwnScanQueue addObject:entry];
    }
    IAPCheckProcessNextScanEntry();
}

@interface IAPCheckPaymentObserver : NSObject <SKPaymentTransactionObserver>
@end

@implementation IAPCheckPaymentObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        NSString *state = @"unknown";
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:  state = @"purchasing"; break;
            case SKPaymentTransactionStatePurchased:   state = @"purchased"; break;
            case SKPaymentTransactionStateFailed:      state = @"failed"; break;
            case SKPaymentTransactionStateRestored:    state = @"restored"; break;
            case SKPaymentTransactionStateDeferred:    state = @"deferred"; break;
            default: break;
        }
        IAPCheckLog(@"Transaction %@ -> %@",
                    transaction.payment.productIdentifier, state);
    }
}
@end

static void IAPCheckInstallTransactionObserver(void) {
    if (gObserverInstalled) return;
    gObserverInstalled = YES;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[IAPCheckPaymentObserver new]];
}

static void IAPCheckConsumePendingBuy(void) {
    NSDictionary *pending = IAPCheckReadJSON(kIAPCheckPendingBuyName);
    NSString *target = [pending[@"bundleId"] isKindOfClass:[NSString class]] ? pending[@"bundleId"] : nil;
    NSString *productId = [pending[@"productId"] isKindOfClass:[NSString class]] ? pending[@"productId"] : nil;
    if (!target.length || !productId.length) return;
    if (![target isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) return;

    IAPCheckLog(@"Target app initiated payment for product: %@", productId);
    IAPCheckInstallTransactionObserver();

    void (^pay)(SKProduct *) = ^(SKProduct *product) {
        [[SKPaymentQueue defaultQueue] addPayment:[SKPayment paymentWithProduct:product]];
        IAPCheckRemovePendingFile(kIAPCheckPendingBuyName);
    };

    SKProduct *cached = gLiveProducts[productId];
    if (cached) {
        pay(cached);
    } else {
        IAPCheckFetchProducts([NSSet setWithObject:productId], ^(NSArray *products) {
            SKProduct *product = products.firstObject;
            if (product) pay(product);
        });
    }
}

#pragma mark - Floating HUD

@interface IAPCheckHUDController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIButton *pill;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL showTrialsOnly;
@end

static UIWindow *gHUDWindow;
static IAPCheckHUDController *gHUDController;

@implementation IAPCheckHUDController

- (NSArray<NSDictionary *> *)rows {
    NSString *bundleId = IAPCheckEffectiveBundle();
    NSArray *all = gCatalogByBundle[bundleId].allValues ?: @[];
    NSArray *sorted = [all sortedArrayUsingDescriptors:
        @[ [NSSortDescriptor sortDescriptorWithKey:@"productId" ascending:YES] ]];
    if (!self.showTrialsOnly) return sorted;
    return [sorted filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"hasFreeTrial == YES"]];
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = [UIColor clearColor];

    CGRect screen = UIScreen.mainScreen.bounds;
    self.pill = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pill.frame = CGRectMake(0, 0, 120, 40);
    self.pill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.pill.layer.cornerRadius = 20;
    self.pill.layer.borderWidth = 1;
    self.pill.layer.borderColor = UIColor.systemPurpleColor.CGColor;
    [self.pill setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.pill.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.pill addTarget:self action:@selector(togglePanel)
        forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.pill];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragged:)];
    [self.pill addGestureRecognizer:pan];

    CGFloat panelWidth = MIN(340.0, screen.size.width - 24);
    CGFloat panelHeight = MIN(320.0, screen.size.height - 200);
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 48, panelWidth, panelHeight)];
    self.panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.92];
    self.panel.layer.cornerRadius = 14;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor = UIColor.systemPurpleColor.CGColor;
    self.panel.hidden = YES;
    [self.view addSubview:self.panel];

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, panelWidth - 24, 18)];
    self.statsLabel.font = [UIFont boldSystemFontOfSize:11];
    self.statsLabel.textColor = UIColor.whiteColor;
    [self.panel addSubview:self.statsLabel];

    UIButton *trialToggle = [UIButton buttonWithType:UIButtonTypeSystem];
    trialToggle.frame = CGRectMake(12, 28, panelWidth - 24, 30);
    trialToggle.backgroundColor = UIColor.systemPurpleColor;
    trialToggle.layer.cornerRadius = 8;
    [trialToggle setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    trialToggle.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [trialToggle setTitle:@"Show trials only" forState:UIControlStateNormal];
    [trialToggle addTarget:self action:@selector(toggleTrials)
          forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:trialToggle];

    UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
    copy.frame = CGRectMake(12, 62, (panelWidth - 30) / 2.0, 28);
    copy.backgroundColor = UIColor.darkGrayColor;
    copy.layer.cornerRadius = 8;
    [copy setTitle:@"Copy JSON" forState:UIControlStateNormal];
    [copy setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    copy.titleLabel.font = [UIFont systemFontOfSize:12];
    [copy addTarget:self action:@selector(copyJSON)
   forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:copy];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(18 + (panelWidth - 30) / 2.0, 62, (panelWidth - 30) / 2.0, 28);
    close.backgroundColor = UIColor.darkGrayColor;
    close.layer.cornerRadius = 8;
    [close setTitle:@"Hide HUD" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:12];
    [close addTarget:self action:@selector(hideHUD)
    forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];

    CGFloat tableY = 98;
    self.table = [[UITableView alloc] initWithFrame:
        CGRectMake(4, tableY, panelWidth - 8, panelHeight - tableY - 6)
        style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorColor = UIColor.darkGrayColor;
    self.table.rowHeight = 46;
    [self.panel addSubview:self.table];
}

- (void)refresh {
    NSInteger total = gCatalogByBundle[IAPCheckEffectiveBundle()].count;
    NSInteger trials = 0;
    for (NSDictionary *p in gCatalogByBundle[IAPCheckEffectiveBundle()].allValues) {
        if ([p[@"hasFreeTrial"] boolValue]) trials++;
    }
    [self.pill setTitle:[NSString stringWithFormat:@"IAP %ld · ★%ld",
                         (long)total, (long)trials]
               forState:UIControlStateNormal];
    self.statsLabel.text = [NSString stringWithFormat:@"%@  ·  %ld products",
                            IAPCheckEffectiveBundle(), (long)total];
    [self.table reloadData];
}

- (void)togglePanel {
    self.expanded = !self.expanded;
    // A UIWindow only renders content inside its own bounds, so the window
    // itself must grow/shrink when the detail panel opens.
    CGRect screen = UIScreen.mainScreen.bounds;
    CGRect frame = gHUDWindow.frame;
    if (self.expanded) {
        CGFloat panelWidth = MIN(340.0, screen.size.width - 24);
        CGFloat panelHeight = MIN(320.0, screen.size.height - 200);
        frame.size = CGSizeMake(panelWidth, 48 + panelHeight);
        self.panel.frame = CGRectMake(0, 48, panelWidth, panelHeight);
        self.panel.hidden = NO;
    } else {
        frame.size = CGSizeMake(120, 40);
        self.panel.hidden = YES;
    }
    gHUDWindow.frame = frame;
    [self refresh];
}

- (void)toggleTrials {
    self.showTrialsOnly = !self.showTrialsOnly;
    [self refresh];
}

- (void)copyJSON {
    NSString *bundleId = IAPCheckEffectiveBundle();
    NSArray *products = gCatalogByBundle[bundleId].allValues ?: @[];
    NSDictionary *payload = @{ @"bundleId": bundleId,
                               @"timestamp": @(IAPCheckNow()),
                               @"products": products };
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload
        options:NSJSONWritingPrettyPrinted error:nil];
    if (json) {
        UIPasteboard.generalPasteboard.string =
            [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    }
}

- (void)hideHUD {
    gHUDWindow.hidden = YES;
}

- (void)dragged:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gHUDWindow];
    [gesture setTranslation:CGPointZero inView:gHUDWindow];
    CGRect frame = gHUDWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    gHUDWindow.frame = frame;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self rows].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseId = @"IAPCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:reuseId];
        cell.backgroundColor = UIColor.clearColor;
        cell.textLabel.textColor = UIColor.whiteColor;
        cell.textLabel.font = [UIFont systemFontOfSize:11];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:10];
    }
    NSDictionary *product = [self rows][indexPath.row];
    NSString *title = [product[@"title"] isKindOfClass:[NSString class]] && [product[@"title"] length]
        ? product[@"title"] : product[@"productId"];
    cell.textLabel.text = title;
    NSMutableString *detail = [NSMutableString stringWithFormat:@"%@",
                               product[@"formattedBasePrice"] ?: @"?"];
    if ([product[@"hasFreeTrial"] boolValue]) [detail appendString:@"  ★ TRIAL"];
    if ([product[@"hasIntroDiscount"] boolValue]) [detail appendString:@"  ◆ INTRO"];
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.textColor =
        [product[@"hasFreeTrial"] boolValue] ? UIColor.systemPurpleColor : UIColor.lightGrayColor;
    return cell;
}

@end

static void IAPCheckHUDEnsure(void) {
    if (gHUDWindow) return;
    CGRect frame = CGRectMake(12, 140, 120, 40);
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = nil;
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if ([candidate isKindOfClass:[UIWindowScene class]] &&
                candidate.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)candidate;
                break;
            }
        }
        window = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                       : [[UIWindow alloc] initWithFrame:frame];
    } else {
        window = [[UIWindow alloc] initWithFrame:frame];
    }
    window.frame = frame;
    window.windowLevel = UIWindowLevelAlert + 100;
    window.backgroundColor = UIColor.clearColor;
    gHUDController = [IAPCheckHUDController new];
    window.rootViewController = gHUDController;
    window.hidden = NO;
    gHUDWindow = window;
    [gHUDController refresh];
}

static void IAPCheckHUDRefresh(void) {
    if (gHUDWindow) { [gHUDController refresh]; return; }
    if (gCatalogByBundle.count) IAPCheckHUDEnsure();
}

#pragma mark - Launch handling

static void IAPCheckOnAppLaunched(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        IAPCheckConsumePendingScan();
        IAPCheckConsumePendingBuy();
        if (!gLaunchProbeDone) {
            gLaunchProbeDone = YES;
            NSSet<NSString *> *receiptIds = IAPCheckReceiptProductIds();
            if (receiptIds.count) {
                IAPCheckLog(@"Probing %lu receipt-derived product ids",
                            (unsigned long)receiptIds.count);
                IAPCheckFetchProducts(receiptIds, nil);
            }
        }
    });
}

static void IAPCheckDarwinCallback(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object,
                                   CFDictionaryRef userInfo) {
    NSString *notification = (__bridge NSString *)name;
    if ([notification isEqualToString:kIAPCheckBuyNotify]) {
        dispatch_async(dispatch_get_main_queue(), ^{ IAPCheckConsumePendingBuy(); });
    } else if ([notification isEqualToString:kIAPCheckScanNotify]) {
        dispatch_async(dispatch_get_main_queue(), ^{ IAPCheckConsumePendingScan(); });
    }
}

#pragma mark - Hooks: app processes

static char kIAPCheckRequestIDsKey;

%group AppHooks

%hook SKProductsRequest

- (instancetype)initWithProductIdentifiers:(NSSet<NSString *> *)identifiers {
    IAPCheckLog(@"Intercepted initWithProductIdentifiers: %@", identifiers);
    id instance = %orig;
    if (instance && identifiers) {
        objc_setAssociatedObject(instance, &kIAPCheckRequestIDsKey, identifiers,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return instance;
}

- (void)setDelegate:(id)delegate {
    %orig;
    IAPCheckSwizzleDelegate(delegate);
}

- (void)start {
    NSSet *ids = objc_getAssociatedObject(self, &kIAPCheckRequestIDsKey);
    IAPCheckLog(@"SKProductsRequest started for: %@", ids ?: @"(unknown ids)");
    %orig;
}

%end

%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
    IAPCheckLog(@"SKPaymentQueue addPayment: %@", payment.productIdentifier);
    %orig;
}

%end

%end // AppHooks

#pragma mark - Hooks: store daemons

%group DaemonHooks

%hook SKClient

- (NSString *)bundleIdentifier {
    NSString *real = %orig;
    NSString *spoof = IAPCheckSpoofBundle();
    if (spoof.length && ![spoof isEqualToString:real]) {
        IAPCheckLog(@"[storekitd] Spoofing SKClient bundleIdentifier %@ -> %@", real, spoof);
        return spoof;
    }
    return real;
}

- (NSString *)clientBundleID {
    NSString *real = %orig;
    NSString *spoof = IAPCheckSpoofBundle();
    if (spoof.length && ![spoof isEqualToString:real]) {
        IAPCheckLog(@"[storekitd] Spoofing SKClient clientBundleID %@ -> %@", real, spoof);
        return spoof;
    }
    return real;
}

%end

%end // DaemonHooks

#pragma mark - Constructor

// SKClient lives in a framework the daemon may load lazily, so the hooks
// install on first sight instead of only at dylib load time.
static BOOL gDaemonHooksInstalled = NO;

static void IAPCheckTryInitDaemonHooks(void) {
    if (gDaemonHooksInstalled) return;
    if (!objc_getClass("SKClient")) return;
    gDaemonHooksInstalled = YES;
    %init(DaemonHooks);
}

static void IAPCheckDyldImageAdded(const struct mach_header *mh, intptr_t slide) {
    IAPCheckTryInitDaemonHooks();
}

%ctor {
    @autoreleasepool {
        gCatalogByBundle   = [NSMutableDictionary new];
        gLiveProducts      = [NSMutableDictionary new];
        gActiveDelegates   = [NSMutableArray new];
        gSwizzledClasses   = [NSMutableSet new];
        gOwnScanQueue      = [NSMutableArray new];
        gWorkQueue         = dispatch_queue_create("com.adr.checkiap.work", DISPATCH_QUEUE_SERIAL);

        NSString *process = [[NSProcessInfo processInfo] processName];
        NSString *bundle  = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        IAPCheckLog(@"Initializing in process: %@ (Bundle: %@)", process, bundle);

        if ([process isEqualToString:@"storekitd"] ||
            [process isEqualToString:@"itunesstored"]) {
            IAPCheckLog(@"Active inside daemon: %@", process);
            IAPCheckTryInitDaemonHooks();
            if (!gDaemonHooksInstalled) {
                _dyld_register_func_for_add_image(&IAPCheckDyldImageAdded);
            }
            return;
        }

        // Skip Apple system apps: they do not use the StoreKit1 request path
        // this tweak captures, and HUD noise there is not useful.
        if ([bundle hasPrefix:@"com.apple."]) return;

        %init(AppHooks);

        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, &IAPCheckDarwinCallback,
            (CFStringRef)kIAPCheckBuyNotify, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, &IAPCheckDarwinCallback,
            (CFStringRef)kIAPCheckScanNotify, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        [[NSNotificationCenter defaultCenter] addObserverForName:
            UIApplicationDidFinishLaunchingNotification
            object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
                IAPCheckOnAppLaunched();
            }];
    }
}

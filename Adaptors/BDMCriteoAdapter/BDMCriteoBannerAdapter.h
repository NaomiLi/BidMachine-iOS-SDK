//
//  BDMCriteoBannerAdapter.h
//
//  Copyright © 2020 Stas Kochkin. All rights reserved.
//

@import Foundation;
@import BidMachine;
@import BidMachine.Adapters;
@import CriteoPublisherSdk;

#import "BDMCriteoAdNetwork.h"

NS_ASSUME_NONNULL_BEGIN

@interface BDMCriteoBannerAdapter : NSObject <BDMBannerAdapter>

- (instancetype)initWithProvider:(id<BDMCriteoAdNetworkProvider>)provider;

@property (nonatomic, weak, nullable) id<BDMAdapterLoadingDelegate> loadingDelegate;
@property (nonatomic, weak, nullable) id <BDMBannerAdapterDisplayDelegate> displayDelegate;

@end

NS_ASSUME_NONNULL_END

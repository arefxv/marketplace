// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

abstract contract Errors {
    error MarketPlace__AlreadyRegistered();
    error MarketPlace__InvalidChargeAmount(uint256);
    error MarketPlace__SubscriptionNotExpired();
    error MarketPlace__OnlySellers();
    error MarketPlace__SubscriptionExpired(uint256);
    error MarketPlace__AmountMustBeMoreThanZero();
    error MarketPlace__CollectionNotFound();
    error MarketPlace__ProductNotFound();
    error MarketPlace__DeadlinePassed();
    error MarketPlace__StatusAlreadyActivated();
    error MarketPlace__YourAccountIsInactivated();
    error MarketPlace__YourAccountIsSuspended();
    error MarketPlace__NotSubscribedYet__TrySubscribeAsSeller();
    error MarketPlace__SellerNotFound();
    error MarketPlace__YouAreNotCollectionOwner();
    error MarketPlace__InvalidProductId();
    error MarketPlace__ProductPriceIsDifferent(uint256);
    error MarketPlace__ProductSoldOut();
    error MarketPlace__MaxDurationIsFourteenDays();
    error MarketPlace__CannotPlaceBidLowerThanStartPrice(uint256);
    error MarketPlace__AuctionEnded();
    error MarketPlace__InvalidDiscountPercentage();
    error MarketPlace__CouponExpired();
    error MarketPlace__CouponAlreadyUsed();
    error MarketPlace__RatingMustBeBetween_1_And_5();
    error MarketPlace__MustPurchaseTheProductFirst();
    error MarketPlace__TicketNotFound();
    error MarketPlace__CategoryNotFound();
    error MarketPlace__RefundRequestNotFound();
    error MarketPlace__NoFundsToWithdraw();
    error MarketPlace__NotEnoughPoints();
    error MarketPlace__AuctionNotEnded();
    error MarketPlace__NoBidsPlaced();
    error MarketPlace__AuctionStillActive();
    error Marketplace__ActionAlreadyFinalized();
    error MarketPlace__YouAreNotProductOwner();
    error MarketPlace__SevenDaysMustPass();
    error MarketPlace__AccountAlreadyInactivated();
    error MarketPlace__YouDidnotOpenedThisTicket();
    error Marketplace__LockUpTimeNotReached();

    error SellerIdentity__SellerAlreadyVerified();
    error SellerIdentity__SBTsAreNonTransferable();
    error MarketPlace__SellerNotVerified();
}

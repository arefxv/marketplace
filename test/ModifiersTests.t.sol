// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {MarketPlace} from "../src/MarketPlace.sol";
import {Errors} from "../src/Errors.sol";
import {SellerIdentity} from "../src/SellerIdentity.sol";

contract SellerTests is Test {
    SellerIdentity kyc;
    MarketPlace mp;

    address owner = address(this);
    address USER = makeAddr("user");
    address SELLER = makeAddr("seller");
    address ADMIN = makeAddr("admin");

    uint256 USER_BALANCE = 10 ether;
    uint256 SELLER_BALANCE = 10 ether;
    uint256 OWNER_BALANCE = 10 ether;
    uint256 VALUE = 1 ether;

    uint256 collectionId = 1;
    uint256 price = 1 ether;
    string description = "description";
    uint256 productId = 1;
    uint256 startPrice = 1 ether;
    uint256 duration = 5 days;

    string public sellerInfo = "https://ipfs.io/ipfs/bafkreifpsulvnhr3gptj2yyevx2wmzqecrbvng44yfibmgv4qujvtwvjjm";

    function setUp() public {
        mp = new MarketPlace();
        kyc = new SellerIdentity();

        vm.deal(owner, OWNER_BALANCE);

        vm.startPrank(owner);
        mp.initialize(address(kyc));
        kyc.mintSBT(SELLER, sellerInfo);
        mp.grantAdminRole(ADMIN);
        vm.stopPrank();

        vm.deal(USER, USER_BALANCE);
        vm.deal(SELLER, SELLER_BALANCE);
    }

    modifier sellerSubed() {
        uint256 sellerSubCharge = mp.getSellersSubscriptionCharge();

        vm.prank(SELLER);
        mp.subscribeAsSeller{value: sellerSubCharge}();
        _;
    }

    modifier collectionCreated() {
        vm.prank(SELLER);
        mp.createCollection("name", "description");
        _;
    }

    modifier auctionCreated() {
        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);
        _;
    }

    modifier productListed() {
        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, false);
        _;
    }

    function testOnlyValidValueModifier() public {
        uint256 sellerSubCharge = mp.getSellersSubscriptionCharge();

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__InvalidChargeAmount.selector, sellerSubCharge));
        mp.subscribeAsSeller{value: sellerSubCharge - 1}();

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__InvalidChargeAmount.selector, sellerSubCharge));
        mp.subscribeAsSeller{value: sellerSubCharge + 1}();

        vm.prank(SELLER);
        mp.subscribeAsSeller{value: sellerSubCharge}();

        vm.warp(block.timestamp + mp.getSellersSubEndTime() + 1);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__InvalidChargeAmount.selector, sellerSubCharge));
        mp.renewSubscription{value: sellerSubCharge - 1}();

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__InvalidChargeAmount.selector, sellerSubCharge));
        mp.renewSubscription{value: sellerSubCharge + 1}();

        vm.prank(SELLER);
        mp.renewSubscription{value: sellerSubCharge}();
    }

    function testMoreThanZeroModifier() public sellerSubed collectionCreated auctionCreated {
        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__AmountMustBeMoreThanZero.selector);
        mp.listProduct(collectionId, 0, description, false);

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__AmountMustBeMoreThanZero.selector);
        mp.placeBid{value: 0}(data);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__AmountMustBeMoreThanZero.selector);
        mp.purchaseProduct{value: 0}(data);
    }

    function testOnlyVerifiedAndNonSuspendedSellersTest() public {
        uint256 sellerSubCharge = mp.getSellersSubscriptionCharge();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.subscribeAsSeller{value: sellerSubCharge}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.renewSubscription{value: sellerSubCharge}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.activateSellerStatus();

        vm.prank(owner);
        kyc.mintSBT(USER, sellerInfo);

        vm.startPrank(USER);
        mp.subscribeAsSeller{value: sellerSubCharge}();

        mp.inactivateSellerStatus();

        mp.activateSellerStatus();

        vm.warp(block.timestamp + mp.getSellersSubEndTime() + 1);

        mp.renewSubscription{value: sellerSubCharge}();
        vm.stopPrank();

        vm.prank(owner);
        mp.changeSellerStatus(false, false, true, USER);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.subscribeAsSeller{value: sellerSubCharge}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.renewSubscription{value: sellerSubCharge}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.activateSellerStatus();
    }

    function testOnlyValidSellersModifier_1() public {
        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.inactivateSellerStatus();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.createCategory("");

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.createCollection("", "");

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.updateCollectionDescription(USER, collectionId, "");

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.listProduct(collectionId, price, "", false);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.listProduct(collectionId, price, "", true);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.addProductToCategory(collectionId, productId, 1);

        MarketPlace.ProductUpdateData memory data = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: 2 ether,
            newDescription: ""
        });

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.updateProduct(data);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.removeProduct(SELLER, collectionId, productId);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.createDiscountCoupon(collectionId, productId, 1, 1);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.cancelSubscription();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.createAuction(SELLER, collectionId, productId, 1, 1);
    }

    function testOnlyValidSellersModifier_2() public sellerSubed {
        MarketPlace.Seller memory seller = mp.getSellersInfo(SELLER);

        vm.warp(block.timestamp + seller.subTimestamp + 1);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));
        mp.createCategory("");

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));
        mp.createCollection("", "");

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));
        mp.updateCollectionDescription(USER, collectionId, "");

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.listProduct(collectionId, price, "", false);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.listProduct(collectionId, price, "", true);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.addProductToCategory(collectionId, productId, 1);

        MarketPlace.ProductUpdateData memory data = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: 2 ether,
            newDescription: ""
        });

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.updateProduct(data);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.removeProduct(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.createDiscountCoupon(collectionId, productId, 1, 1);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.cancelSubscription();

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, seller.subTimestamp));

        mp.createAuction(SELLER, collectionId, productId, 1, 1);
    }

    function testOnlyValidSellersModifier_3() public sellerSubed {
        vm.prank(SELLER);
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.createCategory("");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.createCollection("", "");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.updateCollectionDescription(USER, collectionId, "");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.listProduct(collectionId, price, "", false);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.listProduct(collectionId, price, "", true);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.addProductToCategory(collectionId, productId, 1);

        MarketPlace.ProductUpdateData memory data = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: 2 ether,
            newDescription: ""
        });

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.updateProduct(data);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.removeProduct(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.createDiscountCoupon(collectionId, productId, 1, 1);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.cancelSubscription();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);

        mp.createAuction(SELLER, collectionId, productId, 1, 1);
    }

    function testOnlyValidSellersModifier_4() public sellerSubed {
        vm.prank(owner);
        mp.changeSellerStatus(false, false, true, SELLER);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.createCategory("");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.createCollection("", "");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.updateCollectionDescription(USER, collectionId, "");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.listProduct(collectionId, price, "", false);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.listProduct(collectionId, price, "", true);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.addProductToCategory(collectionId, productId, 1);

        MarketPlace.ProductUpdateData memory data = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: 2 ether,
            newDescription: ""
        });

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.updateProduct(data);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.removeProduct(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.createDiscountCoupon(collectionId, productId, 1, 1);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.cancelSubscription();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);

        mp.createAuction(SELLER, collectionId, productId, 1, 1);
    }

    function testOnlyExistCollectionModifier() public sellerSubed {
        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.updateCollectionDescription(SELLER, collectionId, "");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.listProduct(collectionId, price, "", false);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.listProduct(collectionId, price, "", true);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.createAuction(SELLER, collectionId, productId, 1, 1);

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.placeBid{value: 1}(data);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.getCollection(SELLER, collectionId);
    }

    function testOnlyCollectionOwnerModifier() public sellerSubed collectionCreated productListed {
        uint256 sellerSubCharge = mp.getSellersSubscriptionCharge();

        vm.prank(owner);
        kyc.mintSBT(USER, sellerInfo);

        vm.prank(USER);
        mp.subscribeAsSeller{value: sellerSubCharge}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotCollectionOwner.selector);
        mp.updateCollectionDescription(SELLER, collectionId, "");

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotCollectionOwner.selector);
        mp.removeProduct(SELLER, collectionId, productId);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotCollectionOwner.selector);
        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotCollectionOwner.selector);
        mp.createAuction(SELLER, collectionId, productId, 1, 1);

        vm.startPrank(USER);
        uint256 _collectionId = mp.createCollection("", "");
        mp.listProduct(_collectionId, price, "", false);
        vm.stopPrank();

        MarketPlace.ProductUpdateData memory data = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: 2 ether,
            newDescription: ""
        });

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotProductOwner.selector);
        mp.updateProduct(data);
    }
}

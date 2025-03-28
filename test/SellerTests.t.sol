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

    string public sellerInfo = "https://ipfs.io/ipfs/bafkreifpsulvnhr3gptj2yyevx2wmzqecrbvng44yfibmgv4qujvtwvjjm";

    event SellerSubscribed(address seller, uint256 sellerId, uint256 subscriptionTime);
    event CategoryCreated(address seller, uint256 categoryId, string categoryName);
    event SellerInactivatedStatus(address seller);
    event SellerActivatedStatus(address seller);
    event SubscriptionRenewed(address seller);
    event CollectionCreated(address seller, string collectionName, string collectionDescription, uint256 collectionId);
    event CollectionDescriptionUpdated(address seller, uint256 collectionId, string newDescription);
    event ProductListed(address seller, uint256 collectionId, uint256 productId);
    event ProductAddedToCategory(address seller, uint256 collectionId, uint256 productId, uint256 categoryId);
    event ProductUpdated(
        address seller, uint256 collectionId, uint256 productId, uint256 newPrice, string newDescription
    );
    event ProductRemoved(address seller, uint256 collectionId, uint256 productId);
    event ProductMarkedAsSoldOut(address seller, uint256 collectionId, uint256 productId, bool soldOut);
    event DiscountCouponCreated(
        address seller, uint256 collectionId, uint256 productId, uint256 discountPercentage, uint256 expirationTime
    );
    event SubscriptionCancelled(address seller);
    event FundsWithdrawn(address user, uint256 value);
    event AuctionCreated(address seller, uint256 collectionId, uint256 productId, uint256 startPrice, uint256 duration);
    event AuctionFinalized(
        address seller, uint256 collectionId, uint256 productId, address highestBidder, uint256 highestBid
    );

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

    function testUserCanSubAsSeller() public {
        uint256 idBeforeSub = 0;
        uint256 subTimestampBefore = 0;
        bool isSellerBefore = false;
        uint256 expectedStartingTotalSellers = 0;
        uint256 actualStartingTotalSellers = mp.getTotalSellers();

        MarketPlace.Seller memory seller = mp.getSellersInfo(SELLER);
        assertEq(idBeforeSub, seller.id);
        assertEq(subTimestampBefore, seller.subTimestamp);
        assertEq(isSellerBefore, seller.isSeller);
        assertEq(actualStartingTotalSellers, expectedStartingTotalSellers);

        vm.expectEmit(false, false, false, true);
        emit SellerSubscribed(SELLER, 1, block.timestamp + mp.getSellersSubEndTime());
        vm.prank(SELLER);
        uint256 sellerId = mp.subscribeAsSeller{value: 0.01 ether}();

        uint256 expectedSellerId = 1;
        uint256 actualSellerId = mp.getSellerId(SELLER);

        assertEq(sellerId, expectedSellerId);
        assertEq(sellerId, actualSellerId);

        uint256 idAfterSub = 1;
        uint256 subTimestampAfter = block.timestamp + mp.getSellersSubEndTime();
        bool isSellerAfter = true;
        uint256 expectedEndingTotalSellers = 1;
        uint256 actualEndingTotalSellers = mp.getTotalSellers();

        seller = mp.getSellersInfo(SELLER);
        assertEq(idAfterSub, seller.id);
        assertEq(subTimestampAfter, seller.subTimestamp);
        assertEq(isSellerAfter, seller.isSeller);
        assertEq(actualEndingTotalSellers, expectedEndingTotalSellers);
        assertEq(uint256(mp.getSellerStatus(SELLER)), 0);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__AlreadyRegistered.selector);
        mp.subscribeAsSeller{value: 0.01 ether}();

        assertTrue(mp.isVerifiedSeller(SELLER));
    }

    function testNonVerifiedUsersCannotSubAsSeller() public {
        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.subscribeAsSeller{value: 0.01 ether}();
    }

    function testSuspendedUsersCannotSubAsSeller() public {
        vm.prank(SELLER);
        mp.subscribeAsSeller{value: 0.01 ether}();

        vm.prank(ADMIN);
        mp.changeSellerStatus(false, false, true, SELLER);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.subscribeAsSeller{value: 0.01 ether}();
    }

    modifier sellerSubed() {
        vm.prank(SELLER);
        mp.subscribeAsSeller{value: 0.01 ether}();
        _;
    }

    function testSellerCanCreateCategory() public sellerSubed {
        vm.startPrank(SELLER);

        vm.expectEmit(false, false, false, true);
        emit CategoryCreated(SELLER, 1, "first category");

        mp.createCategory("first category");

        vm.expectEmit(false, false, false, true);
        emit CategoryCreated(SELLER, 2, "second category");

        mp.createCategory("second category");

        MarketPlace.Category[] memory categories = mp.getSellerCategories(SELLER);
        uint256 expectedFirstCategoryId = 1;
        string memory expectedFirstCategoryName = "first category";
        uint256 actualFirstCategoryId = categories[0].categoryId;
        string memory actualFirstCategoryName = categories[0].categoryName;

        uint256 expectedSecondCategoryId = 2;
        string memory expectedSecondCategoryName = "second category";
        uint256 actualSecondCategoryId = categories[1].categoryId;
        string memory actualSecondCategoryName = categories[1].categoryName;

        uint256 expectedTotalCategories = 2;
        uint256 actualTotalCategories = mp.getTotalCreatedCategories();

        assertEq(actualFirstCategoryId, expectedFirstCategoryId);
        assertEq(actualFirstCategoryName, expectedFirstCategoryName);
        assertEq(actualSecondCategoryId, expectedSecondCategoryId);
        assertEq(actualSecondCategoryName, expectedSecondCategoryName);
        assertEq(actualTotalCategories, expectedTotalCategories);

        MarketPlace.Category memory category = mp.getSellerCategoryByCategoryId(SELLER, actualFirstCategoryId);

        assertEq(category.categoryId, actualFirstCategoryId);
        assertEq(category.categoryName, actualFirstCategoryName);

        vm.stopPrank();
    }

    function testSellerCanInactivatesStatus() public sellerSubed {
        vm.expectEmit(false, false, false, true);
        emit SellerInactivatedStatus(SELLER);

        vm.prank(SELLER);
        mp.inactivateSellerStatus();

        assertEq(uint256(mp.getSellerStatus(SELLER)), 1);
    }

    function testInactivateSellerStatusFailsIfConditionsNotMet() public sellerSubed {
        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        mp.inactivateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.inactivateSellerStatus();

        vm.prank(ADMIN);
        mp.changeSellerStatus(false, false, true, SELLER);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.inactivateSellerStatus();
    }

    function testInactivateSellerStatusFailsIfSubTimePassed() public sellerSubed {
        MarketPlace.Seller memory seller = mp.getSellersInfo(SELLER);

        uint256 sellerEndTime = seller.subTimestamp;

        vm.warp(block.timestamp + sellerEndTime + 1);
        vm.roll(block.number + 1);

        vm.prank(SELLER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__SubscriptionExpired.selector, sellerEndTime));
        mp.inactivateSellerStatus();
    }

    function testSellerCanActivateStatus() public sellerSubed {
        vm.startPrank(SELLER);
        mp.inactivateSellerStatus();

        vm.expectEmit(false, false, false, true);
        emit SellerActivatedStatus(SELLER);

        mp.activateSellerStatus();
        vm.stopPrank();

        assertEq(uint256(mp.getSellerStatus(SELLER)), 0);
    }

    function testActivateStatusFailsIfConditionsNotMet() public {
        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.activateSellerStatus();

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__StatusAlreadyActivated.selector);
        mp.activateSellerStatus();

        vm.prank(SELLER);
        mp.subscribeAsSeller{value: 0.01 ether}();

        vm.prank(ADMIN);
        mp.changeSellerStatus(false, false, true, SELLER);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.activateSellerStatus();
    }

    function testSellerCanRenewSubscription() public sellerSubed {
        MarketPlace.Seller memory seller = mp.getSellersInfo(SELLER);

        uint256 sellerEndTime = seller.subTimestamp;

        vm.warp(block.timestamp + sellerEndTime + 1);
        vm.roll(block.number + 1);

        vm.expectEmit(false, false, false, true);
        emit SubscriptionRenewed(SELLER);

        vm.prank(SELLER);
        mp.renewSubscription{value: 0.01 ether}();

        seller = mp.getSellersInfo(SELLER);

        assertEq(seller.subTimestamp, sellerEndTime + mp.getSellersSubEndTime());
    }

    function testRenewSubscriptionFailsIfConditionsNotMet() public sellerSubed {
        vm.startPrank(SELLER);

        vm.expectRevert(Errors.MarketPlace__SubscriptionNotExpired.selector);
        mp.renewSubscription{value: 0.01 ether}();

        mp.inactivateSellerStatus();

        vm.expectRevert(Errors.MarketPlace__YourAccountIsInactivated.selector);
        mp.renewSubscription{value: 0.01 ether}();
        vm.stopPrank();

        vm.prank(ADMIN);
        mp.changeSellerStatus(false, false, true, SELLER);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__YourAccountIsSuspended.selector);
        mp.renewSubscription{value: 0.01 ether}();

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__SellerNotVerified.selector);
        mp.renewSubscription{value: 0.01 ether}();
    }

    function testRenewSubscriptionFailsIfSellerNotSubed() public {
        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__NotSubscribedYet__TrySubscribeAsSeller.selector);
        mp.renewSubscription{value: 0.01 ether}();
    }

    function testSellerCanCreateCollection() public sellerSubed {
        vm.expectEmit(false, false, false, true);
        emit CollectionCreated(SELLER, "name", "description", 1);

        vm.startPrank(SELLER);
        uint256 collectionId = mp.createCollection("name", "description");

        (address _owner, uint256 id, string memory name, string memory description, uint256 productCount) =
            mp.getCollection(SELLER, collectionId);
        vm.stopPrank();

        assertEq(_owner, SELLER);
        assertEq(id, collectionId);
        assertEq(name, "name");
        assertEq(description, "description");
        assertEq(productCount, 0);
        assertEq(mp.getSellerTotalCollections(SELLER), 1);
    }

    modifier collectionCreated() {
        vm.prank(SELLER);
        mp.createCollection("name", "description");
        _;
    }

    function testSellerCanUpdateCollectionDescription() public sellerSubed collectionCreated {
        uint256 collectionId = 1;

        vm.startPrank(SELLER);

        (,,, string memory startingDescription,) = mp.getCollection(SELLER, collectionId);

        assertEq(startingDescription, "description");

        vm.expectEmit(false, false, false, true);
        emit CollectionDescriptionUpdated(SELLER, collectionId, "new description");

        mp.updateCollectionDescription(SELLER, collectionId, "new description");

        (,,, string memory newDescription,) = mp.getCollection(SELLER, collectionId);

        assertEq(newDescription, "new description");
        vm.stopPrank();
    }

    function testUpdateCollectionDescriptionFailsIfCollectionIdNotValid() public sellerSubed collectionCreated {
        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.updateCollectionDescription(SELLER, 2, "new description");

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.updateCollectionDescription(SELLER, 0, "new description");
    }

    function testUpdateDescriptionFailsIfNotCollectionOwner() public sellerSubed collectionCreated {
        vm.prank(owner);
        kyc.mintSBT(USER, sellerInfo);

        vm.startPrank(USER);
        mp.subscribeAsSeller{value: 0.01 ether}();

        vm.expectRevert(Errors.MarketPlace__YouAreNotCollectionOwner.selector);
        mp.updateCollectionDescription(SELLER, 1, "new description");
        vm.stopPrank();
    }

    function testSellerCanListProductForNonPremiumUsers() public sellerSubed collectionCreated {
        uint256 collectionId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        vm.startPrank(SELLER);
        vm.expectRevert(Errors.MarketPlace__AmountMustBeMoreThanZero.selector);
        mp.listProduct(collectionId, 0, description, false);

        vm.expectEmit(false, false, false, true);
        emit ProductListed(SELLER, collectionId, 1);

        mp.listProduct(collectionId, price, description, false);
        vm.stopPrank();

        MarketPlace.Product[] memory products = mp.getProducts(SELLER, collectionId);

        (,,,, uint256 productCounts) = mp.getCollection(SELLER, collectionId);

        assertEq(products[0].productId, 1);
        assertEq(products[0].price, price);
        assertEq(products[0].productDescription, description);
        assertEq(products[0].couponId, 0);
        assertEq(products[0].discountedPrice, 0);
        assertEq(products[0].owner, SELLER);
        assertFalse(products[0].soldOut);
        assertFalse(products[0].forPremiums);
        assertEq(productCounts, 1);
    }

    function testSellerCanListProductForPremiumUsers() public sellerSubed collectionCreated {
        uint256 collectionId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, true);

        MarketPlace.Product[] memory products = mp.getProducts(SELLER, collectionId);

        (,,,, uint256 productCounts) = mp.getCollection(SELLER, collectionId);

        assertEq(products[0].productId, 1);
        assertEq(products[0].price, price);
        assertEq(products[0].productDescription, description);
        assertEq(products[0].couponId, 0);
        assertEq(products[0].discountedPrice, 0);
        assertEq(products[0].owner, SELLER);
        assertFalse(products[0].soldOut);
        assertTrue(products[0].forPremiums);
        assertEq(productCounts, 1);
    }

    modifier categoryCreated() {
        vm.prank(SELLER);
        mp.createCategory("first category");
        _;
    }

    modifier productListedNP() {
        //non premiums
        uint256 collectionId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, false);
        _;
    }

    function testSellerCanAddProductToCategory() public sellerSubed collectionCreated productListedNP categoryCreated {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 categoryId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, false);

        vm.expectEmit(false, false, false, true);
        emit ProductAddedToCategory(SELLER, collectionId, productId, categoryId);

        vm.prank(SELLER);
        mp.addProductToCategory(collectionId, productId, categoryId);
        vm.prank(SELLER);
        mp.addProductToCategory(collectionId, productId + 1, categoryId);

        uint256[] memory products = mp.getCategoryProducts(SELLER, categoryId);

        assertEq(products.length, 2);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__CategoryNotFound.selector);
        mp.getCategoryProducts(SELLER, 0);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__InvalidProductId.selector);
        mp.addProductToCategory(collectionId, productId + 2, categoryId);
    }

    function testSellerCanUpdateProduct() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        MarketPlace.Product[] memory product = mp.getProducts(SELLER, collectionId);
        assertEq(product[0].price, price);
        assertEq(product[0].productDescription, description);

        uint256 newPrice = 2 ether;
        string memory newDescription = "new description";

        MarketPlace.ProductUpdateData memory updateData = MarketPlace.ProductUpdateData({
            collectionOwner: SELLER,
            collectionId: collectionId,
            productId: productId,
            newPrice: newPrice,
            newDescription: newDescription
        });

        vm.expectEmit(false, false, false, true);
        emit ProductUpdated(SELLER, collectionId, productId, newPrice, newDescription);

        vm.prank(SELLER);
        mp.updateProduct(updateData);

        product = mp.getProducts(SELLER, collectionId);
        assertEq(product[0].price, newPrice);
        assertEq(product[0].productDescription, newDescription);
    }

    function testSellerCanRemoveProduct() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;

        (,,,, uint256 productCount) = mp.getCollection(SELLER, collectionId);
        MarketPlace.Product[] memory products = mp.getProducts(SELLER, collectionId);

        assertEq(productCount, 1);
        assertEq(products.length, 1);

        vm.expectEmit(false, false, false, true);
        emit ProductRemoved(SELLER, collectionId, productId);

        vm.prank(SELLER);
        mp.removeProduct(SELLER, collectionId, productId);

        (,,,, uint256 productCountAfterRemove) = mp.getCollection(SELLER, collectionId);
        products = mp.getProducts(SELLER, collectionId);

        assertEq(productCountAfterRemove, 0);
        assertEq(products.length, 0);
    }

    function testSellerCanmarkProductAsSoldOut() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;

        (
            uint256 price,
            string memory productDescription,
            bool soldOut,
            uint256 couponId,
            uint256 discountedPrice,
            bool forPremiums,
            address _owner
        ) = mp.getProduct(SELLER, collectionId, productId);

        assertEq(price, 1 ether);
        assertEq(productDescription, "description");
        assertEq(couponId, 0);
        assertEq(discountedPrice, 0);
        assertEq(_owner, SELLER);
        assertFalse(soldOut);
        assertFalse(forPremiums);

        vm.expectEmit(false, false, false, true);
        emit ProductMarkedAsSoldOut(SELLER, collectionId, productId, true);

        vm.prank(SELLER);
        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        (,, bool _soldOut,,,,) = mp.getProduct(SELLER, collectionId, productId);

        assertTrue(_soldOut);
    }

    function testSellerCanCreateDiscountCoupon() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 discountPercentage = 10;
        uint256 expirationTime = 1 days;

        vm.expectEmit(false, false, false, true);
        emit DiscountCouponCreated(SELLER, collectionId, productId, discountPercentage, expirationTime);

        vm.prank(SELLER);
        uint256 couponId = mp.createDiscountCoupon(collectionId, productId, discountPercentage, expirationTime);
        uint256 expectedCouponId = 1;

        assertEq(couponId, expectedCouponId);

        (uint256 _discountPercentage, uint256 _expirationTime, bool _isUsed) = mp.getDiscountCoupon(couponId);

        assertEq(_discountPercentage, discountPercentage);
        assertEq(_expirationTime, expirationTime);
        assertFalse(_isUsed);

        MarketPlace.DiscountCoupon memory discountCoupon = mp.getCouponIdDetails(couponId);

        assertEq(discountCoupon.discountPercentage, discountPercentage);
        assertEq(discountCoupon.expirationTime, expirationTime);
        assertFalse(discountCoupon.isUsed);

        uint256 expectedTotalCoupons = 1;
        uint256 actualTotalCoupons = mp.getTotalDiscountCoupons();

        assertEq(actualTotalCoupons, expectedTotalCoupons);
    }

    function testCreateDiscountCouponFailsIfConditionsNotMet() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 discountPercentage = 10;
        uint256 expirationTime = block.timestamp - 1;

        vm.startPrank(SELLER);
        vm.expectRevert(Errors.MarketPlace__InvalidDiscountPercentage.selector);
        mp.createDiscountCoupon(collectionId, productId, 0, expirationTime);

        vm.expectRevert(Errors.MarketPlace__InvalidDiscountPercentage.selector);
        mp.createDiscountCoupon(collectionId, productId, 100, expirationTime);

        vm.expectRevert(Errors.MarketPlace__CouponExpired.selector);
        mp.createDiscountCoupon(collectionId, productId, discountPercentage, expirationTime);
    }

    function testSellerCanCancelSubscription() public sellerSubed collectionCreated {
        uint256 collectionId = 1;

        (address _owner, uint256 id, string memory name, string memory description, uint256 productCount) =
            mp.getCollection(SELLER, collectionId);
        assertEq(_owner, SELLER);
        assertEq(id, collectionId);
        assertEq(name, "name");
        assertEq(description, "description");
        assertEq(productCount, 0);

        MarketPlace.Seller memory seller = mp.getSellersInfo(SELLER);

        assertEq(seller.seller, SELLER);
        assertEq(seller.id, 1);
        assertTrue(seller.isSeller);
        assertEq(uint256(mp.getSellerStatus(SELLER)), 0);

        vm.expectEmit(false, false, false, true);
        emit SubscriptionCancelled(SELLER);

        vm.prank(SELLER);
        mp.cancelSubscription();

        seller = mp.getSellersInfo(SELLER);
        assertFalse(seller.isSeller);
        assertEq(uint256(mp.getSellerStatus(SELLER)), 0); //deleted

        uint256 expectedSellerPendingWithdraw = 0.01 ether;
        uint256 actualSellerPendingWithdraw = mp.getSellerPendingWithdrawls(SELLER);

        assertEq(actualSellerPendingWithdraw, expectedSellerPendingWithdraw);

        uint256 startingSellerBalance = SELLER.balance;

        vm.expectEmit(false, false, false, true);
        emit FundsWithdrawn(SELLER, actualSellerPendingWithdraw);

        vm.prank(SELLER);
        mp.withdraw();

        uint256 endingSellerBalance = SELLER.balance;

        assertEq(endingSellerBalance, startingSellerBalance + actualSellerPendingWithdraw);

        uint256 endingSellerPendingWithdraw = mp.getSellerPendingWithdrawls(SELLER);

        assertEq(endingSellerPendingWithdraw, 0);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CollectionNotFound.selector);
        mp.getCollection(SELLER, collectionId);
    }

    function testCancelSubscriptionFailsIfConditionsNotMet() public sellerSubed {
        vm.startPrank(SELLER);
        vm.expectRevert(Errors.MarketPlace__NoFundsToWithdraw.selector);
        mp.withdraw();

        uint256 userDeadline = mp.getSubscriptionCancellationDeadline();

        vm.warp(block.timestamp + userDeadline + 1);

        vm.expectRevert(Errors.MarketPlace__DeadlinePassed.selector);
        mp.cancelSubscription();

        vm.stopPrank();
    }

    function testSellerCanCreateAuction() public sellerSubed collectionCreated {
        vm.startPrank(SELLER);
        mp.listProduct(1, 1 ether, "description", false);

        vm.expectEmit(false, false, false, true);
        emit AuctionCreated(SELLER, 1, 1, 1 ether, 5 days);

        mp.createAuction(SELLER, 1, 1, 1 ether, 5 days);

        MarketPlace.Auction[] memory auctions = mp.getActiveAuctions(SELLER, 1);
        assertEq(auctions[0].seller, SELLER);
        assertEq(auctions[0].startPrice, 1 ether);
        assertEq(auctions[0].startTime, block.timestamp);
        assertEq(auctions[0].duration, block.timestamp + 5 days);
        vm.stopPrank();
        vm.startPrank(SELLER);
    }

    function testSellerCantSetAuctionTimeMoreThanMaxTime() public sellerSubed collectionCreated {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        string memory des = "description";
        uint256 duration = mp.getMaxAuctionDuration() + 1;

        vm.startPrank(SELLER);
        mp.listProduct(collectionId, startPrice, des, false);

        vm.expectRevert(Errors.MarketPlace__MaxDurationIsFourteenDays.selector);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);
        vm.stopPrank();
    }

    function testSellerCanFinalizeAuction() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        MarketPlace.Auction memory auction = mp.getAuction(SELLER, collectionId, productId);

        assertFalse(auction.finalized);

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + duration + 2);

        vm.expectEmit(false, false, false, true);
        emit AuctionFinalized(SELLER, collectionId, productId, USER, startPrice + 1);

        vm.prank(SELLER);
        mp.finalizeAuction(data);

        auction = mp.getAuction(SELLER, collectionId, productId);

        assertTrue(auction.finalized);

        MarketPlace.Auction[] memory auctions = mp.getActiveAuctions(SELLER, collectionId);

        if (auctions.length > 0) {
            assertTrue(auctions[0].finalized);
        } else {
            assertTrue(true);
        }
    }

    function testFundsWithdrawToSellerAfterFinalizingAnAuction() public sellerSubed collectionCreated productListedNP {
        uint256 startingSellerBalance = SELLER.balance;

        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + duration + 2);

        vm.prank(SELLER);
        mp.finalizeAuction(data);

        uint256 endingSellerBalance = SELLER.balance;

        assertEq(endingSellerBalance, startingSellerBalance + startPrice + 1);
    }

    function testProductOwnershipWillBeTransferedToBuyerAfterFinalizingAuction()
        public
        sellerSubed
        collectionCreated
        productListedNP
    {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        (,,,,,, address productOwnerBefore) = mp.getProduct(SELLER, collectionId, productId);

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + duration + 2);

        vm.prank(SELLER);
        mp.finalizeAuction(data);

        (,,,,,, address productOwnerAfter) = mp.getProduct(SELLER, collectionId, productId);

        assertEq(productOwnerBefore, SELLER);
        assertEq(productOwnerAfter, USER);
    }

    function testTxWillbeSavedAfterFinalizingAnAuction() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + duration + 2);

        vm.prank(SELLER);
        mp.finalizeAuction(data);

        MarketPlace.Transaction[] memory txs = mp.getTransactionHistory(SELLER);
        assertEq(txs[0].buyer, USER);
        assertEq(txs[0].seller, SELLER);
        assertEq(txs[0].collectionId, collectionId);
        assertEq(txs[0].productId, productId);
        assertEq(txs[0].value, startPrice + 1);
        assertEq(txs[0].timestamp, block.timestamp);

        vm.prank(SELLER);
        vm.expectRevert(Errors.Marketplace__ActionAlreadyFinalized.selector);
        mp.finalizeAuction(data);
    }

    function testFinalizeAuctionFailsIfTimeNotPassed() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__AuctionStillActive.selector);
        mp.finalizeAuction(data);
    }

    function testFinalizingFailsIfNoBidsPlaced() public sellerSubed collectionCreated productListedNP {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);

        vm.warp(block.timestamp + duration + 2);

        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__NoBidsPlaced.selector);
        mp.finalizeAuction(data);
    }

    function testAddProductToCategoryFailsIfCategoryIdInvalid() public sellerSubed collectionCreated productListedNP {
        vm.prank(SELLER);
        vm.expectRevert(Errors.MarketPlace__CategoryNotFound.selector);
        mp.addProductToCategory(1, 1, 0);
    }
}

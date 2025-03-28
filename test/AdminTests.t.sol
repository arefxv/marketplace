// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {MarketPlace} from "../src/MarketPlace.sol";
import {Errors} from "../src/Errors.sol";
import {SellerIdentity} from "../src/SellerIdentity.sol";

contract AdminTests is Test {
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

    event AdminRoleGrant(address admin);
    event SellerSubscriptionFeeChanged(uint256 newFee);
    event PremiumSubscriptionFeeChanged(uint256 newFee);
    event PlatformPercentageChanged(uint256 newPercentage);
    event AdminInactivatedSeller(address seller);
    event AdminActivatedSeller(address seller);
    event AdminSuspendedSeller(address seller);
    event RefundApproved(address buyer, uint256 requestId);
    event RefundRejected(address buyer, uint256 requestId);

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

        vm.prank(SELLER);
        mp.subscribeAsSeller{value: 0.01 ether}();
    }

    function testOwnerCanGrantRoleAndNonOwnerCant() public {
        vm.expectEmit(false, false, false, true);
        emit AdminRoleGrant(ADMIN);

        vm.prank(owner);
        mp.grantAdminRole(ADMIN);

        vm.prank(USER);
        vm.expectRevert();
        mp.grantAdminRole(ADMIN);

        vm.prank(ADMIN);
        vm.expectRevert();
        mp.grantAdminRole(USER);
    }

    function testOwnerCanSetNewPremiumUserDiscountPercentageAndNonOwnerCant() public {
        uint256 newPercentage = 10;

        vm.prank(owner);
        mp.setNewPremiumUserDiscountPercentage(newPercentage);

        uint256 actualnewPercentage = mp.getPremiumDiscountUserPercentage();

        assertEq(actualnewPercentage, newPercentage);

        vm.prank(USER);
        vm.expectRevert();
        mp.setNewPremiumUserDiscountPercentage(newPercentage);
    }

    function testPremiumDiscountPercentageCalculatesCorrect() public {
        uint256 price = 1 ether;

        uint256 newPercentage = 10;

        vm.prank(owner);
        mp.setNewPremiumUserDiscountPercentage(newPercentage);

        uint256 expectedDiscountAmount = 0.1 ether;
        console.log("expectedPriceAfterDiscount", expectedDiscountAmount);

        uint256 actualDiscountAmount = mp.getPremiumUsersDiscount(price);
        console.log("actualPriceAfterDiscount", actualDiscountAmount);

        assertEq(actualDiscountAmount, expectedDiscountAmount);
    }

    function testOwnerCanSetNewSellerSubscriptionFeeAndOthersCant() public {
        uint256 beforeSubFee = mp.getSellersSubscriptionCharge();
        uint256 newFee = 0.2 ether;

        vm.expectEmit(false, false, false, true);
        emit SellerSubscriptionFeeChanged(newFee);

        vm.prank(owner);
        mp.setSellerSubscriptionFee(newFee);

        uint256 actualNewFee = mp.getSellersSubscriptionCharge();

        assertGt(newFee, beforeSubFee);
        assertEq(actualNewFee, newFee);

        vm.prank(USER);
        vm.expectRevert();
        mp.setSellerSubscriptionFee(newFee);
    }

    function testOwnerCanSetNewPremiumSubFeeAndNonOwnerCant() public {
        uint256 beforeSubFee = mp.getPremiumSubscriptionFee();
        uint256 newFee = 0.2 ether;

        vm.expectEmit(false, false, false, true);
        emit PremiumSubscriptionFeeChanged(newFee);

        vm.prank(owner);
        mp.setPremiumSubscriptionFee(newFee);

        uint256 actualNewFee = mp.getPremiumSubscriptionFee();

        assertGt(newFee, beforeSubFee);
        assertEq(actualNewFee, newFee);

        vm.prank(USER);
        vm.expectRevert();
        mp.setSellerSubscriptionFee(newFee);
    }

    function testOwnerCanSetNewPlatformPercentageAndNonOwnerCant() public {
        uint256 platformFeeBeforeChange = mp.getPlatformPercentage();
        uint256 newPlatformFeePercentage = 6;

        vm.expectEmit(false, false, false, true);
        emit PlatformPercentageChanged(newPlatformFeePercentage);

        vm.prank(owner);
        mp.setNewPlatformPercentage(newPlatformFeePercentage);

        uint256 platformFeeAfterChange = mp.getPlatformPercentage();

        assertGt(platformFeeAfterChange, platformFeeBeforeChange);
        assertEq(platformFeeBeforeChange, 5);
        assertEq(platformFeeAfterChange, newPlatformFeePercentage);

        vm.prank(USER);
        vm.expectRevert();
        mp.setNewPlatformPercentage(newPlatformFeePercentage);
    }

    function testOwnerCanSetNewEthValueToPointAndOthersCant() public {
        uint256 newValueToPoint = 2 ether;

        vm.prank(owner);
        mp.setNewEthValueToPoint(newValueToPoint);

        uint256 actualNewValueToPoint = mp.getEthValueToPoint();

        assertEq(actualNewValueToPoint, newValueToPoint);

        vm.prank(USER);
        vm.expectRevert();
        mp.setNewEthValueToPoint(newValueToPoint);
    }

    function testOwnerCanSetNewRequiredDiscountPointsAndOthersCant() public {
        uint256 newRequiredPoints = 150 ether;

        vm.prank(owner);
        mp.setNewRequiredDiscountPoints(newRequiredPoints);

        uint256 actualNewRequiredPoints = mp.getRequiredDiscountPoints();

        assertEq(actualNewRequiredPoints, newRequiredPoints);

        vm.prank(USER);
        vm.expectRevert();
        mp.setNewEthValueToPoint(newRequiredPoints);
    }

    function testAdminsCanChangeSellersStatusAndFailsIfConditionsNotMet() public {
        vm.startPrank(ADMIN);

        vm.expectEmit(false, false, false, true);
        emit AdminInactivatedSeller(SELLER);

        mp.changeSellerStatus(true, false, false, SELLER);

        uint256 inactive = 1;

        assertEq(uint256(mp.getSellerStatus(SELLER)), inactive);

        vm.expectEmit(false, false, false, true);
        emit AdminActivatedSeller(SELLER);

        mp.changeSellerStatus(false, true, false, SELLER);

        uint256 active = 0;

        assertEq(uint256(mp.getSellerStatus(SELLER)), active);

        vm.expectEmit(false, false, false, true);
        emit AdminSuspendedSeller(SELLER);

        mp.changeSellerStatus(false, false, true, SELLER);

        uint256 suspended = 2;

        assertEq(uint256(mp.getSellerStatus(SELLER)), suspended);

        vm.expectRevert(Errors.MarketPlace__SellerNotFound.selector);
        mp.changeSellerStatus(false, false, true, USER);

        vm.stopPrank();

        vm.prank(USER);
        vm.expectRevert();
        mp.changeSellerStatus(false, false, true, SELLER);
    }

    function testAdminsCanFinalizeAuctions() public {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 startPrice = 1 ether;
        uint256 duration = 5 days;
        uint256 price = 1 ether;
        string memory description = "description";

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.startPrank(SELLER);
        mp.createCollection("name", "description");
        mp.listProduct(collectionId, price, description, false);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);
        vm.stopPrank();

        uint256 startingSellerBalance = SELLER.balance;

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + duration + 2);

        vm.prank(ADMIN);
        mp.finalizeAuctionByAdmin(data);

        uint256 endingSellerBalance = SELLER.balance;

        assertEq(endingSellerBalance, startingSellerBalance + startPrice + 1);

        MarketPlace.Auction memory auction = mp.getAuction(SELLER, collectionId, productId);
        assertTrue(auction.finalized);

        (,,,,,, address productOwnerAfter) = mp.getProduct(SELLER, collectionId, productId);

        assertEq(productOwnerAfter, USER);

        MarketPlace.Transaction[] memory txs = mp.getTransactionHistory(ADMIN);
        assertEq(txs[0].buyer, USER);
        assertEq(txs[0].seller, SELLER);
        assertEq(txs[0].collectionId, collectionId);
        assertEq(txs[0].productId, productId);
        assertEq(txs[0].value, startPrice + 1);
        assertEq(txs[0].timestamp, block.timestamp);
    }

    function testAdminsCanApproveRefundRequests() public {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.startPrank(SELLER);
        mp.createCollection("name", "description");
        mp.listProduct(collectionId, price, description, false);
        vm.stopPrank();

        vm.startPrank(USER);
        mp.purchaseProduct{value: price}(data);
        uint256 requestId = mp.requestRefund(data, "reason");
        vm.stopPrank();

        MarketPlace.RefundData memory refundData = MarketPlace.RefundData({
            seller: SELLER,
            buyer: USER,
            requestId: requestId,
            productId: productId,
            collectionId: collectionId,
            value: price
        });

        (,,,,,, address productOwnerBeforeApproval) = mp.getProduct(SELLER, collectionId, productId);

        vm.expectEmit(false, false, false, true);
        emit RefundApproved(USER, requestId);

        uint256 startingUserBalance = USER.balance;

        vm.prank(ADMIN);
        mp.processRefund(refundData, true);

        uint256 endingUserBalance = USER.balance;

        MarketPlace.RefundRequest memory refund = mp.getUserRefundRequests(USER, requestId);

        assertTrue(refund.isApproved);

        (,,,,,, address productOwnerAfterApproval) = mp.getProduct(SELLER, collectionId, productId);

        assertEq(productOwnerBeforeApproval, USER);
        assertEq(productOwnerAfterApproval, SELLER);
        assertEq(endingUserBalance, startingUserBalance + price);
    }

    function testProcessRefundEmitsAnEventIfAdminsRejectRequest() public {
        uint256 collectionId = 1;
        uint256 productId = 1;
        uint256 price = 1 ether;
        string memory description = "description";

        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.startPrank(SELLER);
        mp.createCollection("name", "description");
        mp.listProduct(collectionId, price, description, false);
        vm.stopPrank();

        vm.startPrank(USER);
        mp.purchaseProduct{value: price}(data);
        uint256 requestId = mp.requestRefund(data, "reason");
        vm.stopPrank();

        MarketPlace.RefundData memory refundData = MarketPlace.RefundData({
            seller: SELLER,
            buyer: USER,
            requestId: requestId,
            productId: productId,
            collectionId: collectionId,
            value: price
        });

        uint256 startingUserBalance = USER.balance;

        vm.expectEmit(false, false, false, true);
        emit RefundRejected(USER, requestId);

        vm.prank(ADMIN);
        mp.processRefund(refundData, false);

        MarketPlace.RefundRequest memory refund = mp.getUserRefundRequests(USER, requestId);

        assertFalse(refund.isApproved);

        (,,,,,, address productOwner) = mp.getProduct(SELLER, collectionId, productId);

        assertEq(productOwner, USER);

        uint256 endingUserBalance = USER.balance;

        assertEq(endingUserBalance, startingUserBalance);
    }

    function testProcessRefundFailsIfNoRequestsExist() public {
        uint256 requestId = 0;
        uint256 price = 0;
        uint256 collectionId = 1;
        uint256 productId = 1;

        MarketPlace.RefundData memory refundData = MarketPlace.RefundData({
            seller: SELLER,
            buyer: USER,
            requestId: requestId,
            productId: productId,
            collectionId: collectionId,
            value: price
        });

        vm.prank(owner);
        vm.expectRevert();
        mp.processRefund(refundData, false);
    }

    function testOwnerCanSetNewLoyalCostumerDiscountPercentage() public {
        uint256 prevPercentage = mp.getLoyalCostumerDiscountPercentage();

        uint256 _newPercentage = 12;

        vm.prank(owner);
        mp.setNewLoyalCostumerDiscountPercentage(_newPercentage);

        uint256 newPercentage = mp.getLoyalCostumerDiscountPercentage();

        assertLt(newPercentage, prevPercentage);
        assertEq(newPercentage, _newPercentage);
    }
}

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

    event PremiumSubscriptionPurchased(address user, uint256 fee);
    event ProductPurchased(address buyer, address seller, uint256 collectionId, uint256 productId, uint256 value);
    event BidPlaced(address bidder, address seller, uint256 collectionId, uint256 productId);
    event BidRefunded(address to, uint256 value);
    event RefundRequested(address by, address seller, uint256 collectionId, uint256 productId);
    event ReviewSubmitted(
        address reviewer, address seller, uint256 collectionId, uint256 productId, uint256 rating, string comment
    );
    event SupportTicketCreated(address by, uint256 time, uint256 ticketId);
    event SupportTicketClosed(uint256 ticketId);
    event NotificationSent(address from, address to);

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

        vm.startPrank(SELLER);
        mp.subscribeAsSeller{value: 0.01 ether}();
        mp.createCollection("name", "description");
        mp.createCategory("first category");
        mp.listProduct(collectionId, price, description, false);
        mp.createAuction(SELLER, collectionId, productId, startPrice, duration);
        vm.stopPrank();
    }

    function testUserCanPurchasePremiumSub() public {
        MarketPlace.PremiumSubscription memory details = mp.getPremiumUsersDetails(USER);
        assertEq(details.user, address(0));
        assertEq(details.startTimestamp, 0);
        assertEq(details.endTimestamp, 0);
        assertFalse(mp.isPremiumUser(USER));

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.MarketPlace__InvalidChargeAmount.selector, mp.getPremiumSubscriptionFee())
        );
        mp.purchasePremiumSubscription{value: 0.01 ether}();

        vm.expectEmit(false, false, false, true);
        emit PremiumSubscriptionPurchased(USER, mp.getPremiumSubscriptionFee());

        mp.purchasePremiumSubscription{value: mp.getPremiumSubscriptionFee()}();

        details = mp.getPremiumUsersDetails(USER);
        assertEq(details.user, USER);
        assertEq(details.startTimestamp, block.timestamp);
        assertEq(details.endTimestamp, block.timestamp + mp.getPremiumSubscriptionDeadline());
        assertTrue(mp.isPremiumUser(USER));
        vm.stopPrank();
    }

    function testPurchaseProductFailsIfProductSoldOut() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});
        vm.prank(SELLER);
        mp.markProductAsSoldOut(SELLER, collectionId, productId);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__ProductSoldOut.selector);
        mp.purchaseProduct{value: price}(purchase);
    }

    function testPurchaseProductFailsIfPriceDifferent() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(Errors.MarketPlace__ProductPriceIsDifferent.selector, price));
        mp.purchaseProduct{value: price - 1}(purchase);
    }

    function testUserCanPurchaseProduct() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        uint256 startingContractBalance = address(mp).balance;
        uint256 startingSellerBalance = SELLER.balance;
        uint256 startingUserBalance = USER.balance;

        vm.prank(USER);
        mp.purchaseProduct{value: price}(purchase);

        uint256 contractBalanceAfterUserPurchased = address(mp).balance;
        uint256 sellerBalanceAfterUserPurchased = SELLER.balance;
        uint256 endingUserBalance = USER.balance;

        assertEq(endingUserBalance, startingUserBalance - price);
        assertEq(sellerBalanceAfterUserPurchased, startingSellerBalance);
        assertEq(contractBalanceAfterUserPurchased, startingContractBalance + price);

        //
        //
        //
        //
    }

    function testUserCanpurchaseProductAndSellerCanWithdrawEarnings() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        mp.purchaseProduct{value: price}(purchase);

        uint256 startingContractBalance = address(mp).balance;
        uint256 startingSellerBalance = SELLER.balance;

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(SELLER);
        mp.withdrawEarnedAmount();

        (uint256 totalSold, uint256 totalRevenue,,) = mp.getProductStats(SELLER, collectionId, productId);

        uint256 expectedProductSales = 1;
        uint256 actualProductSales = mp.getProductSalesByProductId(productId);

        uint256 platformfee = mp.calculatePlatformFee(price);
        uint256 platformRevenue = mp.getPlatformRevenue();
        uint256 sellerEarn = mp.getSellerEarnings(SELLER);

        uint256 endingContractBalance = address(mp).balance;
        uint256 endingSellerBalance = SELLER.balance;

        assertEq(platformRevenue, platformfee);
        assertEq(endingContractBalance, startingContractBalance - price + platformRevenue);
        assertEq(endingSellerBalance, startingSellerBalance + sellerEarn);
        assertEq(totalRevenue, price);
        assertEq(actualProductSales, expectedProductSales);
        assertEq(totalSold, 1);
    }

    function testUserCanPurchaseProductAndTxWillBeSaved() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.expectEmit(false, false, false, true);
        emit ProductPurchased(USER, SELLER, collectionId, productId, price);

        vm.prank(USER);
        mp.purchaseProduct{value: price}(purchase);

        bool endingPurchasedStatus = mp.hasPurchasedProductId(SELLER, collectionId, productId, USER);

        address[] memory productBuyers = mp.getProductBuyers(SELLER, collectionId, productId);

        MarketPlace.Transaction[] memory txs = mp.getTransactionHistory(USER);

        uint256 expectedUserPoints = 10;
        uint256 actualUserPoints = mp.getLoyaltyPoints(USER);

        assertEq(productBuyers[0], USER);
        assertEq(txs[0].buyer, USER);
        assertEq(txs[0].seller, SELLER);
        assertEq(txs[0].collectionId, collectionId);
        assertEq(txs[0].productId, productId);
        assertEq(txs[0].value, price);
        assertEq(txs[0].timestamp, block.timestamp);
        assertTrue(endingPurchasedStatus);
        assertEq(actualUserPoints, expectedUserPoints);
    }

    function testPurchaseProductByPremiumUser() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, false);

        uint256 startingUserBalance = USER.balance;
        uint256 expectedPremiumDiscount = (price * 10) / 100;
        uint256 actualPremiumDiscount = mp.getPremiumUsersDiscount(price);

        vm.startPrank(USER);
        mp.purchasePremiumSubscription{value: mp.getPremiumSubscriptionFee()}();

        mp.purchaseProduct{value: price}(purchase);

        uint256 endingUserBalance = USER.balance;

        assertEq(actualPremiumDiscount, expectedPremiumDiscount);
        assertEq(endingUserBalance, startingUserBalance - (price + expectedPremiumDiscount));

        vm.stopPrank();
    }

    function testUserCanPlaceBid() public {
        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        MarketPlace.Auction[] memory auctions = mp.getActiveAuctions(SELLER, collectionId);

        assertEq(auctions[0].startPrice, startPrice);

        uint256 bidAmount = 2 ether;
        uint256 expectedPreviousUserPendingBidRefund = 0;
        uint256 actualPreviousUserPendingBidRefund = mp.getUserPendingBidRefund(USER);

        assertEq(actualPreviousUserPendingBidRefund, expectedPreviousUserPendingBidRefund);

        vm.expectEmit(false, false, false, true);
        emit BidPlaced(USER, SELLER, collectionId, productId);

        vm.prank(USER);
        mp.placeBid{value: bidAmount}(data);

        auctions = mp.getActiveAuctions(SELLER, collectionId);

        assertEq(auctions[0].highestBid, bidAmount);
        assertEq(auctions[0].highestBidder, USER);

        address USER_2 = address(0x123);
        vm.deal(USER_2, USER_BALANCE);
        uint256 user_2_bidAmount = 3 ether;
        vm.prank(USER_2);
        mp.placeBid{value: user_2_bidAmount}(data);

        uint256 expectedUserPendingBidRefund = bidAmount;
        uint256 actualUserPendingBidRefund = mp.getUserPendingBidRefund(USER);

        assertEq(actualUserPendingBidRefund, expectedUserPendingBidRefund);
    }

    function testPlaceBidFailsIfBidAmountIsLowerThanStartPrice() public {
        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        MarketPlace.Auction[] memory auctions = mp.getActiveAuctions(SELLER, collectionId);

        uint256 bidAmount = 0.5 ether;

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MarketPlace__CannotPlaceBidLowerThanStartPrice.selector, auctions[0].startPrice
            )
        );
        mp.placeBid{value: bidAmount}(data);
    }

    function testUserCannotPlaceBidOnAnAuctionWhichEnded() public {
        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__AuctionEnded.selector);
        mp.placeBid{value: startPrice + 1}(data);
    }

    function testUserCanWithdrawPendingBidRefund() public {
        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        mp.placeBid{value: startPrice + 1}(data);

        uint256 startingUserBalance = USER.balance;

        address USER_2 = address(0x123);
        vm.deal(USER_2, USER_BALANCE);
        uint256 user_2_bidAmount = 3 ether;
        vm.prank(USER_2);
        mp.placeBid{value: user_2_bidAmount}(data);

        uint256 pendingUserBidRefundBeforeWithdraw = mp.getUserPendingBidRefund(USER);

        vm.expectEmit(false, false, false, true);
        emit BidRefunded(USER, startPrice + 1);

        vm.prank(USER);
        mp.withdrawBidRefund();

        uint256 endingUserBalance = USER.balance;
        uint256 pendingUserBidRefundAfterWithdraw = mp.getUserPendingBidRefund(USER);

        assertEq(endingUserBalance, startingUserBalance + startPrice + 1);
        assertEq(pendingUserBidRefundBeforeWithdraw, startPrice + 1);
        assertEq(pendingUserBidRefundAfterWithdraw, 0);
    }

    function testWithdrawBidRefundFailsIfNoFundsAvailable() public {
        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__NoFundsToWithdraw.selector);
        mp.withdrawBidRefund();
    }

    function testUsersCanFinalizeAuctiosAndGetRewarded() public {
        MarketPlace.PurchaseData memory data =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        MarketPlace.Auction[] memory auctions = mp.getActiveAuctions(SELLER, collectionId);
        uint256 startTime = auctions[0].startTime;

        vm.prank(SELLER);
        mp.placeBid{value: startPrice + 1}(data);

        vm.warp(block.timestamp + startTime + duration + 1);

        uint256 startingUserBalance = USER.balance;

        vm.startPrank(USER);

        uint256 initialGas = gasleft();
        mp.finalizeAuction(data);
        uint256 gasUsed = initialGas - gasleft();
        uint256 gasCost = gasUsed * tx.gasprice;

        uint256 endingUserBalance = USER.balance;

        assertEq(endingUserBalance, startingUserBalance + gasCost);
        vm.stopPrank();
    }

    function testUserCanRequestRefund() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.startPrank(USER);
        mp.purchaseProduct{value: price}(purchase);

        vm.expectEmit(false, false, false, true);
        emit RefundRequested(USER, SELLER, collectionId, productId);

        uint256 requestId = mp.requestRefund(purchase, "reason");
        vm.stopPrank();

        uint256 expectedTotalRequests = 1;
        uint256 actualTotalRequests = mp.getTotalRefundRequests();

        assertEq(actualTotalRequests, expectedTotalRequests);

        MarketPlace.RefundRequest memory refundRequest = mp.getUserRefundRequests(USER, requestId);

        assertEq(refundRequest.requestId, requestId);
        assertEq(refundRequest.buyer, USER);
        assertEq(refundRequest.seller, SELLER);
        assertEq(refundRequest.collectionId, collectionId);
        assertEq(refundRequest.productId, productId);
        assertEq(refundRequest.reason, "reason");
        assertEq(refundRequest.timestamp, block.timestamp);
        assertFalse(refundRequest.isApproved);
    }

    function testRequestRefundFailsIfUserNotOwnerOfProduct() public {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__YouAreNotProductOwner.selector);
        mp.requestRefund(purchase, "reason");
    }

    modifier productPurchased() {
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        vm.prank(USER);
        mp.purchaseProduct{value: price}(purchase);
        _;
    }

    function testUserCanSubmitRewiew() public productPurchased {
        uint256 rating = 4;
        string memory comment = "comment";

        vm.expectEmit(false, false, false, true);
        emit ReviewSubmitted(USER, SELLER, collectionId, productId, rating, comment);

        vm.prank(USER);
        mp.submitReview(SELLER, collectionId, productId, rating, comment);

        MarketPlace.Review[] memory review = mp.getProductReviews(SELLER, collectionId, productId);

        assertEq(review[0].reviewer, USER);
        assertEq(review[0].rating, rating);
        assertEq(review[0].comment, comment);
        assertEq(review[0].timestamp, block.timestamp);
    }

    function testUserCannotReviewAProductIfDidnotBuy() public {
        uint256 rating = 4;
        string memory comment = "comment";

        vm.prank(USER);
        vm.expectRevert(Errors.MarketPlace__MustPurchaseTheProductFirst.selector);
        mp.submitReview(SELLER, collectionId, productId, rating, comment);
    }

    function testUsersCanOnlyRateFromOneToFive() public productPurchased {
        string memory comment = "comment";

        vm.startPrank(USER);
        vm.expectRevert(Errors.MarketPlace__RatingMustBeBetween_1_And_5.selector);
        mp.submitReview(SELLER, collectionId, productId, 0, comment);

        vm.expectRevert(Errors.MarketPlace__RatingMustBeBetween_1_And_5.selector);
        mp.submitReview(SELLER, collectionId, productId, 6, comment);
        vm.stopPrank();
    }

    function testUserCanCreateSupportTicket() public {
        string memory title = "title";
        string memory emailAddress = "emailAddress";

        vm.expectEmit(false, false, false, true);
        emit SupportTicketCreated(USER, block.timestamp, 1);

        vm.prank(USER);
        uint256 ticketId = mp.createSupportTicket(title, description, emailAddress);

        uint256 expectedTotalNumOfTickets = 1;
        uint256 actualTotalNumOfTickets = mp.getTotalNumberOfTickets();

        assertEq(actualTotalNumOfTickets, expectedTotalNumOfTickets);

        MarketPlace.SupportTicket[] memory tickets = mp.getUserTickets(USER);

        uint256 expectedTicketId = 1;

        assertEq(expectedTicketId, ticketId);
        assertEq(tickets[0].ticketId, ticketId);
        assertEq(tickets[0].user, USER);
        assertEq(tickets[0].title, title);
        assertEq(tickets[0].description, description);
        assertEq(tickets[0].emailAddress, emailAddress);
        assertEq(tickets[0].timestamp, block.timestamp);
        assertFalse(tickets[0].isClosed);

        MarketPlace.SupportTicket memory ticket = mp.getUserTicket(USER, ticketId);
        assertEq(ticket.ticketId, ticketId);
        assertEq(ticket.user, USER);
        assertEq(ticket.title, title);
        assertEq(ticket.description, description);
        assertEq(ticket.emailAddress, emailAddress);
        assertEq(ticket.timestamp, block.timestamp);
        assertFalse(ticket.isClosed);
    }

    function testUserCanCloseSupportTicket() public {
        string memory title = "title";
        string memory emailAddress = "emailAddress";

        vm.prank(USER);
        uint256 ticketId = mp.createSupportTicket(title, description, emailAddress);

        MarketPlace.SupportTicket memory ticket = mp.getUserTicket(USER, ticketId);
        assertFalse(ticket.isClosed);

        vm.expectEmit(false, false, false, true);
        emit SupportTicketClosed(ticketId);

        vm.prank(USER);
        mp.closeSupportTicket(ticketId);

        ticket = mp.getUserTicket(USER, ticketId);
        assertTrue(ticket.isClosed);
    }

    function testCloseTicketFailsIfConditionsNotMet() public {
        string memory title = "title";
        string memory emailAddress = "emailAddress";

        vm.prank(USER);
        uint256 ticketId = mp.createSupportTicket(title, description, emailAddress);

        vm.prank(ADMIN);
        vm.expectRevert(Errors.MarketPlace__TicketNotFound.selector);
        mp.closeSupportTicket(ticketId);
    }

    function testUsersCanSenNotifications() public {
        string memory message = "message";

        vm.expectEmit(false, false, false, true);
        emit NotificationSent(USER, ADMIN);
        vm.prank(USER);
        uint256 notificationId = mp.sendNotification(ADMIN, message);

        MarketPlace.Notification[] memory msag = mp.getUserNotifications(ADMIN);

        assertEq(notificationId, 1);
        assertEq(msag[0].sender, USER);
        assertEq(msag[0].receiver, ADMIN);
        assertEq(msag[0].notificationId, notificationId);
        assertEq(msag[0].message, message);
        assertEq(msag[0].timestamp, block.timestamp);
        assertEq(mp.getTotalSentNotifications(), 1);
    }

    function testPremiumUserCanPurchasePreoduct() public {
        vm.prank(SELLER);
        uint256 newProductId = mp.listProduct(collectionId, price, description, true);
        console.log(" id ", newProductId);

        vm.startPrank(USER);
        mp.purchasePremiumSubscription{value: mp.getPremiumSubscriptionFee()}();

        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: newProductId, couponId: 0});

        uint256 userBalanceBefore = USER.balance;
        console.log("userBalanceBefore", userBalanceBefore);

        mp.purchaseProduct{value: price}(purchase);
        vm.stopPrank();
        console.log("price", price);
        uint256 premiumUsersDiscountPercentage = mp.getPremiumDiscountUserPercentage();

        uint256 expectedDiscountAmount = (price * premiumUsersDiscountPercentage) / 100;
        uint256 actualDiscountAmount = mp.getPremiumUsersDiscount(price);

        uint256 userBalanceAfter = USER.balance;
        console.log("userBalanceAfter", userBalanceAfter);

        assertEq(actualDiscountAmount, expectedDiscountAmount);
        assertEq(userBalanceAfter, userBalanceBefore - price + actualDiscountAmount);
    }

    function testGetter() public view {
        uint256 expectedValue = 15;
        uint256 actualValue = mp.getLoyalCostumerDiscountPercentage();

        assertEq(actualValue, expectedValue);

        uint256 expectedSellerSubTime = block.timestamp + mp.getSellersSubEndTime();
        uint256 actualSellerSubTime = mp.getSellerTimestamp(SELLER);

        assertEq(actualSellerSubTime, expectedSellerSubTime);
    }

    function testGetTopRatedProductsAndTopSellingProducts() public {
        uint256 rating_1 = 3;
        uint256 rating_2 = 5;
        uint256 rating_3 = 5;
        string memory comment = "comment";

        vm.prank(SELLER);
        mp.listProduct(collectionId, price, description, false);

        vm.startPrank(USER);
        MarketPlace.PurchaseData memory purchase =
            MarketPlace.PurchaseData({seller: SELLER, collectionId: collectionId, productId: productId, couponId: 0});

        mp.purchaseProduct{value: price}(purchase);
        mp.purchaseProduct{value: price}(purchase);

        purchase = MarketPlace.PurchaseData({
            seller: SELLER,
            collectionId: collectionId,
            productId: productId + 1,
            couponId: 0
        });

        mp.purchaseProduct{value: price}(purchase);

        mp.submitReview(SELLER, collectionId, productId, rating_1, comment);
        mp.submitReview(SELLER, collectionId, productId, rating_3, comment);
        mp.submitReview(SELLER, collectionId, productId + 1, rating_2, comment);
        vm.stopPrank();

        MarketPlace.Product[] memory topRatedProduct = mp.getTopRatedProducts(SELLER);

        assertEq(topRatedProduct[0].productId, productId + 1);

        MarketPlace.Product[] memory topSellingProduct = mp.getTopSellingProducts(SELLER);

        assertEq(topSellingProduct[0].productId, productId);

        uint256 averageRating_1 = mp.getProductAverageRating(SELLER, collectionId, productId);
        uint256 averageRating_2 = mp.getProductAverageRating(SELLER, collectionId, productId + 1);

        assertEq(averageRating_1, 4);
        assertEq(averageRating_2, 5);
    }

    function testAdminGetters() public view {
        bytes32 expectedAdminRole = keccak256("ADMIN_ROLE");
        bytes32 actualAdminRole = mp.getAdminRole();

        assertEq(actualAdminRole, expectedAdminRole);

        address expectedOwner = address(this);
        address actualOwner = mp.getOwner();

        assertEq(actualOwner, expectedOwner);
    }
}

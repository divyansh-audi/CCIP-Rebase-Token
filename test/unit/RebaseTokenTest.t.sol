// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public OWNER = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    /**
     * @notice Deploying the contract for testing and adding reward to the vault of 1 eth ,which will ensure that if the user deposits in the vault ,then they can get the rebase award by this money which is in the vault added by the admin .So it is added to ensure that the protocol works fine .
     */
    function setUp() public {
        // vm.deal(USER, 10 ether);
        vm.deal(OWNER, 10 ether);
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function addRewardstoVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        if (!success) {
            revert();
        }
    }

    function testLinearInterest(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount + 1 ether);
        vault.deposit{value: amount}();

        uint256 firstBalance = rebaseToken.balanceOf(user);
        console.log("first balance", firstBalance);
        assert(firstBalance == amount);
        vm.warp(block.timestamp + 100);
        uint256 secondBalance = rebaseToken.balanceOf(user);
        console.log("second balance", secondBalance);
        vm.warp(block.timestamp + 100);
        uint256 thirdBalance = rebaseToken.balanceOf(user);
        console.log("third time", thirdBalance);
        console.log("dif 1:", secondBalance - firstBalance);
        console.log("dif 2:", thirdBalance - secondBalance);
        vm.stopPrank();
        assertApproxEqAbs(secondBalance - firstBalance, thirdBalance - secondBalance, 1);
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        console.log("USER BALANCE IN VAULT:", rebaseToken.balanceOf(address(user)));
        console.log("AMOUNT:", amount);
        console.log("AMOUNT IN USERS POCKET:", user.balance);

        vault.redeem(type(uint256).max);
        console.log("AMOUNT IN USER POCCKET AFTER REDEEMING:", user.balance);
        console.log("AMOUNT IN VAULT ASSOCIATED WITH USER :", rebaseToken.balanceOf(user));
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(user.balance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterSomeTime(uint256 amount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(user.balance, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        assertEq(user.balance, 0);

        vm.warp(block.timestamp + time);
        uint256 amountTotal = rebaseToken.balanceOf(user);
        vm.deal(OWNER, amountTotal - amount + 1 ether);
        vm.prank(OWNER);
        addRewardstoVault(amountTotal - amount + 1 ether);
        console.log("TOTAL Amount:", amountTotal);
        console.log("Amount:", amount);
        vm.prank(user);
        vault.redeem(type(uint256).max);

        assertEq(amountTotal, user.balance);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // deposit some amount
        vm.deal(user, amount);

        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 interestRateForUser = rebaseToken.getUserInterestRate(user);
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        vm.prank(OWNER);
        rebaseToken.setInterestRate(4e10);

        assertGt(userBalance, user2Balance);
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 interestRateForUser2 = rebaseToken.getUserInterestRate(user2);

        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfter = rebaseToken.balanceOf(user2);
        assertEq(interestRateForUser, interestRateForUser2);
        assertEq(user2BalanceAfter + userBalanceAfter, userBalance + user2Balance);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        // Update the interest rate
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }

    function testCannotCallMintAndBurn(uint256 amount) public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.mint(user2, amount, rebaseToken.getInterestRate());
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.burn(user2, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);

        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 100000);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public {
        vm.prank(user);
        address expectedAddress = vault.getRebaseTokenAddress();
        address realAddress = address(rebaseToken);
        assertEq(expectedAddress, realAddress);
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, rebaseToken.getInterestRate(), type(uint96).max);
        vm.startPrank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
                rebaseToken.getInterestRate(),
                newInterestRate
            )
        );
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }

    function testTransferFromFunction(uint256 amount, uint256 amountToTransfer) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1e5, amount - 1e5);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        vm.prank(user);
        rebaseToken.approve(user, amount);

        assertEq(rebaseToken.balanceOf(user2), 0);
        assertEq(rebaseToken.balanceOf(user), amount);
        vm.prank(user);
        rebaseToken.transferFrom(user, user2, amountToTransfer);

        assertEq(rebaseToken.balanceOf(user2), amountToTransfer);
        assertEq(rebaseToken.balanceOf(user), amount - amountToTransfer);

        address user3 = makeAddr("user3");
        vm.deal(user3, amount);
        vm.warp(block.timestamp + 100000);
        vm.prank(user3);
        vault.deposit{value: amount}();
        uint256 interestUser3 = rebaseToken.getUserInterestRate(user3);
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getUserInterestRate(user2));
        assertEq(rebaseToken.getUserInterestRate(user), interestUser3);

        vm.prank(user3);
        rebaseToken.approve(user3, amount);

        vm.prank(user3);
        rebaseToken.transferFrom(user3, user2, amountToTransfer);

        assertGt(rebaseToken.balanceOf(user2), 2 * amountToTransfer);
    }
}

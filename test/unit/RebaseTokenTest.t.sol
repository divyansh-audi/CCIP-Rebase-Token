// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");

    /**
     * @notice Deploying the contract for testing and adding reward to the vault of 1 eth ,which will ensure that if the user deposits in the vault ,then they can get the rebase award by this money which is in the vault added by the admin .So it is added to ensure that the protocol works fine .
     */
    function setUp() public {
        vm.deal(USER, 10 ether);
        vm.deal(OWNER, 10 ether);
        vm.startPrank(OWNER);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        if (!success) {
            revert();
        }
        vm.stopPrank();
    }

    function testLinearInterest() public {
        vm.startPrank(USER);
        vault.deposit{value: 0.5 ether}();
        uint256 firstTimeCheck = block.timestamp;
        uint256 firstBalance = rebaseToken.balanceOf(USER);
        vm.warp(firstTimeCheck + 100);
        uint256 secondBalance = rebaseToken.balanceOf(USER);
        vm.warp(firstTimeCheck + 200);
        uint256 thirdBalance = rebaseToken.balanceOf(USER);
        vm.stopPrank();
        assert(secondBalance - firstBalance == thirdBalance - secondBalance);
    }

    function fuzzTestingForLinearInterest(uint256 amountToDeposit) public {}
}

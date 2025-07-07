// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__RedeemFailed();
    //We need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of ETH the user sends
    // create a redeem function that burns token from the user and sends the user ETH
    // create a functiom that allows the owner to set the interest rate
    // create a way to add reward to the vault

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed sender, uint256 indexed amountToMint);
    event Redeem(address indexed sender, uint256 indexed amountToBurn);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows user to deposit and mint Rebase token
     */
    function deposit() external payable {
        // 1. We need to use the amount of eth the user has sent to mint tokens to the user.
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase token for ETH.
     * @param _amount The amount of rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        i_rebaseToken.burn(msg.sender, _amount);
        // payable(msg.sender).transfer(_amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the Rebase token address
     * @return The Rebase Token Address
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}

// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Divyansh Audichya
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /**
     * @notice suppose you wanna write 50% interest ,it means 0.5 in decimals ,which means 5e17 in solidity.
     * So this is like that only.
     */
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    // we should make the interst rate such that it is in terms of precision factor ,so if we change precision factor ,interest rate also get automatically adjusted

    // Interest rate is 5*10-8 persecond and this is constant--->5*10^-8=s_interestRate/PRECISION_FACTOR
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InteresrRateSet(uint256 indexed newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new Interest Rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        //Set the interest rate
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InteresrRateSet(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of the user.This is the number of tokens that have currently been minted to the user,not including any interest that have been accrued since the last time the user interacted with the protocol.
     * @param _user user to see the principle balance
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user token when they withdraw from the vault
     * @param _from The user to burn their tokens from
     * @param _amount the amount of token to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * Calculate the balance for the user including the interest that has accumulated since the last uppdate
     * (principal balance)+ some interest that has accrued
     * @param _user the user to calculate the balance for
     */
    function balanceOf(address _user) public view override returns (uint256) {
        //get the current principal balance of the user
        //multiple the principal balance by the interest rate that has accumulated in the time since the balance has last updated

        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient recipient to transfer takens to
     * @param _amount amount of token to transfer
     * @return True if the transfer was successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer token from one user to another
     * @param _sender The user to transfer the tokens from
     * @param _recipient the user to transfer the token to
     * @param _amount the amount of token to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest accumulateed for
     * @return The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1.calculate time since the lasst update
        // 2.calculate the amount of linear growth
        //(principal amount)+(principal amount)*(interest rate)*(time elasped)=principal amount*(1+interestRate*timeElapsed)
        // deposit 10 tokens
        // interest rate 0.5 tokens per seconds
        // time elapsed 2 seconds
        // 10 +(10*0.5*2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        uint256 linearInterest = PRECISION_FACTOR + (timeElapsed * s_userInterestRate[_user]);
        return linearInterest;
    }

    /**
     * @notice Mint hte accrued interst to the user since the last time they interacted with the protocol (eg burn,mint ,transfer)
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        //(1)find their currect balance of rebase token -->principal balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        //(2)calculate their current balance including any interest.--> this will be returned from balanceOf
        uint256 currentBalance = balanceOf(_user);
        //(3)calculate the number of token that need to be minted to the user
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        //set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        //call _mint to mint the token to the user
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Get the interest rate for the user
     * @param userAddress user to get the interest rate for
     * @return The interestrate for the user
     */
    function getUserInterestRate(address userAddress) external view returns (uint256) {
        return s_userInterestRate[userAddress];
    }

    /**
     * @notice Get the interest rate that is currently set for the contract .Any future depositors will recieve this interest rate
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}

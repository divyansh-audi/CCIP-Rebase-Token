// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outBoundRateLimiterIsEnabled,
        uint128 outBoundRateLimitCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterIsEnabled,
        uint128 inBoundRateLimitCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        RateLimiter.Config memory outboundRateLimiterConfig =
            RateLimiter.Config(outBoundRateLimiterIsEnabled, outBoundRateLimitCapacity, outBoundRateLimiterRate);
        RateLimiter.Config memory inboundRateLimiterConfig =
            RateLimiter.Config(inBoundRateLimiterIsEnabled, inBoundRateLimitCapacity, inBoundRateLimiterRate);
        remotePoolAddresses[0] = abi.encode(remotePool);
        chainToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: outboundRateLimiterConfig,
            inboundRateLimiterConfig: inboundRateLimiterConfig
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainToAdd);
        vm.stopBroadcast();
    }
}

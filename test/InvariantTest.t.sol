// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {Handler} from "./handlers/Handler.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract InvariantTest is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    StableCoinRewardsVault public vault;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    Handler public handler;
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

    function setUp() public {
        address OWNER = address(0x00001234);
        vm.startPrank(OWNER);
        vm.warp(104 days + 1);

        asset = new ERC20Mock();
        stableCoinRewardsVault = new StableCoinRewardsVault();

        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;
        address targetAddr = address(
            0x7AC8519283B1bba6d683FF555A12318Ec9265229
        );
        vm.etch(targetAddr, bytecode);
        rewardToken = ERC20Mock(targetAddr);

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stableCoinRewardsVault),
            abi.encodeCall(
                stableCoinRewardsVault.initialize,
                (
                    IERC20(address(asset)),
                    "Vault Name",
                    "SYMBOL",
                    minAmount,
                    maxAmount
                )
            )
        );
        vault = StableCoinRewardsVault(address(proxy));
        vault.startEpoch();
        vm.stopPrank();

        // 4) Deploy the handler using contract references (no address(...) cast)
        handler = new Handler(vault, asset, rewardToken);

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        selectors[2] = Handler.claimRewards.selector;
        selectors[3] = Handler.addRewards.selector;
        selectors[4] = Handler.warpTime.selector;
        selectors[5] = Handler.donateAsset.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );

        targetContract(address(handler));
        
    }

    function invariant_TotalDepositsMatchVault() public view {

        uint256 deposits = handler.ghost_depositSum();
        uint256 donates = handler.ghost_donateSum();
        uint256 withdraws = handler.ghost_withdrawSum();

        uint256 netDeposited = deposits + donates - withdraws;
        assertEq(
            vault.totalAssets(),
            netDeposited,
            "Vault total assets mismatch"
        );
    }

    function invariant_RewardsLogic() public view{
        uint256 totalRewardsAdded = handler.ghost_rewardsAdded();
        uint256 totalRewardsClaimed = handler.ghost_rewardsClaimed();
        uint256 totalUnclaimedRewards = rewardToken.balanceOf(address(vault));
        assertEq(
            totalRewardsAdded,
            totalUnclaimedRewards + totalRewardsClaimed,
            "Rewards added mismatch"
        );
        
    }

    function Invariant_FinalizeAndCheck() public {
        finalizeAndCheck();
    }

    // invariant to check if claimed rewards are calculated correctly

    function finalizeAndCheck() public {

    address[] memory allActors = handler.actors();
    uint256 endtime = vault.startTime() + 100 days;
    vm.warp(endtime);
    for (uint256 i = 0; i < allActors.length; i++) {
        address user = allActors[i];
        
        // Optionally claim any outstanding rewards:
        // If you have a “claimRewards(user)” method:
        try vault.claimRewards(user) {
            // If it reverts, skip or handle
        } catch {}

        // Then withdraw all shares:
        uint256 userShares = vault.balanceOf(user);
        if (userShares > 0) {
            try vault.withdraw(userShares, user, user) {
                // If it reverts, skip or handle
            } catch {}
        }
    }

    // 3) Check if the vault is empty
    //uint256 vaultAssetBalance = asset.balanceOf(address(vault));
    //assertEq(vaultAssetBalance, 0, "Vault still has leftover assets");

    uint256 vaultRewardBalance = rewardToken.balanceOf(address(vault));
    vm.assertApproxEqAbs(vaultRewardBalance, 0, 5, "Vault still has leftover rewards");

}

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}

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
    StableCoinRewardsVault public vault;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    Handler public handler;
    address public vaultAdmin = address(0x0001);
    address public vaultManager = address(0x0002);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02
    uint256 maxPoolSize = 100000000000000000000000000; // 2_000_000 of tokens @ 0.02

    function setUp() public {

        vm.warp(104 days + 1);

        //setup mock tokens
        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;

        //USDT token
        address rewardTokenAddr = address(0x7AC8519283B1bba6d683FF555A12318Ec9265229);
        vm.etch(rewardTokenAddr, bytecode);
        rewardToken = ERC20Mock(rewardTokenAddr);

        //NEXD token
        address assetTargetAddr = address(0x3858567501fbf030BD859EE831610fCc710319f4);
        vm.etch(assetTargetAddr, bytecode);
        asset = ERC20Mock(assetTargetAddr);

        vault = new StableCoinRewardsVault(
            asset,
            "NEXD Rewards Vault",
            "sNEXD",
            vaultAdmin,
            vaultManager,
            minAmount,
            maxAmount,
            maxPoolSize
        );
       
        vm.prank(vaultManager);
        vault.startEpoch();


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

    function invariant_TotalDepositsMatchVault() public {

        uint256 deposits = handler.ghost_depositSum();
        uint256 donates = handler.ghost_donateSum();
        uint256 withdraws = handler.ghost_withdrawSum();

        uint256 tolerance = deposits / 1e10;
        console.log("tolerance: ", tolerance);
        console.log("Deposits: ", deposits);

        uint256 netDeposited = deposits + donates - withdraws;
        assertApproxEqAbs(
            vault.totalAssets(),
            netDeposited,
            tolerance, 
            "Vault total assets mismatch"
        );
    }

    function invariant_RewardsLogic() public {
        uint256 totalRewardsAdded = handler.ghost_rewardsAdded();
        uint256 totalRewardsClaimed = handler.ghost_rewardsClaimed();
        uint256 totalUnclaimedRewards = rewardToken.balanceOf(address(vault));
        assertApproxEqAbs(
            totalRewardsAdded,
            totalUnclaimedRewards + totalRewardsClaimed,
            1e9,
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
    assertApproxEqAbs(vaultRewardBalance, 0, 1e9, "Vault still has leftover rewards");

}

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}

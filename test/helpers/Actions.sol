pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StableCoinRewardsVault} from "../../src/StableCoinRewardsVault.sol";



contract Actions is Test {

    uint256 public constant MIN_AMOUNT = 5000000000000000000000; // $100 of tokens @ 0.02 - 18 decimals
    uint256 public constant MAX_AMOUNT= 5000000000000000000000000; // 100_000 of tokens @ 0.02 - 18 decimals
    uint256 public constant MIN_REWARD = 100000000; //  100  - 6 decimals
    uint256 public constant MAX_REWARD = 1000000000000000000; // 1 trillon - 6 decimals

    function boundedDeposit(
        address user,
        ERC20Mock asset,
        StableCoinRewardsVault vault,
        uint256 rawAmount
    ) public returns (uint256) {
        uint256 amt = bound(rawAmount, MIN_AMOUNT, MAX_AMOUNT);
        asset.mint(user, amt);
        vm.startPrank(user);
        asset.approve(address(vault), amt);
        vault.deposit(amt, user);
        vm.stopPrank();
        return amt;
    }

    function simpleDeposit(address user, ERC20Mock asset,  StableCoinRewardsVault vault, uint256 amount, bool expectRevert) public returns (uint256) {
        asset.mint(user, amount);
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        if (expectRevert) {
            vm.expectRevert();
            vault.deposit(amount, user);
        } else {
            vault.deposit(amount, user);
        }
        vm.stopPrank();
        return amount;
    }

    function simpleMint(address user, ERC20Mock asset,  StableCoinRewardsVault vault, uint256 amount, bool expectRevert) public returns (uint256) {
        asset.mint(user, amount);
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        uint256 shares = vault.convertToShares(amount);
        if (expectRevert) {
            vm.expectRevert();
            vault.mint(shares, user);
        } else {
            vault.mint(shares, user);
        }
        vm.stopPrank();
        return shares;
    }

    function simpleWithdraw(address user, StableCoinRewardsVault vault, uint256 amount, bool expectRevert) public returns (uint256) {
        vm.startPrank(user);
        if (expectRevert) {
            vm.expectRevert();
            vault.withdraw(amount, user, user);
        } else {
            vault.withdraw(amount, user, user);
        }
        vm.stopPrank();
        return amount;
    }

    function simpleRedeem(address user, StableCoinRewardsVault vault, uint256 amount, bool expectRevert) public returns (uint256) {
        vm.startPrank(user);
        if (expectRevert) {
            vm.expectRevert();
            vault.redeem(amount, user, user);
        } else {
            vault.redeem(amount, user, user);
        }
        vm.stopPrank();
        return amount;
    }

    function simpleClaimRewards(address user, StableCoinRewardsVault vault, bool expectRevert) public {
        vm.startPrank(user);
        if (expectRevert) {
            vm.expectRevert();
            vault.claimRewards(user);
        } else {
            vault.claimRewards(user);
        }
        vm.stopPrank();
    }


    function boundedWithdraw(
        address user,
        StableCoinRewardsVault vault,
        uint256 rawAmount
    ) public returns (uint256) {
        vm.startPrank(user);
        vault.withdraw(rawAmount, user, user);
        vm.stopPrank();
        return rawAmount;
    }

    function boundedReward(
        address user,
        ERC20Mock rewardToken,
        StableCoinRewardsVault vault,
        uint256 rawAmount
    ) public returns (uint256) {
        uint256 amt = bound(rawAmount, MIN_REWARD, MAX_REWARD);
        rewardToken.mint(user, amt);
        vm.startPrank(user);
        rewardToken.approve(address(vault), amt);
        vault.addRewards(amt);
        vm.stopPrank();
        return amt;
    }

     function executeDepositWithdrawal(
        address user,
        ERC20Mock asset,
        StableCoinRewardsVault vault,
        uint256 warpTime,
        bool expectRevert,
        string memory description,
        uint256 rawAmount
    ) public {
        uint256 deposit;
        console.log(description);
        vm.warp(vault.startTime() + warpTime);
        if (expectRevert) {
            uint256 amt = bound(rawAmount, MIN_AMOUNT, MAX_AMOUNT);
            asset.mint(user, amt);
            vm.startPrank(user);
            asset.approve(address(vault), amt);
            vm.expectRevert();
            vault.deposit(amt, user);
            vm.expectRevert();
            vault.withdraw(amt, user, user);
            vm.stopPrank();
        } else {
            deposit = boundedDeposit(user, asset, vault, rawAmount);
            boundedWithdraw(user, vault, deposit);
        }
    }

   function executeAddRewards(
        address user,
        ERC20Mock asset,
        ERC20Mock rewardToken,
        StableCoinRewardsVault vault,
        uint256 warpTime,
        bool expectRevert,
        string memory description,
        uint256 rawAmount
    ) public {
        console.log(description);
        vm.warp(vault.startTime() + warpTime);
        if (expectRevert) {
            vm.startPrank(user);
            uint256 amt = bound(rawAmount, MIN_AMOUNT, MAX_AMOUNT);
            rewardToken.mint(user, amt);
            asset.mint(user, amt);
            asset.approve(address(vault), amt);
            vault.deposit(amt, user);

            rewardToken.approve(address(vault), amt);
            vm.expectRevert();
            vault.addRewards(amt);         
            vm.stopPrank();
        } else {
            boundedReward(user, rewardToken, vault, rawAmount);
        }
    }



    function startEpoch(address owner, StableCoinRewardsVault vault) public {
        vm.startPrank(owner);
        vault.startEpoch();
        vm.stopPrank();
    }

    function claimAndExpectRevert(address user, StableCoinRewardsVault vault) public {
        vm.expectRevert();
        vault.claimRewards(user);
    }
}
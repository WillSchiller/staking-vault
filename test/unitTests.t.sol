// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Actions} from "./helpers/Actions.sol";

contract stableCoinRewardsVaultTest is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    StableCoinRewardsVault public stableCoinRewardsVaultProxy;
    Actions public actions;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public tester = address(0x0001);
    address public owner = address(0x0002);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

    address staker1 = address(0x1234);
    address staker2 = address(0x5678);
    address staker3 = address(0x9abc);

    function setUp() public {
        actions = new Actions();
        vm.startPrank(owner);
        vm.warp(104 days + 1);
        //setup mock token
        asset = new ERC20Mock();

        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;
        address targetAddr = address(0x7AC8519283B1bba6d683FF555A12318Ec9265229);
        vm.etch(targetAddr, bytecode);
        rewardToken = ERC20Mock(targetAddr);

        //deploy implementation contract
        stableCoinRewardsVault = new StableCoinRewardsVault();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stableCoinRewardsVault),
            abi.encodeCall(
                stableCoinRewardsVault.initialize,
                (IERC20(address(asset)), "Vault Name", "SYMBOL", minAmount, maxAmount)
            )
        );
        stableCoinRewardsVaultProxy = StableCoinRewardsVault(address(proxy));
        stableCoinRewardsVaultProxy.startEpoch();
        vm.stopPrank();
    }

    function testIsOpen(uint256 rawAmount) public {
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 1 days, false, "Testing isOpen at 1 day",rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 7 days + 1, true, "Testing isOpen at 7 days + 1 second: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 30 days + 1, true, "Testing isOpen at 30 days + 1 second: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 97 days, false, "Testing isOpen at 97 days", rawAmount);
    }

    function testIsLocked(uint256 rawAmount) public {
        actions.executeAddRewards(owner, asset, rewardToken, stableCoinRewardsVaultProxy, 1 days, true, "Testing isOpen at 1 day", rawAmount);
        actions.executeAddRewards(owner, asset, rewardToken, stableCoinRewardsVaultProxy, 7 days + 1, false, "Testing isOpen at 7 days + 1 second", rawAmount);
        actions.executeAddRewards(owner, asset, rewardToken, stableCoinRewardsVaultProxy, 30 days + 1, false, "Testing isOpen at 30 days + 1 second", rawAmount);
        actions.executeAddRewards(owner, asset, rewardToken, stableCoinRewardsVaultProxy, 97 days + 1, true, "Testing isOpen at 97 days", rawAmount);
    }

    function testIsMinAmount() public {}
    function testUpdateReward() public {}
    function testInitialize() public {}
    function testClaimRewards() public {}
    function testEarned() public {}
    function testAddRewards() public {}

    function testSimpleRewardsDistribution(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {
        
        uint256 amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        uint256 amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        uint256 amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);
        uint256 totalDeposits = amount1 + amount2 + amount3;
        
        //move to lock period and add rewards
        vm.warp(block.timestamp + 7 days);

        uint256 rewards = actions.boundedReward(owner, rewardToken, stableCoinRewardsVaultProxy, rewards);
        uint256 rewardsPerShare = (rewards * 1e27) / totalDeposits;
        
        uint256 expectedRewards1 = (amount1 * rewardsPerShare) / 1e27;
        if (expectedRewards1 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker1);
            vm.assertEq(rewardToken.balanceOf(staker1), expectedRewards1);
        }

        uint256 expectedRewards2 = (amount2 * rewardsPerShare) / 1e27;
        if (expectedRewards2 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker2);
            vm.assertEq(rewardToken.balanceOf(staker2), expectedRewards2);
        }

        uint256 rewards3 = stableCoinRewardsVaultProxy.earned(staker3);
        uint256 expectedRewards3 = (amount3 * rewardsPerShare) / 1e27;
        if (expectedRewards3 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker3);
            vm.assertEq(rewardToken.balanceOf(staker3), expectedRewards3);
        }
        vm.assertApproxEqAbs(
            rewardToken.balanceOf(address(stableCoinRewardsVaultProxy)) / 1e27, 0, 5, "Rewards not fully distributed"
        );
    }

    // Test mechamism that updates unclaimed rewards when user does multiple deposits and withdrawals
    function testUnclainedRewards(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {

        uint256 amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        uint256 amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        uint256 amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        uint256 totalDeposits = amount1 + amount2 + amount3;

        vm.warp(block.timestamp + 8 days);  

        uint256 rewards = actions.boundedReward(owner, rewardToken, stableCoinRewardsVaultProxy, rewards);
        
        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(owner, stableCoinRewardsVaultProxy);  

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        vm.warp(block.timestamp + 8 days);

        rewards += actions.boundedReward(owner, rewardToken, stableCoinRewardsVaultProxy, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(owner, stableCoinRewardsVaultProxy);  

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(owner, rewardToken, stableCoinRewardsVaultProxy, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(owner, stableCoinRewardsVaultProxy); 

        // Test unclaimed rewards with various amount remaining (75%, 66%, 0%)
        amount1 -= actions.boundedWithdraw(staker1, stableCoinRewardsVaultProxy, (amount1 / 4)); 
        amount2 -= actions.boundedWithdraw(staker2, stableCoinRewardsVaultProxy, (amount2 / 3));
        amount3 -= actions.boundedWithdraw(staker3, stableCoinRewardsVaultProxy, (amount3 / 1));

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(owner, rewardToken, stableCoinRewardsVaultProxy, rewards);
      
        vm.warp(block.timestamp + 98 days);

        stableCoinRewardsVaultProxy.claimRewards(staker1);
        stableCoinRewardsVaultProxy.claimRewards(staker2);
        stableCoinRewardsVaultProxy.claimRewards(staker3);
        uint256 claimed = rewardToken.balanceOf(staker1);
        claimed += rewardToken.balanceOf(staker2);
        claimed += rewardToken.balanceOf(staker3);

        // All rewards should be claimed and contract balance should be 0
        vm.assertApproxEqAbs((claimed / 1e6), (rewards / 1e6), 5);
        vm.assertApproxEqAbs((rewardToken.balanceOf(address(stableCoinRewardsVaultProxy)) / 1e6), 0, 5);
    }

}

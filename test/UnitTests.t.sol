// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Actions} from "./helpers/Actions.sol";

contract UnitTests is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    Actions public actions;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public contractAdmin = address(0x0001);
    address public epochManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02
    uint256 maxPoolSize = 100000000000000000000000000; // 2_000_000 of tokens @ 0.02

    address staker1 = address(0x1234);
    address staker2 = address(0x5678);
    address staker3 = address(0x9abc);

    error NoClaimableRewards();

    function setUp() public {
        // helper actions
        actions = new Actions();

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

        //deploy implementation contract
        stableCoinRewardsVault = new StableCoinRewardsVault(
            asset,
            "NEXD Rewards Vault",
            "sNEXD",
            contractAdmin,
            epochManager,
            rewardsManager,
            minAmount,
            maxAmount,
            maxPoolSize
        );

        // deploy proxy
       

        vm.prank(epochManager);
        stableCoinRewardsVault.startEpoch();
    }

    function testIsOpen(uint256 rawAmount) public {
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVault, 0 days, false, "Testing isOpen at 0 day",rawAmount);
        actions.executeDepositWithdrawal(staker2, asset, stableCoinRewardsVault, 1 days, false, "Testing isOpen at 1 day",rawAmount);
        // Testing overlaps if isOpen revert is true at 7 days islocked should be false: see line 84
        actions.executeDepositWithdrawal(staker3, asset, stableCoinRewardsVault, 7 days, true, "Testing isOpen at 7 days", rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVault, 7 days + 1, true, "Testing isOpen at 7 days + 1 second: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker2, asset, stableCoinRewardsVault, 30 days, true, "Testing isOpen at 30 days: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker3, asset, stableCoinRewardsVault, 30 days + 1, true, "Testing isOpen at 30 days + 1 second: expect revert", rawAmount);
        // Testing overlaps if isOpen revert is true at 97 days islocked should be false
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVault, 97 days, false, "Testing isOpen at 97 days", rawAmount);
        actions.executeDepositWithdrawal(staker2, asset, stableCoinRewardsVault, 97 days, false, "Testing isOpen at 97 days", rawAmount);
    }

    function testIsLocked(uint256 rawAmount) public {
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 0 days, true, "Testing isOpen at 0 day", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 1 days, true, "Testing isOpen at 1 day", rawAmount);
        // Testing overlaps if isOpen revert is true at 7 days islocked should be false
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 7 days, false, "Testing isOpen at 1 day: expect revert", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 7 days + 1, false, "Testing isOpen at 7 days + 1 second: expect revert", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 30 days + 1, false, "Testing isOpen at 30 days + 1 second: expect revert", rawAmount);
        // Testing overlaps if isOpen revert is true at 97 days islocked should be false
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 97 days, true, "Testing isOpen at 97 days", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 97 days + 1, true, "Testing isOpen at 97 days", rawAmount);
    }


    function testIsMinAmount() public {
        uint256 _minAmount = stableCoinRewardsVault.minAmount();
        actions.simpleMint(staker1, asset, stableCoinRewardsVault, (_minAmount -1), true);
        actions.simpleMint(staker2, asset, stableCoinRewardsVault, _minAmount, false);
        actions.simpleMint(staker3, asset, stableCoinRewardsVault, (_minAmount + 1), false);

        actions.simpleDeposit(staker1, asset, stableCoinRewardsVault, (_minAmount -1), true);
        actions.simpleDeposit(staker2, asset, stableCoinRewardsVault, _minAmount, false);
        actions.simpleDeposit(staker3, asset, stableCoinRewardsVault, (_minAmount + 1), false);
    }

    function testMaxAmount() public {
        uint256 _maxAmount = stableCoinRewardsVault.maxAmount();
        actions.simpleMint(staker1, asset, stableCoinRewardsVault, (_maxAmount + 1), true);
        actions.simpleMint(staker2, asset, stableCoinRewardsVault, _maxAmount, false);
        actions.simpleMint(staker3, asset, stableCoinRewardsVault, (_maxAmount - 1), false);

        actions.simpleDeposit(staker1, asset, stableCoinRewardsVault, (_maxAmount + 1), true);
        actions.simpleDeposit(staker2, asset, stableCoinRewardsVault, _maxAmount, false);
        actions.simpleDeposit(staker3, asset, stableCoinRewardsVault, (_maxAmount - 1), false);
    }

    function testConvertToShareWhenSupplyIsZero() public {
        uint256 supply = stableCoinRewardsVault.totalSupply();
        uint256 shares = stableCoinRewardsVault.convertToShares(5000000000000000000000);
        actions.simpleMint(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, false);
        assertEq(supply, 0);
        assertEq(shares, 5000000000000000000000);
    }
    /*
    function testOnlyAdminCanPause() public {
        vm.expectRevert();
        stableCoinRewardsVault.pause();
        vm.startPrank(contractAdmin);
        stableCoinRewardsVault.pause();
        stableCoinRewardsVault.unpause();
        vm.stopPrank();
    }

    function testPausableFunctions() public {
        // deposit
        actions.simpleDeposit(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, false);
        // pause and try to use contract
        vm.prank(contractAdmin);
        stableCoinRewardsVault.pause();
        actions.simpleDeposit(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, true);
        actions.simpleMint(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, true);
        actions.simpleWithdraw(staker1, stableCoinRewardsVault, 5000000000000000000000, true);
        actions.simpleRedeem(staker1, stableCoinRewardsVault, 5000000000000000000000, true);
        actions.simpleClaimRewards(staker1, stableCoinRewardsVault, true);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVault, 8 days, false, "Will not revert even if paused", 5000000000000000000000);

        // unpause and try to use contract
        vm.prank(contractAdmin);
        stableCoinRewardsVault.unpause();
        vm.warp(block.timestamp + 90 days);
        actions.simpleDeposit(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, false);
        actions.simpleMint(staker1, asset, stableCoinRewardsVault, 5000000000000000000000, false);
        actions.simpleWithdraw(staker1, stableCoinRewardsVault, 5000000000000000000000, false);
        actions.simpleRedeem(staker1, stableCoinRewardsVault, 5000000000000000000000, false);
        actions.simpleClaimRewards(staker1, stableCoinRewardsVault, false);

    }
    */
    function testUpdateReward() public {}
    function testInitialize() public {}
    function testClaimRewards() public {}
    function testEarned() public {}
    function testAddRewards() public {}

    function testSimpleRewardsDistribution(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {
        //deposit        
        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVault, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVault, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVault, amount3);
        uint256 totalDeposits = amount1 + amount2 + amount3;
        
        //move to lock period and add rewards
        vm.warp(block.timestamp + 7 days+ 1);
        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);

        // rewards should == 0 until epoch finishe
        actions.claimAndExpectRevert(staker1, stableCoinRewardsVault);
        actions.claimAndExpectRevert(staker2, stableCoinRewardsVault);
        actions.claimAndExpectRevert(staker3, stableCoinRewardsVault);
        
        vm.warp(block.timestamp + 98 days);
        
        // check rewards
        uint256 rewardsPerShare = (rewards * 1e18) / totalDeposits;
        
        uint256 expectedRewards1 = (amount1 * rewardsPerShare) / 1e18;
        stableCoinRewardsVault.claimRewards(staker1);
        assertApproxEqAbs(rewardToken.balanceOf(staker1), expectedRewards1, 10000000);
        

        uint256 expectedRewards2 = (amount2 * rewardsPerShare) / 1e18;
        stableCoinRewardsVault.claimRewards(staker2);
        assertEq(rewardToken.balanceOf(staker2), expectedRewards2);
        
        uint256 expectedRewards3 = (amount3 * rewardsPerShare) / 1e18;
        stableCoinRewardsVault.claimRewards(staker3);
        assertEq(rewardToken.balanceOf(staker3), expectedRewards3);

        assertApproxEqAbs(
            rewardToken.balanceOf(address(stableCoinRewardsVault)) / 1e18, 0, 100000000, "Rewards not fully distributed"
        );
    }

    // Test mechamism that updates unclaimed rewards when user does multiple deposits and withdrawals
    function testUnclainedRewards(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {

        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVault, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVault, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVault, amount3);

        vm.warp(block.timestamp + 8 days);  

        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);
        
        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVault);
        console.log("Epoch started");

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVault, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVault, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVault, amount3);

        vm.warp(block.timestamp + 8 days);

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVault);  

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVault, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVault, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVault, amount3);

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVault); 

        // Test unclaimed rewards with various amount remaining (75%, 66%, 0%)
        amount1 -= actions.boundedWithdraw(staker1, stableCoinRewardsVault, (amount1 / 4)); 
        amount2 -= actions.boundedWithdraw(staker2, stableCoinRewardsVault, (amount2 / 3));
        amount3 -= actions.boundedWithdraw(staker3, stableCoinRewardsVault, (amount3 / 1));

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);
      
        vm.warp(block.timestamp + 1000 days);

        stableCoinRewardsVault.claimRewards(staker1);
        stableCoinRewardsVault.claimRewards(staker2);
        stableCoinRewardsVault.claimRewards(staker3);
        uint256 claimed = rewardToken.balanceOf(staker1);
        claimed += rewardToken.balanceOf(staker2);
        claimed += rewardToken.balanceOf(staker3);

        // All rewards should be claimed and contract balance should be 0
        assertApproxEqAbs((claimed / 1e6), (rewards / 1e6), 1000000);
        assertApproxEqAbs((rewardToken.balanceOf(address(stableCoinRewardsVault)) / 1e6), 0, 1000000);
    }

    // make deposits and try to claim the rewards in the same epoch
    function testCannotClaimCurrentEpochRewards(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {

        // deposit
        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVault, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVault, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVault, amount3);

        // warp to lock period
        vm.warp(block.timestamp + 8 days);  
        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVault, rewards);

        // claim rewards in the same epoch
        actions.claimAndExpectRevert(staker1, stableCoinRewardsVault);
        actions.claimAndExpectRevert(staker2, stableCoinRewardsVault);
        actions.claimAndExpectRevert(staker3, stableCoinRewardsVault);

    }

}

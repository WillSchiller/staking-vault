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
    StableCoinRewardsVault public stableCoinRewardsVaultProxy;
    Actions public actions;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public contractAdmin = address(0x0001);
    address public epochManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

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
        stableCoinRewardsVault = new StableCoinRewardsVault();

        // deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stableCoinRewardsVault),
            abi.encodeCall(
                stableCoinRewardsVault.initialize,
                (IERC20(address(asset)), "Vault Name", "SYMBOL",contractAdmin, epochManager, rewardsManager, minAmount, maxAmount, rewardToken)
            )
        );

        // set type of proxy and start epoch
        stableCoinRewardsVaultProxy = StableCoinRewardsVault(address(proxy));
        vm.prank(epochManager);
        stableCoinRewardsVaultProxy.startEpoch();

    }

    function testIsOpen(uint256 rawAmount) public {
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 1 days, false, "Testing isOpen at 1 day",rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 7 days + 1, true, "Testing isOpen at 7 days + 1 second: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 30 days + 1, true, "Testing isOpen at 30 days + 1 second: expect revert", rawAmount);
        actions.executeDepositWithdrawal(staker1, asset, stableCoinRewardsVaultProxy, 97 days, false, "Testing isOpen at 97 days", rawAmount);
    }

    function testIsLocked(uint256 rawAmount) public {
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVaultProxy, 1 days, true, "Testing isOpen at 1 day", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVaultProxy, 7 days + 1, false, "Testing isOpen at 7 days + 1 second", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVaultProxy, 30 days + 1, false, "Testing isOpen at 30 days + 1 second", rawAmount);
        actions.executeAddRewards(rewardsManager, asset, rewardToken, stableCoinRewardsVaultProxy, 97 days + 1, true, "Testing isOpen at 97 days", rawAmount);
    }

    function testIsMinAmount() public {}
    function testUpdateReward() public {}
    function testInitialize() public {}
    function testClaimRewards() public {}
    function testEarned() public {}
    function testAddRewards() public {}

    function testSimpleRewardsDistribution(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {
        //deposit        
        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);
        uint256 totalDeposits = amount1 + amount2 + amount3;
        
        //move to lock period and add rewards
        vm.warp(block.timestamp + 7 days+ 1);
        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);

        // rewards should == 0 until epoch finishe
        actions.claimAndExpectRevert(staker1, stableCoinRewardsVaultProxy);
        actions.claimAndExpectRevert(staker2, stableCoinRewardsVaultProxy);
        actions.claimAndExpectRevert(staker3, stableCoinRewardsVaultProxy);
        
        vm.warp(block.timestamp + 98 days);
        
        // check rewards
        uint256 rewardsPerShare = (rewards * 1e27) / totalDeposits;
        
        uint256 expectedRewards1 = (amount1 * rewardsPerShare) / 1e27;
        stableCoinRewardsVaultProxy.claimRewards(staker1);
        assertEq(rewardToken.balanceOf(staker1), expectedRewards1);
        

        uint256 expectedRewards2 = (amount2 * rewardsPerShare) / 1e27;
        stableCoinRewardsVaultProxy.claimRewards(staker2);
        assertEq(rewardToken.balanceOf(staker2), expectedRewards2);
        
        uint256 expectedRewards3 = (amount3 * rewardsPerShare) / 1e27;
        stableCoinRewardsVaultProxy.claimRewards(staker3);
        assertEq(rewardToken.balanceOf(staker3), expectedRewards3);

        assertApproxEqAbs(
            rewardToken.balanceOf(address(stableCoinRewardsVaultProxy)) / 1e27, 0, 5, "Rewards not fully distributed"
        );
    }

    // Test mechamism that updates unclaimed rewards when user does multiple deposits and withdrawals
    function testUnclainedRewards(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {

        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        vm.warp(block.timestamp + 8 days);  

        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);
        
        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVaultProxy);
        console.log("Epoch started");

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        vm.warp(block.timestamp + 8 days);

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVaultProxy);  

        amount1 += actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 += actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 += actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);

        vm.warp(block.timestamp + 98 days);
        actions.startEpoch(epochManager, stableCoinRewardsVaultProxy); 

        // Test unclaimed rewards with various amount remaining (75%, 66%, 0%)
        amount1 -= actions.boundedWithdraw(staker1, stableCoinRewardsVaultProxy, (amount1 / 4)); 
        amount2 -= actions.boundedWithdraw(staker2, stableCoinRewardsVaultProxy, (amount2 / 3));
        amount3 -= actions.boundedWithdraw(staker3, stableCoinRewardsVaultProxy, (amount3 / 1));

        vm.warp(block.timestamp + 8 days); 

        rewards += actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);
      
        vm.warp(block.timestamp + 1000 days);

        stableCoinRewardsVaultProxy.claimRewards(staker1);
        stableCoinRewardsVaultProxy.claimRewards(staker2);
        stableCoinRewardsVaultProxy.claimRewards(staker3);
        uint256 claimed = rewardToken.balanceOf(staker1);
        claimed += rewardToken.balanceOf(staker2);
        claimed += rewardToken.balanceOf(staker3);

        // All rewards should be claimed and contract balance should be 0
        assertApproxEqAbs((claimed / 1e6), (rewards / 1e6), 5);
        assertApproxEqAbs((rewardToken.balanceOf(address(stableCoinRewardsVaultProxy)) / 1e6), 0, 5);
    }

    // make deposits and try to claim the rewards in the same epoch
    function testCannotClaimCurrentEpochRewards(uint256 rewards, uint256 amount1, uint256 amount2, uint256 amount3) public {

        // deposit
        amount1 = actions.boundedDeposit(staker1, asset, stableCoinRewardsVaultProxy, amount1);
        amount2 = actions.boundedDeposit(staker2, asset, stableCoinRewardsVaultProxy, amount2);
        amount3 = actions.boundedDeposit(staker3, asset, stableCoinRewardsVaultProxy, amount3);

        // warp to lock period
        vm.warp(block.timestamp + 8 days);  
        rewards = actions.boundedReward(rewardsManager, rewardToken, stableCoinRewardsVaultProxy, rewards);

        // claim rewards in the same epoch
        actions.claimAndExpectRevert(staker1, stableCoinRewardsVaultProxy);
        actions.claimAndExpectRevert(staker2, stableCoinRewardsVaultProxy);
        actions.claimAndExpectRevert(staker3, stableCoinRewardsVaultProxy);

    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract stableCoinRewardsVaultTest is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    StableCoinRewardsVault public stableCoinRewardsVaultProxy;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public tester = address(0x0001);
    address public owner = address(0x0002);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

    function setUp() public {
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
                (
                    IERC20(address(asset)),
                    "Vault Name",
                    "SYMBOL",
                    minAmount,
                    maxAmount
                )
            )
        );
        stableCoinRewardsVaultProxy = StableCoinRewardsVault(address(proxy));
        stableCoinRewardsVaultProxy.startEpoch();
        vm.stopPrank();
    }

    function testIsOpen() public{}
    function testIsLocked() public{}
    function testIsMinAmount() public{}
    function testUpdateReward() public{}
    function testInitialize() public{}
    function testClaimRewards() public{}
    function testEarned() public{}
    function testAddRewards() public{}


    function testRewardsDistribution(
        uint256 rewards,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        address staker1 = address(0x1234);
        address staker2 = address(0x5678);
        address staker3 = address(0x9abc);
        uint256 amount1 = bound(amount1, minAmount, maxAmount);
        uint256 amount2 = bound(amount2, minAmount, maxAmount);
        uint256 amount3 = bound(amount3, minAmount, maxAmount);
        uint256 rewards = bound(rewards, 100000000, 1000000000000000000); // between 100 and a trillion dollars Assume USDT
        uint256 totalAmount = amount1 + amount2 + amount3;
        uint256 rewardsPerShare = (rewards * 1e27) / totalAmount;
        asset.mint(staker1, amount1);
        asset.mint(staker2, amount2);
        asset.mint(staker3, amount3);
        vm.startPrank(staker1);
        asset.approve(address(stableCoinRewardsVaultProxy), amount1);
        stableCoinRewardsVaultProxy.deposit(amount1, staker1);
        vm.stopPrank();
        vm.startPrank(staker2);
        asset.approve(address(stableCoinRewardsVaultProxy), amount2);
        stableCoinRewardsVaultProxy.deposit(amount2, staker2);
        vm.stopPrank();
        vm.startPrank(staker3);
        asset.approve(address(stableCoinRewardsVaultProxy), amount3);
        stableCoinRewardsVaultProxy.deposit(amount3, staker3);
        vm.stopPrank();
        vm.startPrank(owner);
        rewardToken.mint(address(owner), rewards);
        rewardToken.approve(address(stableCoinRewardsVaultProxy), rewards);
        vm.warp(block.timestamp + 7 days);
        stableCoinRewardsVaultProxy.addRewards(rewards);
        vm.stopPrank();
        vm.startPrank(staker1);
        uint256 rewards1 = stableCoinRewardsVaultProxy.earned(staker1);
        uint256 expectedRewards1 = (amount1 * rewardsPerShare) / 1e27;
        if (expectedRewards1 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker1);
            vm.assertEq(rewardToken.balanceOf(staker1), expectedRewards1);
        }
        vm.stopPrank();
        vm.startPrank(staker2);
        uint256 rewards2 = stableCoinRewardsVaultProxy.earned(staker2);
        uint256 expectedRewards2 = (amount2 * rewardsPerShare) / 1e27;
        if (expectedRewards2 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker2);
            vm.assertEq(rewardToken.balanceOf(staker2), expectedRewards2);
        }
        vm.stopPrank();
        vm.startPrank(staker3);
        uint256 rewards3 = stableCoinRewardsVaultProxy.earned(staker3);
        uint256 expectedRewards3 = (amount3 * rewardsPerShare) / 1e27;
        if (expectedRewards3 != 0) {
            stableCoinRewardsVaultProxy.claimRewards(staker3);
            vm.assertEq(rewardToken.balanceOf(staker3), expectedRewards3);
        }
        vm.stopPrank();
        vm.assertApproxEqAbs(
            rewardToken.balanceOf(address(stableCoinRewardsVaultProxy))/1e27,
            0,
            5,
            "Rewards not fully distributed"
        );

    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract StableCoinRewardsVaultTest is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public vaultAdmin = address(0x0001);
    address public vaultManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    address public tester = address(0x0004);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02
    uint256 maxPoolSize = 100000000000000000000000000; // 2_000_000 of tokens @ 0.02

    function setUp() public {
        vm.warp(104 days + 1);
        //setup mock token
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

        //mint assets
        asset.mint(tester, 10_000_000 * 1e18);

        //deploy implementation contract
        stableCoinRewardsVault = new StableCoinRewardsVault(
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
        stableCoinRewardsVault.startEpoch();

    }

    function testDepositAndWithdraw() public {
        vm.startPrank(tester);

        asset.approve(address(stableCoinRewardsVault), 10000 * 1e18);
        uint256 sharesMinted = stableCoinRewardsVault.deposit(10000 * 1e18, tester);

        // Check shares and total assets
        assertEq(stableCoinRewardsVault.balanceOf(tester), sharesMinted);
        assertEq(stableCoinRewardsVault.totalAssets(), 10000 * 1e18);
        // Withdraw assets
        uint256 assetsWithdrawn = stableCoinRewardsVault.withdraw(10000 * 1e18, tester, tester);
        // Check balances after withdrawal
        assertEq(stableCoinRewardsVault.balanceOf(tester), 0);
        assertEq(stableCoinRewardsVault.totalAssets(), 0);
        assertEq(assetsWithdrawn, 10000 * 1e18);

        vm.stopPrank();
    }

}

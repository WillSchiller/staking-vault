// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Actions} from "./helpers/Actions.sol";

contract InflationTest is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    Actions public actions;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public vaultAdmin = address(0x0001);
    address public vaultManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    uint256 minAmount = 0; // set to 0 to allow any amount
    uint256 maxAmount = type(uint256).max; // set to max to allow any amounts
    uint256 maxPoolSize = 100000000000000000000000000; // 2_000_000 of tokens @ 0.02

    address staker1 = address(0x1234);
    address hacker = address(0x5678);
    address staker3 = address(0x9abc);
    address deployer = address(0xdef0);

    error NoClaimableRewards();

    function setUp() public {
        // helper actions
        actions = new Actions();

        vm.warp(104 days + 1);
        vm.startPrank(deployer);
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
            asset, "NEXD Rewards Vault", "sNEXD", vaultAdmin, vaultManager, minAmount, maxAmount, maxPoolSize
        );

        // deploy proxy

        // set type of proxy and start epoch
        vm.stopPrank();
        vm.prank(vaultManager);
        stableCoinRewardsVault.startEpoch();
    }

    // infation test

    function testInflateAssets() public {
        uint256 bigAmount = 20_000_000_000_000_000 * 1e18;
        uint256 midAmount = 10_000 * 1e18;

        // Hacker mints 1 share
        uint256 hackerShares = actions.simpleMint(hacker, asset, stableCoinRewardsVault, 1, false);

        // Hacker inflates assets in pool

        vm.prank(deployer);
        asset.mint(hacker, bigAmount);
        vm.prank(hacker);
        asset.transfer(address(stableCoinRewardsVault), bigAmount);

        // user mints a big amount of shares
        uint256 usershares = actions.simpleMint(staker1, asset, stableCoinRewardsVault, midAmount, false);

        // hacker burns share
        actions.simpleRedeem(hacker, stableCoinRewardsVault, hackerShares, false);

        // user burns shares
        actions.simpleRedeem(staker1, stableCoinRewardsVault, usershares, false);

        assert(asset.balanceOf(staker1) >= midAmount);
        assert(asset.balanceOf(hacker) <= bigAmount + 1);
    }

    function testFuzzInflateAssets(uint256 amount, uint256 bigAmount) public {
        amount = bound(amount, 1e9, 10_000_000 * 1e18);
        bigAmount = bound(bigAmount, 1e9, 10_000_000 * 1e18);

        // Hacker mints 1 share
        uint256 hackerShares = actions.simpleMint(hacker, asset, stableCoinRewardsVault, 1, false);

        // mint assets
        vm.prank(deployer);
        asset.mint(hacker, bigAmount);
        // Hacker inflates assets in pool
        vm.prank(hacker);
        asset.transfer(address(stableCoinRewardsVault), bigAmount);

        // user mints a big amount of shares
        uint256 usershares = actions.simpleMint(staker1, asset, stableCoinRewardsVault, amount, false);

        // hacker burns share
        actions.simpleRedeem(hacker, stableCoinRewardsVault, hackerShares, false);

        // user burns shares
        actions.simpleRedeem(staker1, stableCoinRewardsVault, usershares, false);

        assert(asset.balanceOf(staker1) >= amount - (amount / 1e9));
        assert(asset.balanceOf(hacker) <= bigAmount + 1 + (bigAmount / 1e9));
    }
}

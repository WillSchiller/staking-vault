// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract MultiStakeTest is Test {
    /*
    StableCoinRewardsVault public stableCoinRewardsVault;
    StableCoinRewardsVault public stableCoinRewardsVaultProxy;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public tester = address(0x0001);
    address public owner = address(0x0002);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

    uint256 public _totalSuppy;

    function setUp() public {
        vm.startPrank(owner);
        vm.warp(104 days + 1);
        //setup mock token
        asset = new ERC20Mock();

        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;
        address targetAddr = address(
            0x7AC8519283B1bba6d683FF555A12318Ec9265229
        );
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
                    "Staked Nexade",
                    "sNEXD",
                    minAmount,
                    maxAmount
                )
            )
        );
        stableCoinRewardsVaultProxy = StableCoinRewardsVault(address(proxy));
        stableCoinRewardsVaultProxy.startEpoch();
        vm.stopPrank();
    }

    mapping(address => uint256) public stakerShares;

    function testMultipleStakesAndWithdraws(
        uint256 seed,
        uint256 rewards
    ) public {
        uint256 numberOfStakers = 1000;
        uint256[] memory amounts = new uint256[](numberOfStakers);
        uint256 _totalSuppy = 0;
        for (uint256 i = 0; i < numberOfStakers; i++) {
            amounts[i] = bound(
                uint256(keccak256(abi.encode(seed, i))),
                minAmount,
                maxAmount
            );
        }

        // 1) Everyone deposits
        for (uint256 i = 0; i < numberOfStakers; i++) {
            address staker = address(
                uint160(uint256(keccak256(abi.encode(seed, i))) + 1)
            );
            asset.mint(staker, amounts[i]);

            vm.startPrank(staker);
            asset.approve(address(stableCoinRewardsVaultProxy), amounts[i]);
            uint256 shares = stableCoinRewardsVaultProxy.deposit(
                amounts[i],
                staker
            );
            vm.stopPrank();
            _totalSuppy += amounts[i];
            stakerShares[staker] = shares; // record for later
        }

        // then add rewards
        vm.warp(block.timestamp + 7 days);
        vm.startPrank(owner);
        rewards = bound(rewards, 100000000, 1000000000000000000); // between 100 and a trillion dollars Assume USDT
        rewardToken.mint(address(owner), rewards);
        rewardToken.approve(address(stableCoinRewardsVaultProxy), rewards);
        stableCoinRewardsVaultProxy.addRewards(rewards);
        vm.stopPrank();

        // Then everone claims
        for (uint256 i = 0; i < numberOfStakers; i++) {
            address staker = address(
                uint160(uint256(keccak256(abi.encode(seed, i))) + 1)
            );
            vm.startPrank(staker);
            stableCoinRewardsVaultProxy.claimRewards(staker);
            vm.stopPrank();
        }

        // 2) Then everyone withdraws
        for (uint256 i = 0; i < numberOfStakers; i++) {
            address staker = address(
                uint160(uint256(keccak256(abi.encode(seed, i))) + 1)
            );
            vm.startPrank(staker);
            // withdraw all shares
            stableCoinRewardsVaultProxy.withdraw(
                stakerShares[staker],
                staker,
                staker
            );
            vm.stopPrank();
            _totalSuppy -= stakerShares[staker];
        }

        // 3) Check that everyone has 0 shares
        for (uint256 i = 0; i < numberOfStakers; i++) {
            address staker = address(
                uint160(uint256(keccak256(abi.encode(seed, i))) + 1)
            );
            assertEq(stableCoinRewardsVaultProxy.balanceOf(staker), 0);
            assertEq(
                stableCoinRewardsVaultProxy.balanceOf(staker),
                _totalSuppy
            );
        }

        // 4) Check that the total assets are 0
        assertEq(stableCoinRewardsVaultProxy.totalAssets(), _totalSuppy);
        vm.assertApproxEqAbs(
            rewardToken.balanceOf(address(stableCoinRewardsVaultProxy)) / 1e27,
            0,
            5,
            "Rewards not fully distributed"
        );
    }
    */
}

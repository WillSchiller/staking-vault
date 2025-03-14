// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Actions} from "./helpers/Actions.sol";

contract AccessControlTests is Test {
    StableCoinRewardsVault public stableCoinRewardsVault;
    Actions public actions;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant VAULT_MANAGER_ROLE =
        keccak256("VAULT_MANAGER_ROLE");

    address public admin_1 = address(0x0001);
    address public admin_2 = address(0x0002);
    address public admin_3 = address(0x0003);

    address public manager_1 = address(0x0004);
    address public manager_2 = address(0x0005);
    address public manager_3 = address(0x0006);

    address public tester = address(0x007);

    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02
    uint256 maxPoolSize = 50000000000000000000000000000000000000; // 20_000_000 of tokens @ 0.02

    function setUp() public {
        // helper actions
        actions = new Actions();

        vm.warp(104 days + 1);

        //setup mock tokens
        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;

        //USDT token
        address rewardTokenAddr = address(
            0x7AC8519283B1bba6d683FF555A12318Ec9265229
        );
        vm.etch(rewardTokenAddr, bytecode);
        rewardToken = ERC20Mock(rewardTokenAddr);

        //NEXD token
        address assetTargetAddr = address(
            0x3858567501fbf030BD859EE831610fCc710319f4
        );
        vm.etch(assetTargetAddr, bytecode);
        asset = ERC20Mock(assetTargetAddr);

        //deploy implementation contract
        stableCoinRewardsVault = new StableCoinRewardsVault(
            asset,
            "NEXD Rewards Vault",
            "sNEXD",
            admin_1,
            manager_1,
            minAmount,
            maxAmount,
            maxPoolSize
        );

        // deploy proxy

        vm.prank(manager_1);
        stableCoinRewardsVault.startEpoch();
    }

    function testCanSetMinAmount() public {
        //mananger 1 can set min amount
        vm.prank(manager_1);
        stableCoinRewardsVault.updateMinAmount(1000);
        assertEq(stableCoinRewardsVault.minAmount(), 1000);

        //manager 2 cannot set min amount
        vm.prank(manager_2);
        vm.expectRevert();
        stableCoinRewardsVault.updateMinAmount(100);
        assertEq(stableCoinRewardsVault.minAmount(), 1000);
    }

    function testCanSetMaxAmount() public {
        //mananger 1 can set max amount
        vm.prank(manager_1);
        stableCoinRewardsVault.updateMaxAmount(1000000);
        assertEq(stableCoinRewardsVault.maxAmount(), 1000000);

        //manager 2 cannot set max amount
        vm.prank(manager_2);
        vm.expectRevert();
        stableCoinRewardsVault.updateMaxAmount(100000);
        assertEq(stableCoinRewardsVault.maxAmount(), 1000000);
    }

    function canAddNewManager() public {
        vm.prank(admin_1);
        stableCoinRewardsVault.grantRole(VAULT_MANAGER_ROLE, manager_2);
        assert(stableCoinRewardsVault.hasRole(VAULT_MANAGER_ROLE, manager_2));
        vm.prank(manager_2);
        stableCoinRewardsVault.updateMaxAmount(1000000);
        assertEq(stableCoinRewardsVault.maxAmount(), 1000000);
        vm.prank(manager_1);
        stableCoinRewardsVault.updateMaxAmount(5000000);
        assertEq(stableCoinRewardsVault.maxAmount(), 5000000);
    }

    function testCanRemoveManager() public {
        vm.prank(admin_1);
        stableCoinRewardsVault.revokeRole(VAULT_MANAGER_ROLE, manager_1);
        assert(!stableCoinRewardsVault.hasRole(VAULT_MANAGER_ROLE, manager_1));
        vm.startPrank(manager_1);
        vm.expectRevert();
        stableCoinRewardsVault.updateMaxAmount(1000000);
        assertEq(stableCoinRewardsVault.maxAmount(), maxAmount);
        vm.stopPrank();
    }

    function testCanAddAdmin() public {
        vm.prank(admin_1);
        stableCoinRewardsVault.grantRole(VAULT_ADMIN_ROLE, admin_2);
        assert(stableCoinRewardsVault.hasRole(VAULT_ADMIN_ROLE, admin_2));
        assert(stableCoinRewardsVault.hasRole(VAULT_ADMIN_ROLE, admin_1));
    }

    function testCanRemoveAdmin() public {
        vm.prank(admin_1);
        stableCoinRewardsVault.revokeRole(VAULT_ADMIN_ROLE, admin_1);
        assert(!stableCoinRewardsVault.hasRole(VAULT_ADMIN_ROLE, admin_1));
        vm.startPrank(admin_1);
        vm.expectRevert();
        stableCoinRewardsVault.grantRole(VAULT_ADMIN_ROLE, admin_1);
    }

    function testManagerCanStartEpoch() public {
        vm.warp(block.timestamp + 97 days);
        //admins cannot start epoch
        vm.prank(admin_1);
        vm.expectRevert();
        stableCoinRewardsVault.startEpoch();
        //managers can start epoch
        vm.prank(manager_1);
        stableCoinRewardsVault.startEpoch();
    }

    function testManagerCanAddRewards() public {
        //setup test
        asset.mint(tester, 10_000_000 * 1e18);
        rewardToken.mint(manager_1, 10_000_000 * 1e18);
        vm.startPrank(tester);
        asset.approve(address(stableCoinRewardsVault), 10000 * 1e18);
        stableCoinRewardsVault.deposit(10000 * 1e18, tester);
        vm.stopPrank();
        vm.warp(block.timestamp + 7 days);
        //admins cannot add rewards
        vm.prank(admin_1);
        vm.expectRevert();
        stableCoinRewardsVault.addRewards(1000000);
        //managers can add rewards
        vm.startPrank(manager_1);
        rewardToken.approve(address(stableCoinRewardsVault), 1000000);
        stableCoinRewardsVault.addRewards(1000000);
        vm.stopPrank();
    }
}

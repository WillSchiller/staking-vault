// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EpochStakingVault} from "../src/EpochStakingVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract EpochStakingVaultTest is Test {

    EpochStakingVault public epochStakingVault;
    ERC20Mock public asset;
    address public vaultAdmin = address(0x0001);
    address public vaultManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    address public tester = address(0x0004);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02
    uint256 maxPoolSize = 100000000000000000000000000; // 2_000_000 of tokens @ 0.02

    function setUp() public {
        vm.warp(104 days + 1);

        //setup mock tokens
        ERC20Mock implementation = new ERC20Mock();
        bytes memory bytecode = address(implementation).code;

        //NEXD token
        address assetTargetAddr = address(0x3858567501fbf030BD859EE831610fCc710319f4);
        vm.etch(assetTargetAddr, bytecode);
        asset = ERC20Mock(assetTargetAddr);

        asset.mint(tester, 10_000_000 * 1e18);

        /// Reward token
        IERC20 rewardToken = IERC20(address(0x0));


        //deploy implementation contract
        epochStakingVault = new EpochStakingVault(
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
        epochStakingVault.startEpoch();

    }

    function testDepositAndWithdraw() public {
        vm.startPrank(tester);

        asset.approve(address(epochStakingVault), 10000 * 1e18);
        uint256 sharesMinted = epochStakingVault.deposit(10000 * 1e18, tester);

        // Check shares and total assets
        assertEq(epochStakingVault.balanceOf(tester), sharesMinted);
        assertEq(epochStakingVault.totalAssets(), 10000 * 1e18);
        // Withdraw assets
        uint256 assetsWithdrawn = epochStakingVault.withdraw(10000 * 1e18, tester, tester);
        // Check balances after withdrawal
        assertEq(epochStakingVault.balanceOf(tester), 0);
        assertEq(epochStakingVault.totalAssets(), 0);
        assertEq(assetsWithdrawn, 10000 * 1e18);

        vm.stopPrank();
    }
    /*
   function testAuthorizedUpgrade() public {
        // Deploy a new implementation contract
        EpochStakingVault newImplementation = new EpochStakingVault();

        // Calculate the EIP-1967 implementation slot
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

        bytes memory data = "";

        // Upgrade the proxy to the new implementation
        vm.startPrank(vaultAdmin);
        epochStakingVault.upgradeToAndCall(address(newImplementation), data);
        vm.stopPrank();

        vm.startPrank(vaultAdmin);
        epochStakingVault.upgradeToAndCall(address(newImplementation), data);
        vm.stopPrank();

        EpochStakingVault authorizedImplementation = new EpochStakingVault();

        vm.startPrank(tester);
        vm.expectRevert();
        epochStakingVault.upgradeToAndCall(address(authorizedImplementation), data);
        vm.stopPrank();

        // Verify that the implementation address was updated in the proxy storage
        address storedImplementation =
            address(uint160(uint256(vm.load(address(epochStakingVault), implementationSlot))));
        assertEq(storedImplementation, address(newImplementation));
    }

    // testing cannot interact with implimentation contract
    function testCannotUseImplimentation() public {
        vm.startPrank(tester);
        asset.approve(address(epochStakingVault), 20000 * 1e18);
        vm.expectRevert();
        epochStakingVault.deposit(10000 * 1e18, msg.sender);
        asset.approve(address(epochStakingVault), 20000 * 1e18);
        epochStakingVault.deposit(10000 * 1e18, msg.sender);
    }

    */
}

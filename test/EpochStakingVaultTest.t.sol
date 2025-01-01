// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EpochStakingVault} from "../src/EpochStakingVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract EpochStakingVaultTest is Test {
    EpochStakingVault public epochStakingVault;
    EpochStakingVault public epochStakingVaultProxy;
    ERC20Mock public asset;
    address public tester = address(0x0001);
    address public owner = address(0x0002);

    function setUp() public {
        vm.startPrank(owner);
        //setup mock token
        asset = new ERC20Mock();
        asset.mint(tester, 10000000000);

        //deploy implementation contract
        epochStakingVault = new EpochStakingVault();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(epochStakingVault),
            abi.encodeCall(
                EpochStakingVault.initialize,
                (IERC20(address(asset)), "Vault Name", "SYMBOL")
            )
        );
        epochStakingVaultProxy = EpochStakingVault(address(proxy));
        vm.stopPrank();
    }

    function testDepositAndWithdraw() public {
        vm.startPrank(tester);

        asset.approve(address(epochStakingVaultProxy), 10000);
        uint256 sharesMinted = epochStakingVaultProxy.deposit(10000, tester);

        // Check shares and total assets
        assertEq(epochStakingVaultProxy.balanceOf(tester), sharesMinted);
        assertEq(epochStakingVaultProxy.totalAssets(), 10000);
        // Withdraw assets
        uint256 assetsWithdrawn = epochStakingVaultProxy.withdraw(
            10000,
            tester,
            tester
        );
        // Check balances after withdrawal
        assertEq(epochStakingVaultProxy.balanceOf(tester), 0);
        assertEq(epochStakingVaultProxy.totalAssets(), 0);
        assertEq(assetsWithdrawn, 10000);

        vm.stopPrank();
    }

    function testAuthorizedUpgrade() public {
        // Deploy a new implementation contract
        EpochStakingVault newImplementation = new EpochStakingVault();

        // Calculate the EIP-1967 implementation slot
        bytes32 implementationSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );

        bytes memory data = "";

        // Upgrade the proxy to the new implementation
        vm.startPrank(owner);
        epochStakingVaultProxy.upgradeToAndCall(
            address(newImplementation),
            data
        );
        vm.stopPrank();

        // Verify that the implementation address was updated in the proxy storage
        address storedImplementation = address(
            uint160(
                uint256(
                    vm.load(address(epochStakingVaultProxy), implementationSlot)
                )
            )
        );
        assertEq(storedImplementation, address(newImplementation));
    }

    // testing cannot interact with implimentation contract
    function testCannotUseImplimentation() public {
        vm.startPrank(tester);
        asset.approve(address(epochStakingVault), 20000);
        vm.expectRevert();
        epochStakingVault.deposit(10000, msg.sender);
        asset.approve(address(epochStakingVaultProxy), 20000);
        epochStakingVaultProxy.deposit(10000, msg.sender);
    }
}

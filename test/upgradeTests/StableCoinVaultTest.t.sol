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
    address public tester = address(0x0001);
    address public owner = address(0x0002);
    uint256 minAmount = 5000000000000000000000; // $100 of tokens @ 0.02
    uint256 maxAmount = 5000000000000000000000000; // 100_000 of tokens @ 0.02

    function setUp() public {
        vm.startPrank(owner);
        vm.warp(104 days + 1);
        //setup mock token
        asset = new ERC20Mock();
        asset.mint(tester, 10_000_000 * 1e18);

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

    function testDepositAndWithdraw() public {
        vm.startPrank(tester);

        asset.approve(address(stableCoinRewardsVaultProxy), 10000 * 1e18);
        uint256 sharesMinted = stableCoinRewardsVaultProxy.deposit(10000 * 1e18, tester);

        // Check shares and total assets
        assertEq(stableCoinRewardsVaultProxy.balanceOf(tester), sharesMinted);
        assertEq(stableCoinRewardsVaultProxy.totalAssets(), 10000 * 1e18);
        // Withdraw assets
        uint256 assetsWithdrawn = stableCoinRewardsVaultProxy.withdraw(
            10000 * 1e18,
            tester,
            tester
        );
        // Check balances after withdrawal
        assertEq(stableCoinRewardsVaultProxy.balanceOf(tester), 0);
        assertEq(stableCoinRewardsVaultProxy.totalAssets(), 0);
        assertEq(assetsWithdrawn, 10000 * 1e18);

        vm.stopPrank();
    }

    function testAuthorizedUpgrade() public {
        // Deploy a new implementation contract
        StableCoinRewardsVault newImplementation = new StableCoinRewardsVault();

        // Calculate the EIP-1967 implementation slot
        bytes32 implementationSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );

        bytes memory data = "";

        // Upgrade the proxy to the new implementation
        vm.startPrank(owner);
        stableCoinRewardsVaultProxy.upgradeToAndCall(
            address(newImplementation),
            data
        );
        vm.stopPrank();

        // Verify that the implementation address was updated in the proxy storage
        address storedImplementation = address(
            uint160(
                uint256(
                    vm.load(address(stableCoinRewardsVaultProxy), implementationSlot)
                )
            )
        );
        assertEq(storedImplementation, address(newImplementation));
    }


    // testing cannot interact with implimentation contract
    function testCannotUseImplimentation() public {
        vm.startPrank(tester);
        asset.approve(address(stableCoinRewardsVault), 20000 * 1e18);
        vm.expectRevert();
        stableCoinRewardsVault.deposit(10000 * 1e18, msg.sender);
        asset.approve(address(stableCoinRewardsVaultProxy), 20000* 1e18 );
        stableCoinRewardsVaultProxy.deposit(10000 * 1e18, msg.sender);
    }
}

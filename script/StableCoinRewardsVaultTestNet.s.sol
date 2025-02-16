// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {StableCoinRewardsVault} from "../src/StableCoinRewardsVault.sol";
import {USDN} from "../src/mock/USDN.sol"; // mock USDC token
import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Deploy is Script {

    /// contracts
    StableCoinRewardsVault public implimentation;
    StableCoinRewardsVault public vault;

    /// roles
    address public contractAdmin = 0xCB62b03ee401DcfDc694638375D03BaFE7681eB1;
    address public epochManager = 0x63211E9514d963C342dE14475E4E11f80F3094aa;
    address public rewardsManager = 0x45F466e9D55fCF13e2D1bA3d3228986512a05eEE;

    /// params
    uint256 public minAmount = 1 * 1e18; // 1 NEXD 
    uint256 public maxAmount = 5000000 * 1e18; // $100k of NEXD @ $0.02
    uint256 public maxPoolSize = 100000000 * 1e18; // $2M of NEXD @ $0.02

    /// tokens
    IERC20 public asset = IERC20(address(0xfc4F032EdB7DE1c5cBd3c6700d56520458349C46)); // Testnet NEXD token
    IERC20 public rewardToken = IERC20(address(0x0)); // Official USDC Arbitrum Sepolia Testnet Token 

    function run() public {
        // Deploy the vault
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey); 

        USDN usdn = new USDN();
        rewardToken = IERC20(address(usdn));

        console2.log("Deploying StableCoinRewardsVault with asset: %s, rewardToken: %s", address(asset), address(rewardToken));

        vault = new StableCoinRewardsVault(
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
        console2.log("Vault deployed at: %s", address(vault));
        vm.stopBroadcast();
    }
}





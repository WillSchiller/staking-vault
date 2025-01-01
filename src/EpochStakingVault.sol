// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract EpochStakingVault is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    event VaultInitialized(address indexed asset, string name, string symbol);

    /// @dev prevent implimentation initialization; only proxy should be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 asset,
        string memory name,
        string memory symbol
    ) public initializer {
        __Ownable_init(msg.sender); // Initialize Ownable // Update to safe later
        __ERC4626_init(asset);      // Initialize ERC4626 with the staked token (asset)
        __ERC20_init(name, symbol); // Initialize the underlying ERC20 (vault token)
        __UUPSUpgradeable_init();   // Initialize UUPS

        emit VaultInitialized(address(asset), name, symbol);
    }

    /// @dev restrict upgrades to the contract owner only.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
   
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DistributeRewards} from "./DistributeRewards.sol";


contract EpochStakingVault is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable, DistributeRewards {

    uint256 public currentEpoch;
    uint256 public epochStart;
    
    //EPOCH CONFIG
    uint256 constant DEPOSIT_WINDOW = 7 days; 
    uint256 constant LOCK_PERIOD = 90 days;
    uint256 constant minAmount = 1000 * 1e18; // 1000 NEXD

    event VaultInitialized(address indexed asset, string name, string symbol);
    event EpochStarted(uint256 indexed epoch, uint256 indexed start);

    error InvalidAsset();
    error TokensLockedUntil(uint256 epochEnd);
    error amountTooLow(); 
    error EpochInProgress();
    

    modifier isOpen() {
        uint256 epochEnd = epochStart + DEPOSIT_WINDOW + LOCK_PERIOD;
        if (block.timestamp > epochStart + DEPOSIT_WINDOW && 
            block.timestamp < epochEnd) revert TokensLockedUntil(epochEnd);
        _;
    }

    modifier isMinAmount(uint256 amount) {
        if (amount < minAmount) revert amountTooLow();
        _;
    }


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
        // if(address(asset) != address(0x3858567501fbf030bd859ee831610fcc710319f4)) revert InvalidAsset(); // Ensure asset is NEXD to maintain decimals 18 // Update to nexade address later
        __Ownable_init(msg.sender); // Initialize Ownable // Update to safe later
        __ERC4626_init(asset);      // Initialize ERC4626 with the staked token (asset)
        __ERC20_init(name, symbol); // Initialize the underlying ERC20 (vault token)
        __UUPSUpgradeable_init();   // Initialize UUPS

        emit VaultInitialized(address(asset), name, symbol);
    }


    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(address) public view override returns (uint256) {
        return 10_000_000 * 10**18;  // update to constant for gas optimization
    }

    /** @dev See {IERC4626-maxMint}. */
    function maxMint(address) public view override returns (uint256) {
        return 10_000_000 * 10**18; // update to constant for gas optimization
    }


    /// @dev only changes to deposit, mint, withdraw and redeem functions are to add the isOpen and isMinAmount modifiers
    /// @dev isOpen modifier restricts deposit, mint, withdraw and redeem functions to be called only when the vault is in the deposit window
    /// @dev isMinAmount modifier restricts deposit, mint, withdraw and redeem functions to be called only when the amount is greater than the minAmount 
    /// modifers should not affect ERC4626Upgradeable functionality in any other way. 
    function deposit(uint256 assets, address receiver) public override isOpen() isMinAmount(assets) returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    function mint(uint256 shares, address receiver) public override isOpen() isMinAmount(shares) returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override isOpen() returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) public override isOpen() returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function startEpoch() public onlyOwner {
        // Additional 7 days to give time for withdraws
        if (block.timestamp < epochStart + DEPOSIT_WINDOW + LOCK_PERIOD + 7 days) revert EpochInProgress();
        currentEpoch++;
        epochStart = block.timestamp;
        emit EpochStarted(currentEpoch, epochStart);
    }
    
    /// @dev restrict upgrades to the contract owner only.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract EpochStakingVault is Initializable, ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Math for uint256;

    uint256 public currentEpoch;
    uint256 public startTime;
    uint256 public minAmount;
    uint256 public maxAmount;

    uint256 constant DEPOSIT_WINDOW = 7 days; 
    uint256 constant LOCK_PERIOD = 90 days;
    
    event VaultInitialized(address indexed asset, string name, string symbol);
    event EpochStarted(uint256 indexed epoch, uint256 indexed start);

    error InvalidAsset();
    error TokensLockedUntil(uint256 epochEnd);
    error amountTooLow(); 
    error EpochInProgress();
    error NotLocked();
    error InvalidClaim();
    
    modifier isOpen() { // will revert is not open
        uint256 epochEnd = startTime + DEPOSIT_WINDOW + LOCK_PERIOD;
        if (block.timestamp > startTime + DEPOSIT_WINDOW && 
            block.timestamp < epochEnd) revert TokensLockedUntil(epochEnd);
        _;
    }

    modifier isLocked() { //will revert if not locked
        if (block.timestamp < startTime + DEPOSIT_WINDOW ||
        block.timestamp > startTime + DEPOSIT_WINDOW + LOCK_PERIOD) revert NotLocked();
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

    function initialize (
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint256 _minAmount,
        uint256 _maxAmount
    ) public virtual initializer {
        // if(address(asset) != address(0x3858567501fbf030bd859ee831610fcc710319f4)) revert InvalidAsset(); // Ensure asset is NEXD to maintain decimals 18 // Update to nexade address later
        __Ownable_init(msg.sender); // Initialize Ownable // Update to safe later
        __ERC4626_init(_asset);      // Initialize ERC4626 with the staked token (asset)
        __ERC20_init(_name, _symbol); // Initialize the underlying ERC20 (vault token)
        __UUPSUpgradeable_init();   // Initialize UUPS

        minAmount = _minAmount;
        maxAmount = _maxAmount;

        emit VaultInitialized(address(_asset), _name, _symbol);
    }


    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(address) public view override returns (uint256) {
        return maxAmount;  // update to constant for gas optimization
    }

    /** @dev See {IERC4626-maxMint}. */
    function maxMint(address) public view override returns (uint256) {
        return _convertToShares(maxAmount, Math.Rounding.Ceil); // update to constant for gas optimization
    }

    /// @dev only changes to deposit, mint, withdraw and redeem functions are to add the isOpen and isMinAmount modifiers
    /// @dev isOpen modifier restricts deposit, mint, withdraw and redeem functions to be called only when the vault is in the deposit window
    /// @dev isMinAmount modifier restricts deposit, mint, withdraw and redeem functions to be called only when the amount is greater than the minAmount 
    /// modifers should not affect ERC4626Upgradeable functionality in any other way. 
    function deposit(uint256 assets, address receiver) public virtual override isOpen() isMinAmount(assets) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override isOpen() isMinAmount(_convertToAssets(shares, Math.Rounding.Ceil)) returns (uint256) {
       return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public virtual override isOpen() returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override isOpen() returns (uint256) {
       return super.redeem(shares, receiver, owner);
    }

    function startEpoch() public onlyOwner {
        if (block.timestamp < startTime + DEPOSIT_WINDOW + LOCK_PERIOD) revert EpochInProgress();
        currentEpoch++;
        uint256 epochStart = block.timestamp;
        startTime = epochStart;
        emit EpochStarted(currentEpoch, epochStart);
    }
    
    /// @dev restrict upgrades to the contract owner only.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}

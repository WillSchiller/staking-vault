// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; 
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EpochStakingVault is
    ERC4626,
    AccessControl,
    ReentrancyGuard
{
    using Math for uint256;

    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");
    bytes32 public constant EPOCH_MANAGER_ROLE = keccak256("EPOCH_MANAGER_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");

    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant DEPOSIT_WINDOW = 7 days;
    uint256 public constant LOCK_PERIOD = 90 days;

    uint256 public currentEpoch;
    uint256 public startTime;
    uint256 public minAmount;
    uint256 public maxAmount;
    uint256 public maxPoolSize;

    event VaultInitialized(address indexed asset, string name, string symbol);
    event EpochStarted(uint256 indexed epoch, uint256 indexed start);

    error InvalidAsset();
    error EpochLocked();
    error AmountTooLow();
    error EpochInProgress();
    error NotLocked();
    error InvalidClaim();
    error MinAmountTooLow();
    error MinAmountMustBeLessThanMaxAmount();
    error ModifyingPoolParametersOutsidePermittedInterval();
    error PoolMaxSizeReached();

    modifier isOpen() { 
        if (block.timestamp >= startTime + DEPOSIT_WINDOW && block.timestamp < startTime + DEPOSIT_WINDOW + LOCK_PERIOD) {
            revert EpochLocked();
        }
        _;
    }

    modifier isLocked() { 
        if (block.timestamp < startTime + DEPOSIT_WINDOW || block.timestamp >= startTime + DEPOSIT_WINDOW + LOCK_PERIOD) {
            revert NotLocked();
        }
        _;
    }

    modifier isMinAmount(uint256 amount) {
        if (amount < minAmount) revert AmountTooLow();
        _;
    }


    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _contractAdmin,
        address _epochManager,
        address _rewardsManager,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _maxPoolSize
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        _grantRole(CONTRACT_ADMIN_ROLE, _contractAdmin);
        _grantRole(EPOCH_MANAGER_ROLE, _epochManager);
        _grantRole(REWARDS_MANAGER_ROLE, _rewardsManager);
        minAmount = _minAmount;
        maxAmount = _maxAmount;
        maxPoolSize = _maxPoolSize;
        emit VaultInitialized(address(_asset), _name, _symbol);
    }

    function updateMinAmount(uint256 _minAmount) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        if (_minAmount >= maxAmount) revert MinAmountMustBeLessThanMaxAmount();
        minAmount = _minAmount;
    }

    function updateMaxAmount(uint256 _maxAmount) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        maxAmount = _maxAmount;
    }

    function updateMaxPoolSize(uint256 _maxPoolSize) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        maxPoolSize = _maxPoolSize;
    }

    /// @dev See {IERC4626-maxAmount}.
    function maxDeposit(address) public view override returns (uint256) {
        return maxAmount;
    }

    /// @dev See {IERC4626-maxMint}.
    function maxMint(address) public view override returns (uint256) {
        return _convertToShares(maxAmount, Math.Rounding.Ceil);
    }

    function getDepositWindow() public view virtual returns (uint256) {
        return DEPOSIT_WINDOW;
    }

    function getLockPeriod() public view virtual returns (uint256) {
        return LOCK_PERIOD;
    }

    function getStartLockPeriod() public view virtual returns (uint256) {
        return startTime + DEPOSIT_WINDOW;
    }

    function getEndLockPeriod() public view virtual returns (uint256) {
        return startTime + DEPOSIT_WINDOW + LOCK_PERIOD;
    }

    /// @dev only changes to deposit, mint, withdraw and redeem functions are to add the isOpen,
    /// isMinAmount, pausable and nonReentrant modifiers
    /// @dev isOpen modifier restricts functions calls to only when the vault is in the deposit window
    /// @dev isMinAmount modifier restricts funtions calls when the amount is less than the minAmount
    /// modifers should not affect ERC4626Upgradeable functionality in any other way.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        isOpen
        isMinAmount(assets)
        nonReentrant
        returns (uint256)
    {
        if (totalSupply() + assets > maxPoolSize) revert PoolMaxSizeReached();
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        isOpen
        isMinAmount(_convertToAssets(shares, Math.Rounding.Ceil))
        nonReentrant
        returns (uint256)
    {
        if (totalSupply() + _convertToAssets(shares, Math.Rounding.Ceil) > maxPoolSize) revert PoolMaxSizeReached();
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        isOpen
        nonReentrant
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        isOpen
        nonReentrant
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function startEpoch() public virtual onlyRole(EPOCH_MANAGER_ROLE) {
        if (block.timestamp < startTime + DEPOSIT_WINDOW + LOCK_PERIOD) revert EpochInProgress();
        startTime = block.timestamp;
        currentEpoch++;
        emit EpochStarted(currentEpoch, block.timestamp);
    }
}

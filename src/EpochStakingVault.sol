// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol"; // could use transient strorage ReentrancyGuardTransientUpgradeable
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EpochStakingVault is
    Initializable,
    ERC4626Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Math for uint256;

    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");
    bytes32 public constant EPOCH_MANAGER_ROLE = keccak256("EPOCH_MANAGER_ROLE");
    bytes32 public constant REWARDS_MANAGER_ROLE = keccak256("REWARDS_MANAGER_ROLE");

    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant DEPOSIT_WINDOW = 7 days;
    uint256 public constant LOCK_PERIOD = 90 days;

    /// @notice custom rewardToken if extending contract to include rewards in non-asset token
    /// @dev can be set to 0x0 for no rewards
    IERC20 public rewardToken;

    uint256 public currentEpoch;
    uint256 public startTime;
    uint256 public minDeposit;
    uint256 public maxDeposit;
    uint256 public maxPoolSize;

    event VaultInitialized(address indexed asset, string name, string symbol);
    event EpochStarted(uint256 indexed epoch, uint256 indexed start);

    error InvalidAsset();
    error EpochLocked();
    error AmountTooLow();
    error EpochInProgress();
    error NotLocked();
    error InvalidClaim();
    error minDepositTooLow();
    error minDepositMustBeLessThanmaxDeposit();
    error ModifyingPoolParametersOutsidePermittedInterval();

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

    modifier isminDeposit(uint256 amount) {
        if (amount < minDeposit) revert AmountTooLow();
        _;
    }

    /// @dev prevent implimentation initialization; only proxy should be initialized
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address contractAdmin,
        address epochManager,
        address rewardsManager,
        uint256 _minDeposit,
        uint256 _maxDeposit,
        uint256 _maxPoolSize,
        IERC20 _RewardToken
    ) public virtual initializer {
        /// Ensure asset is NEXD and ensure asset is decimals 18
        /// Initialize ERC4626 with the staked token (asset)
        /// Initialize the underlying ERC20 (vault token)
        /// Initialize UUPSUpgradeable, PausableUpgradeable and ReentrancyGuardUpgradeable
        /// Grant roles to contractAdmin, epochManager, rewardsManager
        /// Set minDeposit and maxDeposit
        /// if (address(_asset) != address(0x3858567501fbf030BD859EE831610fCc710319f4)) revert InvalidAsset(); uncomment this line in production
        __ERC4626_init(_asset);
        __ERC20_init(_name, _symbol);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(CONTRACT_ADMIN_ROLE, contractAdmin);
        _grantRole(EPOCH_MANAGER_ROLE, epochManager);
        _grantRole(REWARDS_MANAGER_ROLE, rewardsManager);
        minDeposit = _minDeposit;
        maxDeposit = _maxDeposit;
        maxPoolSize = _maxPoolSize;
        rewardToken = _RewardToken;
        emit VaultInitialized(address(_asset), _name, _symbol);
    }
    
    function pause() external virtual onlyRole(CONTRACT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external virtual onlyRole(CONTRACT_ADMIN_ROLE) {
        _unpause();
    }

    function updateMinDeposit(uint256 _minDeposit) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        if (_minDeposit >= maxDeposit) revert minDepositMustBeLessThanmaxDeposit();
        minDeposit = _minDeposit;
    }

    function updateMaxDeposit(uint256 _maxDeposit) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        maxDeposit = _maxDeposit;
    }

    function updateMaxPoolSize(uint256 _maxPoolSize) external virtual isOpen onlyRole(CONTRACT_ADMIN_ROLE) {
        if (block.timestamp > startTime + ONE_DAY) revert ModifyingPoolParametersOutsidePermittedInterval();
        maxPoolSize = _maxPoolSize;
    }

    /// @dev See {IERC4626-maxDeposit}.
    function maxDeposit(address) public view virtual returns (uint256) {
        return maxDeposit;
    }

    /// @dev See {IERC4626-maxMint}.
    function maxMint(address) public view virtual returns (uint256) {
        return _convertToShares(maxDeposit, Math.Rounding.Ceil);
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
    /// isminDeposit, pausable and nonReentrant modifiers
    /// @dev isOpen modifier restricts functions calls to only when the vault is in the deposit window
    /// @dev isminDeposit modifier restricts funtions calls when the amount is less than the minDeposit
    /// modifers should not affect ERC4626Upgradeable functionality in any other way.
    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        isOpen
        isminDeposit(assets)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        isOpen
        isminDeposit(_convertToAssets(shares, Math.Rounding.Ceil))
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        isOpen
        nonReentrant
        whenNotPaused
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
        whenNotPaused
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

    /// @dev restrict upgrades to the contract owner only.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(CONTRACT_ADMIN_ROLE) {}
}

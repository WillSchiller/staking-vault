// SPDX-License-Identifier: MIT 
pragma solidity 0.8.28;

import {EpochStakingVault} from "./EpochStakingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract StableCoinRewardsVault is EpochStakingVault {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public totalRewardsPerShareAccumulator;
    uint256 public claimableRewardsPerShareAccumulator;

    IERC20 public constant REWARD_TOKEN = IERC20(0x7AC8519283B1bba6d683FF555A12318Ec9265229); //update for mainnet

    struct UserInfo {
        uint256 totalRewardsClaimed;
        uint256 rewardsPerShareDebt; 
    }

    mapping(address user => UserInfo) public userInfo;

    event RewardsAdded(uint256 indexed epoch, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    error NoAssetsStaked();
    error NoClaimableRewards();
    error AmountCannotBeZero();

    modifier updateReward(address user) {
        syncToCurrentEpoch();
        UserInfo storage _user = userInfo[user];
        uint256 rewards = claimableRewards(user);
        _user.rewardsPerShareDebt = claimableRewardsPerShareAccumulator;

        if (rewards > 0) {
            _user.totalRewardsClaimed += rewards;
            REWARD_TOKEN.safeTransfer(user, rewards);
            emit RewardsClaimed(user, rewards);
        }
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
    )  EpochStakingVault(_asset, _name, _symbol, _contractAdmin, _epochManager, _rewardsManager, _minAmount, _maxAmount, _maxPoolSize) {
    
    }

    /// Is REWARDS_MANAGER_ROLE redudnant secuirty/ Non issue if someone donates rewards?
    function addRewards(uint256 amount) external onlyRole(REWARDS_MANAGER_ROLE) isLocked {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) revert NoAssetsStaked();
        if (amount == 0) revert AmountCannotBeZero();
        REWARD_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        totalRewardsPerShareAccumulator += amount.mulDiv(1e18, totalSupply, Math.Rounding.Floor);
        emit RewardsAdded(currentEpoch, amount);
    }

    /// ! Could limit to msg.sender == receiver but limits flexibility
    function claimRewards(address receiver) public nonReentrant {
        syncToCurrentEpoch();
        uint256 rewards = claimableRewards(receiver);
        if (rewards == 0) revert NoClaimableRewards();
        UserInfo storage _user = userInfo[receiver];
        _user.rewardsPerShareDebt = claimableRewardsPerShareAccumulator;
        _user.totalRewardsClaimed += rewards;
        REWARD_TOKEN.safeTransfer(receiver, rewards);
        emit RewardsClaimed(receiver, rewards);
    }

    function claimableRewards(address user) public view returns (uint256 rewards) {
        UserInfo memory _user = userInfo[user];
        uint256 _shares = balanceOf(user);
        return _shares.mulDiv(
            claimableRewardsPerShareAccumulator - _user.rewardsPerShareDebt, 1e18, Math.Rounding.Floor
        );
    }

    function allRewards(address user) public view returns (uint256 rewards) {
        UserInfo memory _user = userInfo[user];
        uint256 _shares = balanceOf(user);
        return _shares.mulDiv(totalRewardsPerShareAccumulator - _user.rewardsPerShareDebt, 1e18, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver) public override updateReward(receiver) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override updateReward(receiver) returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        updateReward(owner)
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        updateReward(owner)
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function syncToCurrentEpoch() internal {
        if (
            (block.timestamp < startTime + DEPOSIT_WINDOW
            || block.timestamp > startTime + DEPOSIT_WINDOW + LOCK_PERIOD)
            && totalRewardsPerShareAccumulator != claimableRewardsPerShareAccumulator
        ) 
        {
            claimableRewardsPerShareAccumulator = totalRewardsPerShareAccumulator;
        }
    }
}

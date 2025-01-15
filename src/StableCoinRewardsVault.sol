// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EpochStakingVault} from "./EpochStakingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract StableCoinRewardsVault is EpochStakingVault {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public constant rewardToken = IERC20(0x7AC8519283B1bba6d683FF555A12318Ec9265229); // USDT Arbitrum Sepolia
    uint256 public rewardsPerShareAccumulator;

    struct UserInfo {
        uint256 unclaimedRewards;
        uint256 rewardsPerShareDebt; // maybe should be called rewardsclaimedsnapshot
    }

    mapping(address user => UserInfo) public userInfo;

    // todo add events

    error NoAssetsStaked();
    error NoClaimableRewards();
    error AmountCannotBeZero();

    modifier updateReward(address user) {
        UserInfo storage _user = userInfo[user];
        _user.unclaimedRewards = earned(user);
        _user.rewardsPerShareDebt = rewardsPerShareAccumulator;
        _;
    }

    function initialize(
        IERC20 asset,
        string memory _name,
        string memory _symbol,
        uint256 _minAmount,
        uint256 _maxAmount
    ) public override initializer {
        super.initialize(asset, _name, _symbol, _minAmount, _maxAmount);
    }

    function claimRewards(address receiver) public {
        uint256 rewards = earned(receiver);
        if (rewards == 0) revert NoClaimableRewards();

        UserInfo storage _user = userInfo[receiver];
        _user.rewardsPerShareDebt = rewardsPerShareAccumulator;
        _user.unclaimedRewards = 0;
        rewardToken.safeTransfer(receiver, rewards);
    }

    function earned(address user) public view returns (uint256 rewards) {
        UserInfo memory _user = userInfo[user];
        uint256 _shares = balanceOf(user);
        return _shares.mulDiv(rewardsPerShareAccumulator - _user.rewardsPerShareDebt, 1e27, Math.Rounding.Floor)
            + _user.unclaimedRewards;
    }

    function addRewards(uint256 amount) public onlyOwner isLocked {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) revert NoAssetsStaked();
        if (amount == 0) revert AmountCannotBeZero();

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        rewardsPerShareAccumulator += amount.mulDiv(1e27, totalSupply, Math.Rounding.Floor);
    }

    function deposit(uint256 assets, address receiver) public override updateReward(receiver) returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override updateReward(receiver) returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override updateReward(owner) returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override updateReward(owner) returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }
}

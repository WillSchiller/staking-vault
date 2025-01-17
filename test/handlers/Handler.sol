// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";
import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";
import {StableCoinRewardsVault} from "../../src/StableCoinRewardsVault.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;

    StableCoinRewardsVault public vault;
    ERC20Mock public asset;
    ERC20Mock public rewardToken;
    address public contractAdmin = address(0x0001);
    address public epochManager = address(0x0002);
    address public rewardsManager = address(0x0003);
    uint256 public startTime;
    uint256 public ghost_depositSum;
    uint256 public ghost_donateSum;
    uint256 public ghost_withdrawSum;
    uint256 public ghost_rewardsAdded;
    uint256 public ghost_rewardsClaimed;
    uint256 public ghost_zeroWithdrawals;
    uint256 public ghost_zeroClaims;
    mapping (address user => uint256 rewards) public ghost_rewards_per_user;

 

    mapping(bytes32 => uint256) public calls;
    AddressSet internal _actors;
    address internal currentActor;

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        uint256 actorCount = _actors.count();
        require(actorCount > 0, "No actors available.");

        address picked = _actors.rand(actorIndexSeed);
        // Ensure we don't use the vault address
        if (picked == address(vault)) {
            picked = _actors.rand((actorIndexSeed + 1) % actorCount);
        }

        currentActor = picked;
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor(
        StableCoinRewardsVault _vault,
        ERC20Mock _asset,
        ERC20Mock _rewardToken
    ) {
        vault = _vault;
        asset = _asset;
        rewardToken = _rewardToken;
        startTime = block.timestamp;
    }

    /**
     * @notice Simulate a deposit into the vault.
     */
    function deposit(uint256 amount) public createActor countCall("deposit") {
        amount = bound(amount, 0, 1e24);
        // Mint asset tokens to the actor so they can deposit
        asset.mint(currentActor, amount);

        // Approve & deposit
        vm.startPrank(currentActor);
        asset.approve(address(vault), amount);
        vault.deposit(amount, currentActor);
        vm.stopPrank();

        // Track in ghost variable
        ghost_depositSum += amount;
    }

    /**
     * @notice Withdraw from the vault, picking an existing actor randomly.
     */
    function withdraw(
        uint256 actorSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("withdraw") {
        uint256 userShares = vault.balanceOf(currentActor);
        if (userShares == 0) {
            ghost_zeroWithdrawals++;
            return;
        }

        amount = bound(amount, 0, userShares);
        if (amount == 0) {
            ghost_zeroWithdrawals++;
            return;
        }

        vm.startPrank(currentActor);
        vault.withdraw(amount, currentActor, currentActor);
        vm.stopPrank();

        ghost_withdrawSum += amount;
    }

    /**
     * @notice Claim rewards for a random actor.
     */
    function claimRewards(
        uint256 actorSeed
    ) public useActor(actorSeed) countCall("claimRewards") {
        uint256 earnedBefore = vault.claimableRewards(currentActor);
        if (earnedBefore == 0) {
            ghost_zeroClaims++;
        }

        vm.startPrank(currentActor);
        vault.claimRewards(currentActor);
        vm.stopPrank();

        ghost_rewardsClaimed += earnedBefore;
    }

    /**
     * @notice Add new rewards to the vault
     */
    function addRewards(uint256 rewardAmount) public countCall("addRewards") {
            
        vm.startPrank(rewardsManager);
        rewardAmount = bound(rewardAmount, 100000000, 1000000000000000000); // between 100 and a trillion dollars Assume USDT
        rewardToken.mint(address(rewardsManager), rewardAmount);
        rewardToken.approve(address(vault), rewardAmount);
        vault.addRewards(rewardAmount);
        vm.stopPrank();

        ghost_rewardsAdded += rewardAmount;
    }

    function donateAsset(uint256 amount) public createActor countCall("donateAsset"){
        vm.startPrank(currentActor);
        asset.mint(address(this), amount);
        asset.transfer(address(vault), amount);
        ghost_donateSum += amount;
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
        console.log("withdraw", calls["withdraw"]);
        console.log("claimRewards", calls["claimRewards"]);
        console.log("addRewards", calls["addRewards"]);
        console.log("warpTime", calls["warpTime"]);
        console.log("donateAsset", calls["donateAsset"]);
        console.log("-------------------");

        console.log("Zero withdrawals:", ghost_zeroWithdrawals);
        console.log("Zero claims:", ghost_zeroClaims);
    }

    /**
     * Iterate over all stakers
     */
    function forEachActor(function(address) external func) public {
        _actors.forEach(func);
    }

    function reduceActors(
        uint256 acc,
        function(uint256, address) external returns (uint256) func
    ) public returns (uint256) {
        return _actors.reduce(acc, func);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    // If you do not use ETH-based deposits, you can remove _pay / receive fallback
    function _pay(address to, uint256 amount) internal {
        (bool s, ) = to.call{value: amount}("");
        require(s, "_pay() failed");
    }

    function warpTime() public countCall("warpTime"){
        if (block.timestamp < startTime + 7 days) {
            vm.warp(startTime + 6 days);
        }
        vm.warp(block.timestamp + 30 days);
    }

    receive() external payable {}
}

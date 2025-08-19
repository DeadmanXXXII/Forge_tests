// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";

/// @dev Helper to expose pendingWinnings for test use only
contract GameTestHelper is Game {
    constructor(
        uint256 _initialClaimFee,
        uint256 _gracePeriod,
        uint256 _feeIncreasePercentage,
        uint256 _platformFeePercentage
    ) Game(
        _initialClaimFee,
        _gracePeriod,
        _feeIncreasePercentage,
        _platformFeePercentage
    ) {}

    function setPendingWinnings(address user, uint256 amount) external {
        pendingWinnings[user] = amount;
    }
}

contract GameTest is Test {
    GameTestHelper public game;
    address public deployer;
    address public player1;
    address public maliciousActor;

    uint256 public constant INITIAL_CLAIM_FEE = 0.1 ether;
    uint256 public constant GRACE_PERIOD = 1 days;
    uint256 public constant FEE_INCREASE_PERCENTAGE = 10;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5;

    function setUp() public {
        deployer = makeAddr("deployer");
        player1 = makeAddr("player1");
        maliciousActor = makeAddr("attacker");

        vm.deal(deployer, 10 ether);
        vm.deal(player1, 10 ether);
        vm.deal(maliciousActor, 10 ether);

        vm.startPrank(deployer);
        game = new GameTestHelper(
            INITIAL_CLAIM_FEE,
            GRACE_PERIOD,
            FEE_INCREASE_PERCENTAGE,
            PLATFORM_FEE_PERCENTAGE
        );
        vm.stopPrank();
    }

    function testClaimThrone_RevertIfAlreadyKing() public {
        vm.deal(player1, 1 ether);
        vm.startPrank(player1);

        // First claim should succeed
        game.claimThrone{value: INITIAL_CLAIM_FEE}();

        // Second claim by same player should revert with custom error selector
        vm.expectRevert(abi.encodeWithSelector(Game.AlreadyKing.selector));
        game.claimThrone{value: INITIAL_CLAIM_FEE}();

        vm.stopPrank();
    }

    function testDeclareWinner_RevertIfGracePeriodNotExpired() public {
        vm.deal(player1, 1 ether);
        vm.startPrank(player1);

        game.claimThrone{value: INITIAL_CLAIM_FEE}();

        // Expect revert for grace period not expired custom error
        vm.expectRevert(abi.encodeWithSelector(Game.GracePeriodNotExpired.selector));
        game.declareWinner();

        vm.stopPrank();
    }

    function testConstructor_RevertInvalidGracePeriod() public {
        vm.expectRevert("Game: Grace period must be greater than zero.");
        new Game(
            INITIAL_CLAIM_FEE,
            0,
            FEE_INCREASE_PERCENTAGE,
            PLATFORM_FEE_PERCENTAGE
        );
    }

    function testWithdrawWinnings_Success() public {
        vm.startPrank(player1);

        // Fund contract so it can pay out
        vm.deal(address(game), 5 ether);
        // Set winnings for player1
        game.setPendingWinnings(player1, 1 ether);

        uint256 balanceBefore = player1.balance;
        game.withdrawWinnings();
        uint256 balanceAfter = player1.balance;

        // winnings paid out
        assertEq(balanceAfter, balanceBefore + 1 ether);
        // pending winnings reset to 0
        assertEq(game.pendingWinnings(player1), 0);

        vm.stopPrank();
    }
}

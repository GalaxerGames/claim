// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GALAXER.sol";
import "./CosmicCrucible.sol";

contract Portal is Ownable {
    GALAXER public newToken;
    CosmicCrucible public staker;
    bool public claimWindowClosed;
    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public whitelisted;

    uint256 public constant MAX_CLAIM_AMOUNT = 100000000000 * 10**18;

    constructor(GALAXER _newToken, CosmicCrucible _staker) {
        newToken = _newToken;
        staker = _staker;
    }

function claimNewToken(
    uint256 stakeDuration,
    uint256 amount
) external {
    require(!claimWindowClosed, "TokenMigration: Claim window closed");
    require(
        stakeDuration >= 1 minutes,
        "TokenMigration: Minimum stake duration is 1 minute"
    );
    require(
        !hasClaimed[msg.sender],
        "TokenMigration: User has already claimed"
    );
    require(
        whitelisted[msg.sender],
        "TokenMigration: User is not whitelisted"
    );

    uint256 mult = staker.getMultiplier(stakeDuration); // Calculate multiplier
    uint256 mintAmount = amount * mult;

    require(
        mintAmount <= MAX_CLAIM_AMOUNT,
        "TokenMigration: Claim amount exceeds maximum limit"
    );

    // Mark as claimed
    hasClaimed[msg.sender] = true;

    // Mint new tokens
    newToken.mint(address(staker), mintAmount);

    // Stake new tokens
    staker.stakeTokensFor(msg.sender, mintAmount, stakeDuration);
}



    function mintRemainingTokens() internal {
        require(
            !claimWindowClosed,
            "TokenMigration: Claim window already closed"
        );

        uint256 remainingTokens = newToken.totalSupply() -
            newToken.balanceOf(address(this));

        require(
            remainingTokens > 0,
            "TokenMigration: No remaining tokens to mint"
        );

        // Mint remaining tokens to deployer's address
        newToken.mint(msg.sender, remainingTokens);
        claimWindowClosed = true;
    }

    function whitelistAddresses(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = true;
        }
    }
}
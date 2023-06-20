// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./GLXRToken.sol";
import "./GLXRStaker.sol";

contract GLXRClaim is Ownable {
    GLXRToken public newToken;
    GLXRStaker public staker;
    bytes32 public merkleRoot;
    uint256 public constant claimWindowDuration = 5 days;

    uint256 public claimWindowEndTime;
    bool public claimWindowClosed;
    mapping(bytes32 => bool) public claimed;
    mapping(address => bytes32[]) public merkleProofs;

    constructor(GLXRToken _newToken, GLXRStaker _staker, bytes32 _merkleRoot) {
        newToken = _newToken;
        staker = _staker;
        merkleRoot = _merkleRoot;
        claimWindowEndTime = block.timestamp + claimWindowDuration;
    }

    function claimNewToken(
        uint256 stakeDuration,
        uint256 amount,
        bytes32[] calldata _merkleProof
    ) external {
        require(!claimWindowClosed, "TokenMigration: Claim window closed");
        require(
            stakeDuration >= 90 days,
            "TokenMigration: Minimum stake duration is 90 days"
        );

        // Verify the Merkle proof.
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(claimed[node] == false);
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, node),
            "TokenMigration: Invalid Merkle Proof"
        );

        claimed[node] = true;

        // Mint new tokens
        newToken.mint(msg.sender, amount);

        // Stake new tokens
        staker.stakeTokensFor(msg.sender, amount, stakeDuration);

        if (block.timestamp >= claimWindowEndTime) {
            mintRemainingTokens();
        }
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
}

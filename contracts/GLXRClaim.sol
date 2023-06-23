// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

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
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(GLXRToken _newToken, GLXRStaker _staker, bytes32 _merkleRoot) {
        newToken = _newToken;
        staker = _staker;
        merkleRoot = _merkleRoot;
        claimWindowEndTime = block.timestamp + claimWindowDuration;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function claimNewToken(
        uint256 stakeDuration,
        uint256 index,
        uint256 amount,
        bytes32[] calldata _merkleProof
    ) external {
        require(!claimWindowClosed, "TokenMigration: Claim window closed");
        require(
            stakeDuration >= 90 days,
            "TokenMigration: Minimum stake duration is 90 days"
        );

        require(!isClaimed(index), "index has already been claimed");
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
        require(
            !MerkleProof.verify(_merkleProof, merkleRoot, node),
            "invalid proof"
        );

        // Mark it claimed and send the token.
        _setClaimed(index);
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

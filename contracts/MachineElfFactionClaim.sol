// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MachineElfFactionClaim is AccessControl {
    bytes32 public merkleRoot;
    mapping(address => mapping(uint256 => bool)) public claimed;

    IERC1155 public machineElfFaction;

    event Claimed(address indexed user, uint256 indexed factionId);

    constructor(IERC1155 _machineElfFaction, bytes32 _merkleRoot) {
        machineElfFaction = _machineElfFaction;
        merkleRoot = _merkleRoot;
    }

    function claim(
        uint256 index,
        uint256 factionId,
        bytes32[] calldata merkleProof
    ) external {
        require(!claimed[msg.sender][factionId], "Already claimed");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid merkle proof"
        );

        // Mark it as claimed and send the token.
        claimed[msg.sender][factionId] = true;
        machineElfFaction.safeTransferFrom(
            address(this),
            msg.sender,
            factionId,
            1,
            ""
        );

        emit Claimed(msg.sender, factionId);
    }

    function isClaimed(
        address user,
        uint256 factionId
    ) external view returns (bool) {
        return claimed[user][factionId];
    }
}

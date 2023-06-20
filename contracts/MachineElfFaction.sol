// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MachineElfFaction is ERC1155, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public currentTokenId = 1;
    string public factionName;

    constructor(
        string memory uri,
        address admin,
        string memory _factionName
    ) ERC1155(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, admin);
        factionName = _factionName;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, currentTokenId, amount, "");
        currentTokenId++;
    }

    function mintBatch(
        address to,
        uint256[] memory amounts
    ) public onlyRole(MINTER_ROLE) {
        uint256[] memory ids = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            ids[i] = currentTokenId;
            currentTokenId++;
        }
        _mintBatch(to, ids, amounts, "");
    }

    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract MachineElfFactory {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function createFaction(
        string memory uri,
        string memory factionName
    ) public returns (MachineElfFaction) {
        MachineElfFaction faction = new MachineElfFaction(
            uri,
            admin,
            factionName
        );
        return faction;
    }
}

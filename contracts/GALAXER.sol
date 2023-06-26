// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GALAXER is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");
    uint256 public constant MAX_SUPPLY = 100 * 10**12 * 10**18; // 100 Trillion tokens with 18 decimals

    bool private _paused;

    function initialize() public initializer {
        __ERC20_init("Galaxer", "GLXR");
        __Ownable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        _paused = false;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    require(totalSupply() + amount <= MAX_SUPPLY, "ERC20: minting would exceed max supply");
    _mint(to, amount);
}


    function pause() external onlyRole(PAUSER_ROLE) {
        _paused = true;
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _paused = false;
    }

    function blacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BLACKLISTED_ROLE, account);
    }

    function unblacklist(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BLACKLISTED_ROLE, account);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        require(!_paused, "ERC20Pausable: token transfer while paused");
        require(
            !hasRole(BLACKLISTED_ROLE, from),
            "ERC20Blacklist: sender account is blacklisted"
        );
        require(
            !hasRole(BLACKLISTED_ROLE, to),
            "ERC20Blacklist: recipient account is blacklisted"
        );
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override nonReentrant returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override nonReentrant returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }
}

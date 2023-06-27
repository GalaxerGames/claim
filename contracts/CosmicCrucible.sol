// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract NebulaNote is ERC20Capped, ERC20Burnable, Ownable {
    address public minter;

    constructor() ERC20("Nebula Note", "NEBULAE") ERC20Capped(100000000000000 * 10**18) {
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mintTo(address to, uint256 amount) external {
        require(msg.sender == minter, "Only minter can mint");
        _mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
}

contract CosmicCrucible is Context, Ownable, ReentrancyGuard, Pausable, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant STAKER_ROLE = keccak256("STAKER_ROLE");

    IERC20 private token;
    NebulaNote private nebulaNoteInstance;
    address private penaltyAddress;

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public stakedTimestamp;
    mapping(address => uint256) public stakedAmountOfNebulae;
    mapping(address => bool) public isStakeholder;

    uint256 public totalStakedAmount;

    event TokensStaked(address indexed user, uint256 amount, uint256 duration);
    event TokensUnstaked(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

constructor(IERC20 _token, address _adminAddress, address _penaltyAddress) {
    require(_adminAddress != address(0), "Admin address must be a valid address");
    _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
    _setRoleAdmin(STAKER_ROLE, DEFAULT_ADMIN_ROLE);

    require(_penaltyAddress != address(0), "Penalty address must be a valid address");

    token = _token;
    nebulaNoteInstance = new NebulaNote();
    nebulaNoteInstance.setMinter(address(this));
    penaltyAddress = _penaltyAddress;
}


    modifier onlyStaker() {
        require(hasRole(STAKER_ROLE, _msgSender()), "Caller is not a staker");
        _;
    }

    modifier validDuration(uint256 _duration) {
        require(
            _duration == 1 minutes ||
            _duration == 90 days ||
            _duration == 180 days ||
            _duration == 270 days ||
            _duration == 365 days,
            "Invalid duration"
        );
        _;
    }

    function changeAdmin(address newAdmin) public onlyOwner {
    grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
}

    function addStaker(address newStaker) public onlyOwner {
        grantRole(STAKER_ROLE, newStaker);
    }

    function removeStaker(address staker) public onlyOwner {
        revokeRole(STAKER_ROLE, staker);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner whenPaused {
        require(totalStakedAmount > 0, "Nothing to withdraw");
        token.safeTransfer(_msgSender(), totalStakedAmount);
        totalStakedAmount = 0;

        emit EmergencyWithdraw(_msgSender(), totalStakedAmount);
    }

    // Add the new function here
    function changeMinter(address _newMinter) external onlyOwner {
        nebulaNoteInstance.setMinter(_newMinter);
    }

    // And the withdrawNebulaNotes function
    function withdrawNebulaNotes(address to, uint256 amount) external onlyOwner {
        uint256 nebulaBalance = nebulaNoteInstance.balanceOf(address(this));
        require(nebulaBalance >= amount, "Not enough Nebula Notes in contract");
        nebulaNoteInstance.transfer(to, amount);
    }
function stakeTokensFor(
    address forWhom,
    uint256 amount,
    uint256 duration
) external onlyStaker validDuration(duration) whenNotPaused nonReentrant {
    // If the user is not already a stakeholder or their previous stake has ended, allow them to stake again
    if (!isStakeholder[forWhom] || block.timestamp >= stakedTimestamp[forWhom].add(stakedDuration[forWhom])) {
        isStakeholder[forWhom] = true;
        stakedDuration[forWhom] = duration;
        stakedTimestamp[forWhom] = block.timestamp;
    }

    // Add the new stake amount
    stakedAmount[forWhom] = stakedAmount[forWhom].add(amount);
    totalStakedAmount = totalStakedAmount.add(amount);

    uint256 nebulaeAmount = amount.mul(getMultiplier(duration));
    stakedAmountOfNebulae[forWhom] = stakedAmountOfNebulae[forWhom].add(nebulaeAmount);

    token.safeTransferFrom(_msgSender(), address(this), amount);
    nebulaNoteInstance.mintTo(forWhom, nebulaeAmount);

    emit TokensStaked(forWhom, amount, duration);
}


function stakeTokens(uint256 _amount, uint256 _duration) external validDuration(_duration) whenNotPaused nonReentrant {
    require(_amount > 0, "Amount must be greater than zero");

    uint256 mult = getMultiplier(_duration);
    _amount = _amount * mult;

    // If the user is not already a stakeholder or their previous stake has ended, allow them to stake again
    if (!isStakeholder[_msgSender()] || block.timestamp >= stakedTimestamp[_msgSender()].add(stakedDuration[_msgSender()])) {
        isStakeholder[_msgSender()] = true;
        stakedDuration[_msgSender()] = _duration;
        stakedTimestamp[_msgSender()] = block.timestamp;
    }

    // Add the new stake amount
    stakedAmount[_msgSender()] += _amount;
    totalStakedAmount += _amount;

    // Mint Nebula Note tokens to the sender
    uint256 nebulaeAmount = _amount;
    stakedAmountOfNebulae[_msgSender()] = stakedAmountOfNebulae[_msgSender()].add(nebulaeAmount);

    token.safeTransferFrom(_msgSender(), address(this), _amount);
    nebulaNoteInstance.mintTo(_msgSender(), nebulaeAmount);

    emit TokensStaked(_msgSender(), _amount, _duration);
}


function unstakeTokens() external whenNotPaused nonReentrant {
    require(isStakeholder[_msgSender()] == true, "You do not have any staked tokens");
    uint256 timeElapsed = block.timestamp - stakedTimestamp[_msgSender()];
    uint256 amount = stakedAmount[_msgSender()];
    uint256 penaltyAmount = 0;

    // If the time elapsed is less than the staking duration, calculate penalty
    if (timeElapsed < stakedDuration[_msgSender()]) {
        penaltyAmount = calculatePenaltyAmount(
            amount,
            stakedDuration[_msgSender()],
            timeElapsed
        );
    }
    uint256 unstakeAmount = amount - penaltyAmount;
    stakedAmount[_msgSender()] = 0;
    totalStakedAmount = totalStakedAmount.sub(amount);
    isStakeholder[_msgSender()] = false;

    nebulaNoteInstance.burn(stakedAmountOfNebulae[_msgSender()]);
    stakedAmountOfNebulae[_msgSender()] = 0;

    // Transfer the penalty amount to the penaltyAddress
    if (penaltyAmount > 0) {
        token.safeTransfer(penaltyAddress, penaltyAmount);
    }
    // Unstake the tokens after applying penalty
    token.safeTransfer(_msgSender(), unstakeAmount);

    emit TokensUnstaked(_msgSender(), unstakeAmount);
}

    function calculatePenaltyAmount(
        uint256 _amount,
        uint256 _duration,
        uint256 _timeElapsed
    ) private pure returns (uint256) {
        uint256 penaltyPercentage = calculatePenaltyPercentage(
            _duration,
            _timeElapsed
        );
        return (_amount * penaltyPercentage) / 100;
    }

    function calculatePenaltyPercentage(
        uint256 _duration,
        uint256 _timeElapsed
    ) private pure returns (uint256) {
        if (_timeElapsed >= _duration) {
            return 0;
        }
        if (_duration == 90 days) {
            if (_timeElapsed < 45 days) {
                return 50;
            }
            return 25;
        }
        if (_duration == 180 days) {
            if (_timeElapsed < 90 days) {
                return 50;
            }
            return 25;
        }
        if (_duration == 270 days) {
            if (_timeElapsed < 135 days) {
                return 50;
            }
            return 25;
        }
        if (_duration == 365 days) {
            if (_timeElapsed < 182 days) {
                return 50;
            }
            return 25;
        }
        return 0;
    }

    function getMultiplier(uint256 duration) public pure returns (uint256) {
        if (duration == 90 days) {
            return 10;
        } else if (duration == 1 minutes) {
            return 2;
        } else if (duration == 180 days) {
            return 100;
        }  else if (duration == 270 days) {
            return 1000;
        } else if (duration == 365 days) {
            return 2000;
        } else {
            revert("Invalid staking duration");
        }
    }

    function setPenaltyAddress(address _penaltyAddress) external onlyOwner {
        penaltyAddress = _penaltyAddress;
    }

    function getStakedAmount(address _address) external view returns (uint256) {
        return stakedAmount[_address];
    }

    function getStakedDuration(
        address _address
    ) external view returns (uint256) {
        return stakedDuration[_address];
    }

    function getStakedTimestamp(
        address _address
    ) external view returns (uint256) {
        return stakedTimestamp[_address];
    }

    function getTotalStakedAmount() external view returns (uint256) {
        return totalStakedAmount;
    }
}

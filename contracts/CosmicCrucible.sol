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

     // The staker address
    address public staker;

    uint256 public totalStakedAmount;

    event TokensStaked(address indexed user, uint256 amount, uint256 duration);
    event TokensUnstaked(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

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

     function changeStaker(address newStaker) external onlyOwner {
        require(newStaker != address(0), "New staker must be a valid address");
        staker = newStaker;
    }

   function addPauser(address _newPauser) external onlyOwner {
    grantRole(PAUSER_ROLE, _newPauser);
    }

    modifier onlyPauser() {
    require(hasRole(PAUSER_ROLE, _msgSender()), "Caller is not a pauser");
    _;
    }

    function pause() external onlyPauser {
    _pause();
    }

    function unpause() external onlyPauser {
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
    address beneficiary,
    uint256 _amount,
    uint256 _duration
) external nonReentrant onlyStaker {
    require(beneficiary != address(0), "Beneficiary must be valid address");
    require(_amount > 0, "Amount must be greater than zero");
    require(
        _duration == 1 minutes ||
        _duration == 90 days ||
            _duration == 180 days ||
            _duration == 270 days ||
            _duration == 365 days,
        "Invalid duration"
    );
    // Check if beneficiary is already a stakeholder, if not, set to true
    if (!isStakeholder[beneficiary]) {
        isStakeholder[beneficiary] = true;
    }

    stakedAmount[beneficiary] += _amount;
    stakedDuration[beneficiary] = _duration;
    stakedTimestamp[beneficiary] = block.timestamp;
    totalStakedAmount += _amount;

    nebulaNoteInstance.mintTo(beneficiary, _amount);

    emit TokensStaked(beneficiary, _amount, _duration);
}


function stakeTokens(uint256 amount, uint256 duration) external validDuration(duration) whenNotPaused nonReentrant {
    require(amount > 0, "Amount must be greater than zero");

    // Calculate the multiplier based on the staking duration
    uint256 multiplier = getMultiplier(duration);

    // Multiply the GLXR stake amount by the multiplier
    uint256 glxrAmount = amount.mul(multiplier);

    // If the user is not already a stakeholder, allow them to stake
    if (!isStakeholder[_msgSender()]) {
        isStakeholder[_msgSender()] = true;
        stakedDuration[_msgSender()] = duration;
        stakedTimestamp[_msgSender()] = block.timestamp;
    }

    // Add the new stake amount of GLXR
    stakedAmount[_msgSender()] = stakedAmount[_msgSender()].add(glxrAmount);
    totalStakedAmount = totalStakedAmount.add(glxrAmount);

    // Set the Nebula Notes amount equal to the GLXR stake amount
    uint256 nebulaeAmount = glxrAmount;
    stakedAmountOfNebulae[_msgSender()] = stakedAmountOfNebulae[_msgSender()].add(nebulaeAmount);

    token.safeTransferFrom(_msgSender(), address(this), amount);
    nebulaNoteInstance.mintTo(_msgSender(), nebulaeAmount);

    emit TokensStaked(_msgSender(), glxrAmount, duration);
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

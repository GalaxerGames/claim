// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NebulaNote is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Nebula Notes", "NEBULAE") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("Transfers are disabled");
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("Transfers are disabled");
    }
}

contract CosmicCrucible is Context, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 private token;
    NebulaNote private NebulaNoteInstance;
    address private penaltyAddress;

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public stakedTimestamp;
    uint256 public totalStakedAmount;

    // The staker address
    address public staker;

    event TokensStaked(address indexed user, uint256 amount, uint256 duration);
    event TokensUnstaked(address indexed user, uint256 amount);

    constructor(IERC20 _token) {
        token = _token;
        NebulaNoteInstance = new NebulaNote();

        // Initialize staker as the contract deployer
        staker = _msgSender();
    }

    modifier onlyStaker() {
        require(_msgSender() == staker, "Only staker can call this function.");
        _;
    }

    function changeStaker(address newStaker) external onlyOwner {
        require(newStaker != address(0), "New staker must be a valid address");
        staker = newStaker;
    }

function stakeTokensFor(
    address beneficiary,
    uint256 _amount,
    uint256 _duration
) external nonReentrant onlyStaker {
    require(beneficiary != address(0), "Beneficiary must be valid address");
    require(_amount > 0, "Amount must be greater than zero");
    require(
        _duration == 90 days ||
            _duration == 180 days ||
            _duration == 270 days ||
            _duration == 365 days,
        "Invalid duration"
    );

    stakedAmount[beneficiary] += _amount;
    stakedDuration[beneficiary] = _duration;
    stakedTimestamp[beneficiary] = block.timestamp;
    totalStakedAmount += _amount;

    NebulaNoteInstance.mint(beneficiary, _amount);

    emit TokensStaked(beneficiary, _amount, _duration);
}


function stakeTokens(uint256 _amount, uint256 _duration) external nonReentrant {
    require(_amount > 0, "Amount must be greater than zero");
    require(
        _duration == 90 days ||
        _duration == 180 days ||
        _duration == 270 days ||
        _duration == 365 days,
        "Invalid duration"
    );
    uint256 mult = getMultiplier(_duration);  // Removed 'staker.' prefix
    _amount = _amount * mult;
    token.safeTransferFrom(_msgSender(), address(this), _amount);

    stakedAmount[_msgSender()] += _amount;
    stakedDuration[_msgSender()] = _duration;
    stakedTimestamp[_msgSender()] = block.timestamp;
    totalStakedAmount += _amount;

    NebulaNoteInstance.mint(_msgSender(), _amount);

    emit TokensStaked(_msgSender(), _amount, _duration);
}


 function unstakeTokens() external nonReentrant {
    uint256 stakedAmount_ = stakedAmount[_msgSender()];
    require(stakedAmount_ > 0, "No tokens staked");

    uint256 stakedDuration_ = stakedDuration[_msgSender()];
    uint256 timeElapsed = block.timestamp - stakedTimestamp[_msgSender()];
    require(timeElapsed >= stakedDuration_, "Stake duration not reached");

    // Burn all Nebula Notes associated with the user
    uint256 nebulaNotesToBurn = NebulaNoteInstance.balanceOf(_msgSender());
    NebulaNoteInstance.burnFrom(_msgSender(), nebulaNotesToBurn);

    uint256 penaltyAmount = calculatePenaltyAmount(
        stakedAmount_,
        stakedDuration_,
        timeElapsed
    );
    uint256 unstakedAmount = stakedAmount_ - penaltyAmount;

    delete stakedAmount[_msgSender()];
    delete stakedDuration[_msgSender()];
    delete stakedTimestamp[_msgSender()];
    totalStakedAmount -= stakedAmount_;

    token.safeTransfer(_msgSender(), unstakedAmount);
    if (penaltyAmount > 0) {
        token.safeTransfer(penaltyAddress, penaltyAmount);
    }

    emit TokensUnstaked(_msgSender(), unstakedAmount);
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
    } else if (duration == 180 days) {
        return 100;
    } else if (duration == 270 days) {
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

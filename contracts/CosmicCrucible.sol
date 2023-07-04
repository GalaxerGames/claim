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
    CosmicCrucible public cosmicCrucibleInstance;

    constructor() ERC20("Nebula Note", "NEBULAE") ERC20Capped(100000000000000 * 10**18) {
    }

    function setMinter(address _minter) external onlyOwner {
    require(minter == address(0), "Minter already set");
    minter = _minter;
    }

    function setCosmicCrucibleInstance(CosmicCrucible _cosmicCrucibleInstance) external onlyOwner {
    require(address(cosmicCrucibleInstance) == address(0), "CosmicCrucibleInstance already set");
    cosmicCrucibleInstance = _cosmicCrucibleInstance;
    }
    function mintTo(address to, uint256 amount) external {
        require(msg.sender == minter, "Only minter can mint");
        _mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0)) {
            // Transfer staking rights
            cosmicCrucibleInstance.transferStakingRights(from, to, amount);
        }
    }
}


contract CosmicCrucible is Context, Ownable, ReentrancyGuard, Pausable, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant STAKER_ROLE = keccak256("STAKER_ROLE");

    IERC20 private token;
    NebulaNote private nebulaNoteInstance;
    address private penaltyAddress;
    uint256 public currentMintId = 0;


    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakedDuration;
    mapping(address => uint256) public stakedTimestamp;
    mapping(address => uint256) public stakedAmountOfNebulae;
    mapping(address => bool) public isStakeholder;
    // Map a staked amount of GLXR to a specific Nebula Note
    mapping(uint256 => uint256) public nebulaNoteToGLXR;
    // Mapping from minting ID to the equivalent staked GLXR amount
    mapping(uint256 => uint256) public mintIdToGLXR;
    // Mapping from user to the last minting ID
    mapping(address => uint256) public lastMintId;

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
    nebulaNoteInstance.setCosmicCrucibleInstance(this);
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

    // Change minter address for NN
    function changeMinter(address _newMinter) external onlyOwner {
        require(_newMinter != address(0), "New minter address is not valid");
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

    // Calculate the multiplier based on the staking duration
    uint256 multiplier = getMultiplier(_duration);

    // Multiply the GLXR stake amount by the multiplier
    uint256 glxrAmount = _amount.mul(multiplier);

    stakedAmount[beneficiary] += glxrAmount;
    stakedDuration[beneficiary] = _duration;
    stakedTimestamp[beneficiary] = block.timestamp;
    totalStakedAmount += glxrAmount;

    // Mint Nebula Notes equal to the GLXR stake amount
    nebulaNoteInstance.mintTo(beneficiary, _amount);

    // Increase the mintId
    currentMintId += 1;
    
    // Set equivalent staked GLXR amount for the minted Nebula Note with the mintId
    mintIdToGLXR[currentMintId] = glxrAmount;
    
    // Update the last mintId for the beneficiary
    lastMintId[beneficiary] = currentMintId;

    emit TokensStaked(beneficiary, glxrAmount, _duration);
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

    token.safeTransferFrom(_msgSender(), address(this), amount);

    // Mint Nebula Notes equal to the GLXR stake amount
    nebulaNoteInstance.mintTo(_msgSender(), amount);

    // Increase the mintId
    currentMintId += 1;

    // Set equivalent staked GLXR amount for the minted Nebula Note with the mintId
    mintIdToGLXR[currentMintId] = glxrAmount;
    
    // Update the last mintId for the sender
    lastMintId[_msgSender()] = currentMintId;

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

    function transferStakingRights(address from, address to, uint256 amount) external {
    require(msg.sender == address(nebulaNoteInstance), "Only NebulaNote can initiate transfer");
    
    uint256 glxrAmount = nebulaNoteToGLXR[amount];
    
    // Reduce the GLXR stake amount from the sender
    stakedAmount[from] = stakedAmount[from].sub(glxrAmount);

    // Increase the GLXR stake amount for the recipient
    stakedAmount[to] = stakedAmount[to].add(glxrAmount);
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

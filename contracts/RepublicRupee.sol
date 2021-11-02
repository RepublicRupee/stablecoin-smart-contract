// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RepublicRupee is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant CHIEF_ROLE = keccak256("CHIEF_ROLE");
    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    mapping(address => bool) public isBlackListed;
    event AddedBlackList(address _who, uint256 _when);
    event RemovedBlackList(address _who, uint256 _when);
    event DestroyedBlackFunds(address _who, uint256 _howmuch, uint256 _when);

    constructor() initializer {}

    function initialize(
        address _admin,
        address _governance,
        address _operator,
        address _minter
    ) public initializer {
        __ERC20_init("RepublicRupee", "RINR");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(GOVERNANCE_ROLE, _governance);
        _setupRole(CHIEF_ROLE, _operator);
        _setupRole(BANK_ROLE, _minter);
    }

    function pause() public onlyRole(GOVERNANCE_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    function superMint(address to, uint256 amount) public onlyRole(BANK_ROLE) {
        _mint(to, amount);
    }

    function mint(address _to, uint256 _amount) external onlyRole(TREASURY_ROLE) {
        _mint(to, amount);
    }
    
    function addBlackList(address _who) public onlyRole(CHIEF_ROLE) {
        isBlackListed[_who] = true;
        emit AddedBlackList(_who, block.number);
    }

    function removeBlackList(address _who) public onlyRole(CHIEF_ROLE) {
        isBlackListed[_who] = false;
        emit RemovedBlackList(_who, block.number);
    }

    function getBlackListStatus(address _who) external view returns (bool) {
        return isBlackListed[_who];
    }

    function burnBlackFunds(address _blackListedUser)
        public
        onlyRole(CHIEF_ROLE)
    {
        require(
            isBlackListed[_blackListedUser],
            "BurnBlackFunds:: Blacklist user before destroy funds"
        );
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        _burn(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds, block.number);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!isBlackListed[from], "BeforeTokenTransfer:: User blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }
}
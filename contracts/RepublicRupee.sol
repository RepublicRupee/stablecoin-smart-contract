// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Libraries.sol";

contract RepublicRupee is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using StringLibrary for string;
    using UintLibrary for uint256;

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant CHIEF_ROLE = keccak256("CHIEF_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    event AddedBlackList(address _who, uint256 _when);
    event RemovedBlackList(address _who, uint256 _when);
    event DestroyedBlackFunds(address _who, uint256 _howmuch, uint256 _when);
    event KYCCompleted(address _who, uint256 _when);
    event AddedNewERC20(address _token, uint256 _when, address _who);
    event RemovedERC20(address _token, uint256 _when, address _who);

    mapping(address => bool) public isIntruder;
    mapping(address => bool) public kycStatus;
    mapping(address => bool) public isAllowedForCollateral;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor() initializer {}

    function initialize(
        address _god,
        address _king,
        address _cheif,
        address _treasury,
        address _guarian
    ) public initializer {
        __ERC20_init("RepublicRupee", "RINR");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _god);
        _setupRole(GOVERNANCE_ROLE, _king);
        _setupRole(CHIEF_ROLE, _cheif);
        _setupRole(TREASURY_ROLE, _treasury);
        _setupRole(GUARDIAN_ROLE, _guarian);
    }

    function pause() public onlyRole(GOVERNANCE_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(GOVERNANCE_ROLE) {
        _unpause();
    }

    function superMint(address to, uint256 amount)
        external
        onlyRole(TREASURY_ROLE)
    {
        _mint(to, amount);
    }

    function buy(
        address _collateral,
        uint256 _amount,
        Sig memory _guardianSign
    ) external {
        require(
            isAllowedForCollateral[_collateral],
            "Buy:: Unsupported Collateral Token"
        );
        if (kycStatus[msg.sender]) {
            _buy(_collateral, _amount);
        } else {
            require(isKYCVerified(_guardianSign), "Buy: Please Complete KYC");
            updateKYCStatus();
            _buy(_collateral, _amount);
        }
    }

    function _buy(address _collateral, uint256 _amount) internal {
        // TODO
    }

    function updateKYCStatus() internal {
        kycStatus[msg.sender] = true;
        emit KYCCompleted(msg.sender, block.timestamp);
    }

    function isKYCVerified(Sig memory _guardian) internal view returns (bool) {
        bytes memory _guardianMsg = abi.encodePacked(
            msg.sender,
            address(this),
            block.chainid
        );
        address _signedBy = StringLibrary.getAddress(
            _guardianMsg,
            _guardian.v,
            _guardian.r,
            _guardian.s
        );
        return hasRole(GUARDIAN_ROLE, _signedBy);
    }

    function getMessage() external view returns (bytes memory) {
        return abi.encodePacked(msg.sender, address(this), block.chainid);
    }

    function allowNewCollateralERC20(address _erc20Token)
        external
        onlyRole(GUARDIAN_ROLE)
    {
        isAllowedForCollateral[_erc20Token] = true;
        emit AddedNewERC20(_erc20Token, block.timestamp, msg.sender);
    }

    function removeExistingERC20Collateral(address _erc20Token)
        external
        onlyRole(GUARDIAN_ROLE)
    {
        isAllowedForCollateral[_erc20Token] = false;
        emit RemovedERC20(_erc20Token, block.timestamp, msg.sender);
    }

    function addBlackList(address _who) external onlyRole(CHIEF_ROLE) {
        isIntruder[_who] = true;
        kycStatus[_who] = false;
        emit AddedBlackList(_who, block.timestamp);
        emit KYCCompleted(_who, block.timestamp);
    }

    function removeBlackList(address _who) external onlyRole(CHIEF_ROLE) {
        isIntruder[_who] = false;
        emit RemovedBlackList(_who, block.timestamp);
    }

    function getBlackListStatus(address _who) external view returns (bool) {
        return isIntruder[_who];
    }

    function burnBlackFunds(address _blackListedUser)
        public
        onlyRole(CHIEF_ROLE)
    {
        require(
            isIntruder[_blackListedUser],
            "BurnBlackFunds:: Blacklist user before destroy funds"
        );
        uint256 dirtyFunds = balanceOf(_blackListedUser);
        _burn(_blackListedUser, dirtyFunds);
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds, block.timestamp);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!isIntruder[from], "BeforeTokenTransfer:: User blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }
}

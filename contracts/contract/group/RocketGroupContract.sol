pragma solidity 0.5.0;

// Interfaces
import "../../interface/RocketStorageInterface.sol";
import "../../interface/settings/RocketGroupSettingsInterface.sol";


/// @title The contract for a group that operates in Rocket Pool, holds the entities fees and more
/// @author David Rugendyke

contract RocketGroupContract {

    /**** Properties ***********/

    address public owner;                                                       // The group owner that created the contract
    uint8   public version;                                                     // Version of this contract
    uint256 private feePerc = 0;                                                // The fee this groups charges their users given as a % of 1 Ether (eg 0.02 ether = 2%)
    uint256 private feePercRocketPool = 0;                                      // The fee Rocket Pool charges this group's users given as a % of 1 Ether (eg 0.02 ether = 2%)
    address private feeAddress;                                                 // The address to send group fees to as RPB

    mapping(address => bool) private depositors;                                // Valid depositor contracts for the group
    uint256 private depositorCount = 0;
    mapping(address => bool) private withdrawers;                               // Valid withdrawer contracts for the group
    uint256 private withdrawerCount = 0;


    /*** Contracts ***************/

    RocketStorageInterface rocketStorage = RocketStorageInterface(0);           // The main Rocket Pool storage contract where primary persistant storage is maintained
    RocketGroupSettingsInterface rocketGroupSettings = RocketGroupSettingsInterface(0);

    /*** Events ******************/


    event DepositorAdd (
        address indexed _depositor,
        uint256 added
    );

    event DepositorRemove (
        address indexed _depositor,
        uint256 removed
    );

    event WithdrawerAdd (
        address indexed _withdrawer,
        uint256 added
    );

    event WithdrawerRemove (
        address indexed _withdrawer,
        uint256 removed
    );


    /*** Modifiers ***************/

    /**
    * @dev Throws if not called by RocketGroupAPI.
    */
    modifier onlyRocketGroupAPI() {
        require(msg.sender == rocketStorage.getAddress(keccak256(abi.encodePacked("contract.name", "rocketGroupAPI"))), "Only the RocketGroupAPI contract can perform this function.");
        _;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyGroupOwner() {
        require(msg.sender == owner, "Only the group owner account can perform this function.");
        _;
    }

    /**
    * @dev Throws if fee percentage is invalid.
    */
    modifier onlyValidFeePerc(uint256 _stakingFeePerc) {
        require(_stakingFeePerc <= 1 ether, "User fee cannot be greater than 100%.");
        _;
    }
    modifier onlyValidFeePercRocketPool(uint256 _stakingFeePercRocketPool) {
        rocketGroupSettings = RocketGroupSettingsInterface(rocketStorage.getAddress(keccak256(abi.encodePacked("contract.name", "rocketGroupSettings"))));
        require(_stakingFeePercRocketPool <= rocketGroupSettings.getMaxFee(), "Rocket Pool fee is above maximum amount.");
        _;
    }

     
    /*** Constructor *************/

    /// @dev RocketGroupContract constructor
    constructor(address _rocketStorageAddress, address _owner, uint256 _stakingFeePerc) public onlyValidFeePerc(_stakingFeePerc) {
        // Version
        version = 1;
        // Update the storage contract address
        rocketStorage = RocketStorageInterface(_rocketStorageAddress);
        // Set the group owner
        owner = _owner;
        // Set the staking fee percent
        feePerc = _stakingFeePerc;
        // Set the RP staking fee percent
        rocketGroupSettings = RocketGroupSettingsInterface(rocketStorage.getAddress(keccak256(abi.encodePacked("contract.name", "rocketGroupSettings"))));
        feePercRocketPool = rocketGroupSettings.getDefaultFee();
        // Default the fee address to the group owner
        feeAddress = _owner;
    }

    /*** Getters *************/

    /// @dev Get the group owner
    function getOwner() public view returns(address) {
        return owner;
    }

    /// @dev The fee this groups charges their users given as a % of 1 Ether (eg 0.02 ether = 2%)
    function getFeePerc() public view returns(uint256) {
        return feePerc;
    }

    /// @dev Get the fee that Rocket Pool charges for this group given as a % of 1 Ether (eg 0.02 ether = 2%)
    function getFeePercRocketPool() public view returns(uint256) {
        return feePercRocketPool;
    }

    /// @dev Get the address to send group fees to as RPB
    function getFeeAddress() public view returns(address) {
        return feeAddress;
    }

    /// @dev Check that a depositor exists in the group
    function hasDepositor(address _depositorAddress) public view returns (bool) {
        return depositors[_depositorAddress];
    }

    /// @dev Check that a withdrawer exists in the group
    function hasWithdrawer(address _withdrawerAddress) public view returns (bool) {
        return withdrawers[_withdrawerAddress];
    }


    /*** Setters *************/

    /// @dev Set the fee this group charges their users - Given as a % of 1 Ether (eg 0.02 ether = 2%)
    function setFeePerc(uint256 _stakingFeePerc) public onlyGroupOwner onlyValidFeePerc(_stakingFeePerc) returns(bool) {
        feePerc = _stakingFeePerc;
        return true;
    }

    /// @dev Set the fee Rocket Pool charges this group's users - Given as a % of 1 Ether (eg 0.02 ether = 2%)
    function setFeePercRocketPool(uint256 _stakingFeePercRocketPool) public onlyRocketGroupAPI onlyValidFeePercRocketPool(_stakingFeePercRocketPool) returns(bool) {
        feePercRocketPool = _stakingFeePercRocketPool;
        return true;
    }

    /// @dev Set the address to send group fees to as RPB
    function setFeeAddress(address _feeAddress) public onlyGroupOwner returns(bool) {
        require(_feeAddress != address(0x0), "Invalid fee address");
        feeAddress = _feeAddress;
        return true;
    }


    /*** Methods *************/


    /// @dev Add a depositor contract
    function addDepositor(address _depositorAddress) public onlyGroupOwner {
        require(!depositors[_depositorAddress], "Depositor already exists in the group");
        depositors[_depositorAddress] = true;
        ++depositorCount;
        emit DepositorAdd(_depositorAddress, now);
    }


    /// @dev Remove a depositor contract
    function removeDepositor(address _depositorAddress) public onlyGroupOwner {
        require(depositors[_depositorAddress], "Depositor does not exist in the group");
        depositors[_depositorAddress] = false;
        --depositorCount;
        emit DepositorRemove(_depositorAddress, now);
    }


    /// @dev Add a withdrawer contract
    function addWithdrawer(address _withdrawerAddress) public onlyGroupOwner {
        require(!withdrawers[_withdrawerAddress], "Withdrawer already exists in the group");
        withdrawers[_withdrawerAddress] = true;
        ++withdrawerCount;
        emit WithdrawerAdd(_withdrawerAddress, now);
    }


    /// @dev Remove a withdrawer contract
    /// @dev The last withdrawer contract cannot be removed - at least one must always remain
    function removeWithdrawer(address _withdrawerAddress) public onlyGroupOwner {
        require(withdrawers[_withdrawerAddress], "Withdrawer does not exist in the group");
        require(withdrawerCount > 1, "The last withdrawer in the group cannot be removed");
        withdrawers[_withdrawerAddress] = false;
        --withdrawerCount;
        emit WithdrawerRemove(_withdrawerAddress, now);
    }


}

pragma solidity 0.5.0;


contract RocketMinipoolFactoryInterface {
    function createRocketMinipool(address _nodeOwner, string memory _durationID, bytes memory _depositInput, uint256 _etherDeposited, uint256 _rplDeposited, bool _trusted) public returns(address);
}
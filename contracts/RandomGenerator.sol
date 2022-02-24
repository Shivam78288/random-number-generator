//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@chainlink/contracts/src/v0.8/VRFConsumerBase.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import './IRandomGenerator.sol';

contract RandomGenerator is IRandomGenerator, VRFConsumerBase, AccessControl{
    using SafeMath for uint256;
    bytes32 private constant VIEW_ROLE = keccak256("VIEW_ROLE");

    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 private chainlinkRandomResult;
    uint256 private seed;
    uint256 private counter;
    uint256 private lastRandomNum;

    event RandomNumGenerated(uint256 randomNum, uint256 timestamp);
    event ChainlinkNumGenerated(uint256 randomNumber);
    event ViewerAdded(address viewer);
    event ViewerRemoved(address viewer);

    /* For polygon:
        LINK Token	0xb0897686c545045aFc77CF20eC7A532E3120E0F1
        VRF Coordinator	0x3d2341ADb2D31f1c5530cDC622016af293177AE0
        Key Hash	0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da
        Fee	0.0001 LINK  

       For Mumbai:
        LINK Token	0x326C977E6efc84E512bB9C30f76E30c160eD06FB
        VRF Coordinator	0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
        Key Hash	0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
        Fee	0.0001 LINK
    **/
    constructor(uint256 _seed, address _owner) 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        )
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 10 ** 14; // 0.1 LINK (For Polygon)
        seed = _seed;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(VIEW_ROLE, _owner);
    }

    /** 
     * Requests randomness 
     */
    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        chainlinkRandomResult = randomness;
        emit ChainlinkNumGenerated(chainlinkRandomResult);
    }

    function getSeed() external view override onlyViewRole() returns(uint256){
        return seed;
    }

    function getCounter() external view override onlyViewRole() returns(uint256){
        return counter;
    }

    function setSeed(uint256 _seed) external override onlyDefaultAdminRole() {
        seed = _seed;
    } 


    function _generateRandomNumber(uint256 modulus) private returns (uint256, uint256){
        getRandomNumber();
        bytes32 xorred = (bytes32(seed) ^ bytes32(counter ** 2)) ^ bytes32(chainlinkRandomResult);
        bytes32 random = keccak256(abi.encodePacked(
            xorred,
            block.timestamp,
            block.difficulty,
            msg.sender
        ));
        counter++;
        emit RandomNumGenerated((uint256(random) % modulus), block.timestamp);
        return ((uint256(random) % modulus), block.timestamp);
    }

    function latestRoundData(uint256 modulus)
        external  
        override 
        onlyViewRole()
        returns (uint256, uint256, uint256)
    {
        (uint256 randomNumber, uint256 timestamp) = _generateRandomNumber(modulus);
        lastRandomNum = randomNumber;
        return (counter, randomNumber, timestamp);
    }

    function addViewRole(address account) external override onlyDefaultAdminRole(){
        _setupRole(VIEW_ROLE, account);
        emit ViewerAdded(account);
    }

    function removeFromViewRole(address account) external override onlyDefaultAdminRole(){
        _revokeRole(VIEW_ROLE, account);
        emit ViewerRemoved(account);
    }

    modifier onlyViewRole() {
        require(
            hasRole(VIEW_ROLE, msg.sender),
            "Unauthorized: Only view roles can call this function"
            );
        _;
    }

    modifier onlyDefaultAdminRole() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Unauthorized: Only default admin can call this function"
        );
        _;
    }

}
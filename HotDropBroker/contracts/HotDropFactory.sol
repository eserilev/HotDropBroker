//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract HotDropFactory {
    mapping(uint256 => uint256) public tokenIdToProjectId;
    address public administrator;
    constructor() {
        administrator = msg.sender;
    }
}
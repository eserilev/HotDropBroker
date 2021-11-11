//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract HotDropFactory {
    struct Project {
        address projectAddress;
        bool active;
        string uri;
    } 

    event CreateProject(uint256 indexed projectId, address indexed projectAddress, string uri);
    
    using Counters for Counters.Counter;
    Counters.Counter private projectIds;

    mapping(uint256 => Project) public projects;
    mapping(address => uint256) public isProjectAddress;
    
    bytes4 constant ERC721ID = 0x80ac58cd;

    address public administrator;
    constructor() {
        administrator = msg.sender;
    }

    function createProject(address projectAddress, string memory uri) public requireAdmin requireERC721Contract(projectAddress) returns (uint256) {
        require(isProjectAddress[projectAddress] == 0, "This NFT Project Already Exists In HotDrop!");

        projectIds.increment();
        uint256 newProjectId = projectIds.current();

        isProjectAddress[projectAddress] = newProjectId;
        
        Project memory project = projects[newProjectId];
        project.projectAddress = projectAddress;
        project.active = true;
        project.uri = uri;
        projects[newProjectId] = project;

        return newProjectId;
    }

    function projectIdToTokenAddress(uint256 projectId) public view returns (address) {
        return projects[projectId].projectAddress;
    }

    // MODIFIERS
    modifier requireAdmin() {
		require(msg.sender == administrator, 'You are not the hot drop factory admin!');
		_;
	}

    modifier requireERC721Contract(address contractAddress) {
        require(ERC165Checker.supportsInterface(contractAddress, ERC721ID), 'This is not a supported contract interface');
        _;
    }
}
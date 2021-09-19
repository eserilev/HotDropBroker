//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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

    address public administrator;
    constructor() {
        administrator = msg.sender;
    }

    function createProject(address projectAddress, string memory uri) public requireAdmin returns (uint256) {
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
		require(msg.sender == administrator, 'you are not the hot drop factory admin!');
		_;
	}
}
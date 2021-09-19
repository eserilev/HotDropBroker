//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IHotDropFactory {
	function tokenIdToProjectId(uint256 _tokenId) external view returns (uint256 projectId);
	function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract HotDropBroker {
    IHotDropFactory public HOTDROP_FACTORY;
    
    event HotDropAction(address indexed _user, uint256 indexed _hotDropProjectId, uint256 _priceInWei, uint256 _quantity, string _action);
    
    struct Order {
        uint256 quantity;
        uint256 priceInWei;
    }

    address public hotDropBroker;
    address public hotDropFactory;
    address public hotDropsProfitReceiver;

    uint128 public hotDropBrokerFeeRate;
    
    mapping(address => mapping(uint256 => Order)) public orders;
    mapping(address => uint256) public balances;

    constructor(address _hotDropFactory, address _profitReceiver, uint128 _feeRate) {
        hotDropBroker = msg.sender;
        hotDropFactory = _hotDropFactory;
        hotDropsProfitReceiver = _profitReceiver;
        hotDropBrokerFeeRate = _feeRate;

        HOTDROP_FACTORY = IHotDropFactory(hotDropFactory);
    }

    // USER FUNCTIONS
    function placeOrder(uint256 _hotDropProjectId, uint128 quantity) external payable {
		require(msg.value > 0, 'Zero wei offers not accepted.');
        require(quantity == 1, 'we currently dont support more than one nft at a time');
        Order memory order = orders[msg.sender][_hotDropProjectId];
		require(order.priceInWei * order.quantity == 0, 'You already placed an order');           
        orders[msg.sender][_hotDropProjectId].priceInWei = msg.value;
        orders[msg.sender][_hotDropProjectId].quantity = quantity;

        emit HotDropAction(msg.sender, _hotDropProjectId, msg.value, quantity, 'Placed Order');
    }

    // BOT FUNCTIONS
    function fulfillOrder(address _user, uint256 _hotDropProjectId, uint256 _tokenId, uint256 _expectedPriceInWei, address _profitTo, bool _sendNow) public returns (uint256) {
		Order memory order = orders[_user][_hotDropProjectId];
        require(order.quantity > 0, 'user order does not exist');
        // protect the bot from user front running
        require(order.priceInWei >= _expectedPriceInWei, 'user offer insufficient');
        require(order.quantity == 1, 'we currently dont support more than one nft at a time');

        uint256 hotDropBrokerFee = order.priceInWei * hotDropBrokerFeeRate / 100;
        // pay the hot drop broker
		balances[hotDropsProfitReceiver] += hotDropBrokerFee;

		// transfer NFT to user
		HOTDROP_FACTORY.safeTransferFrom(msg.sender, _user, _tokenId); // reverts on failure

        // pay the bot
		sendValue(payable(_profitTo), order.priceInWei - hotDropBrokerFeeRate);    
    }

    // HELPER FUNCTIONS
    function viewOrder(address _user, uint256 _hotDropProjectId) external view returns (Order memory) {
		return orders[_user][_hotDropProjectId];
	}

    function viewOrders(address[] memory _users, uint256[] memory _hotDropProjectId) external view returns (Order[] memory) {
		Order[] memory output = new Order[](_users.length);
		for (uint256 i = 0; i < _users.length; i++) output[i] = orders[_users[i]][_hotDropProjectId[i]];
		return output;
	}


	// OpenZeppelin's sendValue function, used for transfering ETH out of this contract
	function sendValue(address payable recipient, uint256 amount) internal {
		require(address(this).balance >= amount, "Address: insufficient balance");
		// solhint-disable-next-line avoid-low-level-calls, avoid-call-value
		(bool success, ) = recipient.call{ value: amount }("");
		require(success, "Address: unable to send value, recipient may have reverted");
	}


    // MODIFIERS
    modifier requireBroker() {
		require(msg.sender == hotDropBroker, 'you are not the hot drop broker!');
		_;
	}
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IHotDropFactory {
	function projectIdToTokenAddress(uint256 _projectId) external view returns (address tokenAddress);
}

interface IERC721 {
	function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
}

contract HotDropBroker {
    IHotDropFactory public HOTDROP_FACTORY;
    
    event PlaceOrder(address indexed _user, uint256 indexed _hotDropProjectId, uint256 _priceInWeiEach, uint256 _quantity);
    event FulfillOrder(address indexed _bot, address indexed _user, uint256 indexed _hotDropProjectId, uint256 _priceInWeiEach, uint256 _quantity, uint256 _brokerFee, uint256 _botFee);

    struct Order {
        uint256 quantity;
        uint256 priceInWeiEach;
    }

    address public hotDropBroker;
    address public hotDropFactory;
    address public hotDropsProfitReceiver;
    uint128 public hotDropBrokerFeeRate;
    
    // project_id => user => order
    mapping(uint256 => mapping(address => Order)) public orders;

    // user => balance
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
        Order memory order = orders[_hotDropProjectId][msg.sender];
		require(order.priceInWeiEach * order.quantity == 0, 'You already placed an order');           
        orders[_hotDropProjectId][msg.sender].priceInWeiEach = msg.value;
        orders[_hotDropProjectId][msg.sender].quantity = quantity;

        emit PlaceOrder(msg.sender, _hotDropProjectId, msg.value, quantity);
    }

    // BOT FUNCTIONS
    function fulfillOrder(address _user, uint256 _hotDropProjectId, uint256 _tokenId, uint256 _expectedpriceInWeiEach, address _profitTo) public returns (uint256) {
		Order memory order = orders[_hotDropProjectId][_user];
        require(order.quantity > 0, 'user order does not exist');
        // protect the bot from user front running
        require(order.priceInWeiEach >= _expectedpriceInWeiEach, 'user offer insufficient');
		
        orders[_hotDropProjectId][_user].quantity = order.quantity - 1; // reverts on underflow
        uint256 hotDropBrokerFee = order.priceInWeiEach * hotDropBrokerFeeRate / 100;
        
        // pay the hot drop broker
		balances[hotDropsProfitReceiver] += hotDropBrokerFee;

		// send NFT to the user
        IERC721 nftContract = IERC721(HOTDROP_FACTORY.projectIdToTokenAddress(_hotDropProjectId));
        nftContract.safeTransferFrom(msg.sender, _user, _tokenId);

        // pay the bot
        uint256 botPayment = order.priceInWeiEach - hotDropBrokerFeeRate;
		sendValue(payable(_profitTo), botPayment);   
        emit FulfillOrder(msg.sender, _user, _hotDropProjectId, order.priceInWeiEach, 1, hotDropBrokerFee, botPayment); 
        return botPayment;
    }

    // HELPER FUNCTIONS
    function viewOrder(address _user, uint256 _hotDropProjectId) external view returns (Order memory) {
		return orders[_hotDropProjectId][_user];
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

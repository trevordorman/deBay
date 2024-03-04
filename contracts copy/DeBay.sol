//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IDeBay {
    event AuctionStarted(bytes32 auctionId);
    event Bid(bytes32 auctionId, address bidder, uint256 bid);
    event AuctionEnded(bytes32 auctionId, address winner, uint256 winningBid);

    /**
     * @dev Starts an auction, emits event AuctionStarted
     * Must check if auction already exists
     */
    function startAuction(
        string calldata name,
        string calldata imgUrl,
        string calldata description,
        uint256 floor, // Minimum bid price
        uint256 deadline // To be compared with block.timestamp
    ) external;

    /**
     * @dev Bids on an auction using external funds, emits event Bid
     * Must check if auction exists && auction hasn't ended && bid isn't too low
     */
    function bid(bytes32 auctionId) external payable;

    /**
     * @dev Bids on an auction using existing funds, emits event Bid
     * Must check if auction exists && auction hasn't ended && bid isn't too low
     */
    function bid(bytes32 auctionId, uint256 amount) external;

    /**
     * @dev Settles an auction, emits event AuctionEnded
     * Must check if auction has already ended
     */
    function settle(bytes32 auctionId) external;

    /**
     * @dev Users can deposit more funds into the contract to be used for future bids
     */
    function deposit() external payable;

    /**
     * @dev Users can withdraw funds that were previously deposited
     */
    function withdraw() external;
}

contract DeBay is Ownable, Pausable, IDeBay {
    struct Auction {
        address initiator;
        bool auctionStatus;
        string name;
        string imgUrl;
        string description;
        uint256 floor;
        uint256 deadline;
        uint256 auctionBalance;
        address currentBidder;
        uint256 currentBid;
    }
    mapping(bytes32 => Auction) private _auctions;
    bool private _onlyNotPaused;
    mapping(address => uint256) private _balances;

    modifier pauseOff() {
        require(_onlyNotPaused == false, "Pause On");
        _;
    }

    function startAuction(
        string calldata name,
        string calldata imgUrl,
        string calldata description,
        uint256 floor, // Minimum bid price
        uint256 deadline // To be compared with block.timestamp
    ) external override pauseOff {
        bytes32 auctionId = getAuctionId(
            msg.sender,
            deadline,
            name,
            imgUrl,
            description
        );
        Auction storage a = _auctions[auctionId];
        require(
            !a.auctionStatus && a.initiator == address(0),
            "Auction exists"
        );
        a.name = name;
        a.imgUrl = imgUrl;
        a.description = description;
        a.floor = floor;
        a.deadline = block.timestamp + deadline;
        a.auctionStatus = true;
        a.initiator = _msgSender();
        emit AuctionStarted(auctionId);
    }

    function bid(bytes32 auctionId) external payable override pauseOff {
        Auction storage a = _auctions[auctionId];
        require(block.timestamp < a.deadline, "Auction Ended");
        require(_msgSender() != a.initiator, "Can't bid on own auction");
        require(msg.value > a.currentBid, "Lower than previous Bid");
        require(a.auctionStatus == true, "Auction does not exist");
        _balances[a.currentBidder] += a.currentBid;
        a.currentBidder = _msgSender();
        a.currentBid = msg.value;
        a.auctionBalance = a.currentBid;
        emit Bid(auctionId, _msgSender(), msg.value);
    }

    function bid(bytes32 auctionId, uint256 amount) external override pauseOff {
        Auction storage a = _auctions[auctionId];
        require(block.timestamp < a.deadline, "Auction Ended");
        require(_msgSender() != a.initiator, "Can't bid on own auction");
        require(_balances[_msgSender()] >= amount, "Insufficient Funds");
        require(amount > a.currentBid, "Lower than previous Bid");
        require(a.auctionStatus == true, "Auction does not exist");
        _balances[a.currentBidder] += a.currentBid;
        a.currentBidder = _msgSender();
        _balances[_msgSender()] -= amount;
        a.currentBid = amount;
        a.auctionBalance = a.currentBid;
        emit Bid(auctionId, _msgSender(), amount);
    }

    function settle(bytes32 auctionId) external override pauseOff {
        Auction storage a = _auctions[auctionId];
        require(_msgSender() == a.initiator, "Not Auction Owner");
        require(a.auctionStatus == true, "Already ended");
        a.auctionStatus = false;
        _balances[_msgSender()] += a.currentBid;
        emit AuctionEnded(auctionId, a.currentBidder, a.currentBid);
    }

    function deposit() external payable override pauseOff {
        _balances[_msgSender()] += msg.value;
    }

    function withdraw() external override pauseOff {
        payable(msg.sender).transfer(_balances[_msgSender()]);
        _balances[_msgSender()] = 0;
    }

    function getAuction(
        bytes32 auctionId
    ) external view returns (Auction memory) {
        return _auctions[auctionId];
    }

    function getAuctionId(
        address initiator,
        uint256 deadline,
        string calldata name,
        string calldata imgUrl,
        string calldata description
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(initiator, deadline, name, imgUrl, description)
            );
    }
}

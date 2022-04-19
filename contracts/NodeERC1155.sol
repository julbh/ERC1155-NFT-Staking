// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/INodeERC1155.sol";
import "./interfaces/IJoePair.sol";
import "./interfaces/ICorkToken.sol";
import "./interfaces/ISwapCork.sol";

contract NodeERC1155 is INodeERC1155, ERC1155, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address payable public manager;
    address public pairAddress;
    address public corkAddress;
    address public swapAddress;
    uint256 private _percentRate = 10**8;
    uint256 private _currentTokenID = 0;
    uint256 private _rewardInterval = 3 minutes;
    uint256 private _periodDays = 30;

    struct CollectionStruct {
        string title;
        uint256 price;
        uint256 maxSupply;
        uint256 firstRun;
        uint256 maxFirstRun;
        uint256 trueYield;
        uint256 snowball;
        uint256 maxSnowball;
        uint256 maxDailySell;
        uint256 currentSupply;
        uint256 purchaseLimit;
    }

    // all collection(slope) info
    CollectionStruct[] public collection;

    // 0: Blue, 1: Red, 2: Black, 3: DoubleBlack
    struct NodeStruct {
        address purchaser;
        uint256 nodeType;
        uint256 purchasedAt;
        uint256 snowballAt;
        uint256 claimedAmount;
        uint256 claimedSnowball; // only need to get total claimed amount in frontend.
        uint256 remainClaimedAmount;
        string uri;
    }

    // mapping from tokenId to NodeStruct
    mapping(uint256 => NodeStruct) public nodeState;
    // mapping form owner to node IDs
    mapping(address => uint256[]) public ownedNodes;

    constructor() ERC1155("https://example.com/{id}.json") {
        nodeInit();
    }

    function setManager(address _manager) public onlyOwner {
        manager = payable(_manager);
    }

    // Function to withdraw all AVAX from this contract.
    function withdraw() public nonReentrant {
        // get the amount of AVAX stored in this contract
        require(msg.sender == manager, "only manager can call withdraw");
        uint256 amount = address(this).balance;

        // send all AVAX to manager
        // manager can receive AVAX since the address of manager is payable
        (bool success, ) = manager.call{value: amount}("");
        require(success, "Failed to send AVAX");
    }

    // Function to withdraw cork from this contract.
    function withdrawCork(uint256 amount) public nonReentrant onlyOwner {
        ICorkToken(corkAddress).transfer(msg.sender, amount);
    }

    function nodeInit() internal {
        // title price maxSupply firstRun maxFirstRun trueYield snowball maxSnowball maxDailySell currentSupply
        collection.push(
            CollectionStruct(
                "Blue", // title
                4 ether, // price
                30000, // maxSupply
                1500000, // firstRun
                100000000, // maxFirstRun
                350000, // trueYield
                1700, // snowball
                50000, // maxSnowball
                15000000, // maxDailySell
                0, // currentSupply
                30 // purchaseLimit
            )
        );
        collection.push(
            CollectionStruct(
                "Red",
                10 ether,
                15000,
                2000000,
                100000000,
                900000,
                3333,
                100000,
                10000000,
                0,
                30 // purchaseLimit
            )
        );
        collection.push(
            CollectionStruct(
                "Black",
                100 ether,
                5000,
                2200000,
                100000000,
                1000000,
                3333,
                100000,
                5000000,
                0,
                30 // purchaseLimit
            )
        );
        collection.push(
            CollectionStruct(
                "DoubleBlack",
                1000 ether,
                1000,
                2200000,
                100000000,
                1000000,
                4167,
                125000,
                5000000,
                0,
                10 // purchaseLimit
            )
        );
    }

    function mint(uint256 _nodeType, string calldata _uri) public {
        require(
            collection[_nodeType].currentSupply <=
                collection[_nodeType].maxSupply,
            "all of this collection are purchased"
        );

        require(
            getOwnedNodeCountByType(msg.sender, _nodeType) <
                collection[_nodeType].purchaseLimit,
            "minted nodes exceed amount limit"
        );

        ICorkToken corkToken = ICorkToken(corkAddress);

        require(
            corkToken.balanceOf(msg.sender) >= collection[_nodeType].price,
            "receiver's balance is less than node price"
        );

        uint256 _id = _getNextTokenID();
        _incrementTokenID();
        nodeState[_id].purchaser = msg.sender;
        nodeState[_id].nodeType = _nodeType;
        nodeState[_id].purchasedAt = block.timestamp;
        nodeState[_id].snowballAt = block.timestamp;
        nodeState[_id].uri = _uri;

        collection[_nodeType].currentSupply++;

        corkToken.transferFrom(
            msg.sender,
            address(this),
            collection[_nodeType].price
        );

        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        _mint(msg.sender, _nodeType, 1, "");

        ownedNodes[msg.sender].push(_id);
    }

    function bailOutMint(
        uint256 id, // node used in bailout mint
        uint256 nodeType,
        uint256 amount, // bailout mint amount
        string calldata _uri
    ) public {
        require(
            nodeState[id].purchaser == msg.sender,
            "only node owner can use it"
        );
        uint256 claimableCork = getClaimableCorkById(id);
        uint256 wastedCork = collection[nodeType].price * amount;

        require(
            claimableCork >= wastedCork,
            "claimable cork is less than price"
        );

        require(
            collection[nodeType].currentSupply <=
                collection[nodeType].maxSupply,
            "all of this collection are purchased"
        );

        require(
            getOwnedNodeCountByType(msg.sender, nodeType) <
                collection[nodeType].purchaseLimit,
            "minted nodes exceed amount limit"
        );

        (, uint256 snowballRewardCork) = calculateClaimableAmount(id);
        nodeState[id].snowballAt = block.timestamp;
        if (wastedCork <= snowballRewardCork) {
            if (wastedCork < snowballRewardCork)
                nodeState[id].remainClaimedAmount =
                    snowballRewardCork -
                    wastedCork;
        } else {
            nodeState[id].claimedAmount = wastedCork - snowballRewardCork;
        }
        nodeState[id].claimedSnowball += snowballRewardCork;

        for (uint256 i = 0; i < amount; i++) {
            uint256 _id = _getNextTokenID();
            _incrementTokenID();
            nodeState[_id].purchaser = msg.sender;
            nodeState[_id].nodeType = nodeType;
            nodeState[_id].purchasedAt = block.timestamp;
            nodeState[_id].snowballAt = block.timestamp;
            nodeState[_id].uri = _uri;

            collection[nodeType].currentSupply++;

            if (bytes(_uri).length > 0) {
                emit URI(_uri, _id);
            }

            _mint(msg.sender, nodeType, 1, "");

            ownedNodes[msg.sender].push(_id);
        }
    }

    function claim() external payable nonReentrant {
        require(ownedNodes[msg.sender].length > 0, "No have a node");
        require(getClaimFee(msg.sender) <= msg.value, "No fee is set");
        ICorkToken corkToken = ICorkToken(corkAddress);
        uint256 claimableCork;

        for (uint256 i = 0; i < ownedNodes[msg.sender].length; i++) {
            uint256 id = ownedNodes[msg.sender][i];

            // mainRewardCork: first run yield and true yield
            // snowballRewardCork; sonwball effect yield
            (
                uint256 mainRewardCork,
                uint256 snowballRewardCork
            ) = calculateClaimableAmount(id);
            nodeState[id].snowballAt = block.timestamp;
            nodeState[id].claimedSnowball += snowballRewardCork;
            claimableCork +=
                (snowballRewardCork +
                    mainRewardCork -
                    nodeState[id].claimedAmount) +
                nodeState[id].remainClaimedAmount;
            if (nodeState[id].remainClaimedAmount > 0)
                nodeState[id].remainClaimedAmount = 0;
            nodeState[id].claimedAmount =
                mainRewardCork +
                nodeState[id].remainClaimedAmount;
        }

        corkToken.transfer(msg.sender, claimableCork);
    }

    function claimById(uint256 id) external payable nonReentrant {
        require(
            nodeState[id].purchaser == msg.sender,
            "only puchaser can claim"
        );
        require(getClaimFeeById(id) <= msg.value, "No set enough fee");
        ICorkToken corkToken = ICorkToken(corkAddress);

        (
            uint256 mainRewardCork,
            uint256 snowballRewardCork
        ) = calculateClaimableAmount(id);
        nodeState[id].snowballAt = block.timestamp;
        nodeState[id].claimedSnowball += snowballRewardCork;
        uint256 claimableCork = (snowballRewardCork +
            mainRewardCork -
            nodeState[id].claimedAmount) + nodeState[id].remainClaimedAmount;
        if (nodeState[id].remainClaimedAmount > 0)
            nodeState[id].remainClaimedAmount = 0;
        nodeState[id].claimedAmount =
            mainRewardCork +
            nodeState[id].remainClaimedAmount;

        corkToken.transfer(msg.sender, claimableCork);
    }

    function swapTokensForAVAX(uint256 amount) public {
        ISwapCork swap = ISwapCork(swapAddress);
        swap.swapCorkForAVAX(msg.sender, amount);
    }

    function getClaimableCork(address claimAddress)
        public
        view
        returns (uint256)
    {
        require(ownedNodes[claimAddress].length > 0, "No have a node");
        uint256 claimableCork;

        for (uint256 i = 0; i < ownedNodes[claimAddress].length; i++) {
            uint256 id = ownedNodes[claimAddress][i];

            // mainRewardCork: first run yield and true yield
            // snowballRewardCork; sonwball effect yield
            (
                uint256 mainRewardCork,
                uint256 snowballRewardCork
            ) = calculateClaimableAmount(id);
            claimableCork +=
                (snowballRewardCork +
                    mainRewardCork -
                    nodeState[id].claimedAmount) +
                nodeState[id].remainClaimedAmount;
        }
        return claimableCork;
    }

    function calculateClaimableAmount(uint256 _id)
        public
        view
        returns (uint256, uint256)
    {
        require(nodeState[_id].purchaser != address(0), "No node exist");
        uint256 _nodeType = nodeState[_id].nodeType;
        uint256 _price = collection[_nodeType].price;

        // lasted days
        uint256 lastedMainDays = (block.timestamp - nodeState[_id].purchasedAt)
            .div(_rewardInterval);
        uint256 lastedSnowballDays = (block.timestamp -
            nodeState[_id].snowballAt).div(_rewardInterval);

        uint256 mainRewardAmount = calculateMainAmount(
            collection[_nodeType].firstRun,
            collection[_nodeType].trueYield,
            collection[_nodeType].maxFirstRun,
            lastedMainDays
        );
        uint256 snowballRewardAmount = calculateSnowballAmount(
            collection[_nodeType].snowball,
            collection[_nodeType].maxSnowball,
            lastedSnowballDays
        );
        return (
            _amount2cork(mainRewardAmount, _price),
            _amount2cork(snowballRewardAmount, _price)
        );
    }

    function calculateMainAmount(
        uint256 _firstRun,
        uint256 _trueYield,
        uint256 _maxFirstRun,
        uint256 _lastedMainDays
    ) private view returns (uint256) {
        // if true yield started
        if (_lastedMainDays > _periodDays) {
            uint256 lastedTrueYieldDays = _lastedMainDays - _periodDays;
            return _maxFirstRun + lastedTrueYieldDays * _trueYield; // ROI + true yield
        } else {
            return _lastedMainDays * _firstRun;
        }
    }

    function calculateSnowballAmount(
        uint256 _snowball,
        uint256 _maxSnowball,
        uint256 _lastedSnowballDays
    ) private view returns (uint256) {
        // if reached at the max snowball
        if (_lastedSnowballDays < _periodDays) {
            uint256 totalRates;
            for (uint256 i = 0; i <= _lastedSnowballDays; i++) {
                totalRates += i;
            }
            return totalRates * _snowball;
        } else {
            uint256 totalRates;
            for (uint256 i = 0; i <= _periodDays; i++) {
                totalRates += i;
            }
            return
                totalRates *
                _snowball + // snowball effect when bumping
                _maxSnowball *
                (_lastedSnowballDays - _periodDays); // max snowball effect
        }
    }

    function sellableCork(address from)
        external
        view
        override
        returns (uint256)
    {
        uint256 _sellableCork;

        for (uint256 i = 0; i < collection.length; i++) {
            if (balanceOf(from, i) > 0) {
                _sellableCork +=
                    balanceOf(from, i) *
                    _amount2cork(
                        collection[i].maxDailySell,
                        collection[i].price
                    );
            }
        }

        return _sellableCork;
    }

    function resetContract(
        address _pairAddress,
        address _corkAddress,
        address _swapAddress
    ) external onlyOwner {
        if (_pairAddress != address(0)) pairAddress = _pairAddress;
        if (_corkAddress != address(0)) corkAddress = _corkAddress;
        if (_swapAddress != address(0)) swapAddress = _swapAddress;
    }

    // note: when adding pool, res0 : cork, res1: avax
    function getCorkPrice() public view returns (uint256) {
        (uint256 Res0, uint256 Res1, ) = IJoePair(pairAddress).getReserves();

        uint256 price = (Res1 * (10**18)).div(Res0);
        return price;
    }

    function getClaimFee(address claimAddress) public view returns (uint256) {
        uint256 claimableCork = getClaimableCork(claimAddress);
        uint256 corkPrice = getCorkPrice();
        return (claimableCork * corkPrice).div(10**18);
    }

    function getClaimableCorkById(uint256 id) public view returns (uint256) {
        // mainRewardCork: first run yield and true yield
        // snowballRewardCork; sonwball effect yield
        (
            uint256 mainRewardCork,
            uint256 snowballRewardCork
        ) = calculateClaimableAmount(id);
        uint256 claimableCork = (snowballRewardCork +
            mainRewardCork -
            nodeState[id].claimedAmount) + nodeState[id].remainClaimedAmount;
        return claimableCork;
    }

    function getClaimFeeById(uint256 id) public view returns (uint256) {
        uint256 claimableCork = getClaimableCorkById(id);
        uint256 corkPrice = getCorkPrice();
        return (claimableCork * corkPrice).div(10**18);
    }

    function getOwnedNodeCountByType(address user, uint256 nodeType)
        public
        view
        returns (uint256)
    {
        uint256 count;
        for (uint256 i = 0; i < ownedNodes[user].length; i++) {
            if (nodeState[ownedNodes[user][i]].nodeType == nodeType) count++;
        }
        return count;
    }

    function getNodeState(uint256 id) public view returns (NodeStruct memory) {
        return nodeState[id];
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    function _incrementTokenID() private {
        _currentTokenID++;
    }

    function _amount2cork(uint256 _amount, uint256 _price)
        private
        view
        returns (uint256)
    {
        return (_amount * _price).div(_percentRate);
    }
}

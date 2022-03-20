// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/INodeERC1155.sol";
import "./interfaces/ICorkToken.sol";
// import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IJoeRouter02.sol";
import "./interfaces/ISwapCork.sol";

contract SwapCork is ISwapCork, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) public lastSellTime;
    mapping(address => uint256) public soldDaily;
    mapping(address => bool) public taxSellStarted;

    bool private swapAvailable; // for prevent hack
    address public nodeAddress;
    address public corkAddress;
    address public routerAddress;

    uint256 private sellInterval = 1 days;
    uint256 private tax = 60;
    uint256 private rate = 100;

    constructor(
        address _nodeAddress,
        address _corkAddress,
        address _routerAddress
    ) {
        nodeAddress = _nodeAddress;
        corkAddress = _corkAddress;
        routerAddress = _routerAddress;

        swapAvailable = false;
    }

    function swapCorkForAVAX(address from, uint256 amount) external override {
        require(
            ICorkToken(corkAddress).balanceOf(from) >= amount,
            "sell amount exceeds balance"
        );

        uint256 sellAmountDaily; // temp variable to calculate
        uint256 taxSellAmount; // tax sell
        uint256 toUser; // actual amount the user will receive
        uint256 dailyLimit = INodeERC1155(nodeAddress).sellableCork(from);

        if (block.timestamp - lastSellTime[from] > sellInterval) {
            sellAmountDaily = amount;
            soldDaily[from] = 0;
            taxSellStarted[from] = false;
        } else {
            sellAmountDaily = amount + soldDaily[from];
        }

        // if amount is more than daily limit, tax is assigned
        if (sellAmountDaily > dailyLimit) {
            if (taxSellStarted[from]) taxSellAmount = amount;
            else taxSellAmount = sellAmountDaily - dailyLimit;

            taxSellStarted[from] = true;

            uint256 toTreasury = (taxSellAmount * tax).div(rate);
            toUser = amount - toTreasury;

            ICorkToken(corkAddress).transferFrom(from, nodeAddress, toTreasury);
        } else {
            toUser = amount;
        }

        soldDaily[from] += amount;
        lastSellTime[from] = block.timestamp;
        ICorkToken(corkAddress).transferFrom(from, address(this), toUser);
        swapInTraderjoe(from, toUser);
    }

    function swapInTraderjoe(address from, uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = corkAddress;

        // must be changed in avalanche mainnet launch //////////
        path[1] = IJoeRouter02(routerAddress).WAVAX();
        // path[1] = IUniswapV2Router02(routerAddress).WETH();

        swapAvailable = true;

        ICorkToken(corkAddress).setApprove(
            address(this),
            routerAddress,
            tokenAmount
        );

        // must be changed in avalanche mainnet launch //////////
        IJoeRouter02(routerAddress).swapExactTokensForAVAXSupportingFeeOnTransferTokens(
        // IUniswapV2Router02(routerAddress)
            // .swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of ETH
                path,
                from,
                block.timestamp
            );
    }

    function getSwapAvailable() external view override returns (bool) {
        return swapAvailable;
    }

    function removeSwapAvailable() external override {
        swapAvailable = false;
    }

    function getSellableCorkNoTaxToday(address sellAddress)
        public
        view
        returns (uint256)
    {
        uint256 dayilySellableCork = INodeERC1155(nodeAddress).sellableCork(
            sellAddress
        );
        if (dayilySellableCork <= soldDaily[sellAddress]) return 0;
        if (block.timestamp - lastSellTime[sellAddress] > sellInterval) {
            return dayilySellableCork;
        } else {
            return dayilySellableCork - soldDaily[sellAddress];
        }
    }

    function resetContract(
        address _nodeAddress,
        address _corkAddress,
        address _routerAddress
    ) external onlyOwner {
        if (_nodeAddress != address(0)) nodeAddress = _nodeAddress;
        if (_corkAddress != address(0)) corkAddress = _corkAddress;
        if (_routerAddress != address(0)) routerAddress = _routerAddress;
    }
}

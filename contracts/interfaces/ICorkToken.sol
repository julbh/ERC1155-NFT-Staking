// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface ICorkToken {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function setApprove(address owner, address spender, uint256 amount) external;
}

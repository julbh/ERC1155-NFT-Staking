pragma solidity ^0.8.0;


// SPDX-License-Identifier: MIT LICENSE
interface INodeERC1155 {
    function sellableCork(address from) external view returns (uint256);
}
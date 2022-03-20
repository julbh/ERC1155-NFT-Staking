// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface INodeERC1155 {
    function sellableCork(address from) external view returns (uint256);
}

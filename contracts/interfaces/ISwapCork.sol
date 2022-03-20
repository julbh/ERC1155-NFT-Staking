// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ISwapCork {
    function swapCorkForAVAX(address from, uint256 amount) external;
    function getSwapAvailable() external view returns(bool);
    function removeSwapAvailable() external;
}

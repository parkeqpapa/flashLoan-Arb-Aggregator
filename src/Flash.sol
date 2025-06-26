// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * @title Flash
 * @notice A simple flash loan lender implementing ERC-3156 standard
 * @dev This contract allows users to borrow tokens for a single transaction
 *      and charges a fixed fee of 0.0001 ether regardless of the loan amount
 * @author parkeqpapa
 */
contract Flash is IERC3156FlashLender {
    /// @notice The token address that can be borrowed from this lender
    /// @dev This is the only token supported by this flash loan contract
    address public token;

    /**
     * @notice Constructs the Flash contract
     * @dev Sets the token that will be available for flash loans
     * @param _token The address of the ERC20 token to be lent
     */
    constructor(address _token) {
        token = _token;
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @dev Returns a fixed fee of 0.0001 ether regardless of token or amount
     * @notice The fee is charged in the same token being borrowed
     */
    function flashFee(address tokenAddress, uint256 amount) public pure returns (uint256) {
        return 0.0001 ether;
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @dev Returns the full balance of the contract for the supported token,
     *      or 0 for unsupported tokens
     */
    function maxFlashLoan(address tokenAddress) external view returns (uint256) {
        if (address(token) == tokenAddress) {
            return IERC20(token).balanceOf(address(this));
        }
        return 0;
    }

    /**
     * @inheritdoc IERC3156FlashLender
     * @dev Executes a flash loan by:
     *      1. Transferring tokens to the receiver
     *      2. Calling the receiver's onFlashLoan callback
     *      3. Collecting the loan amount plus fee from the receiver
     * @notice The receiver must approve this contract to transfer tokens back
     * @notice The receiver's onFlashLoan function must return the correct hash
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address tokenAddress,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(IERC20(token).balanceOf(address(this)) >= amount, 'Insufficient balance');

        IERC20(token).transfer(address(receiver), amount);
        uint256 fee = flashFee(tokenAddress, amount);

        require(
            receiver.onFlashLoan(msg.sender, address(token), amount, fee, data)
                == keccak256('ERC3156FlashBorrower.onFlashLoan'),
            'Callback failed'
        );

        IERC20(token).transferFrom(address(receiver), address(this), amount + fee);

        return true;
    }
}
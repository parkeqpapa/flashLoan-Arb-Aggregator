// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Flash is IERC3156FlashLender {
  address public token;

  constructor(
    address _token
  ) {
    token = _token;
  }

  function flashFee(address tokenAddress, uint256 amount) public pure returns (uint256) {
    return 0.0001 ether;
  }

  function maxFlashLoan(
    address tokenAddress
  ) external view returns (uint256) {
    if (address(token) == tokenAddress) {
      return IERC20(token).balanceOf(address(this));
    }
    return 0;
  }

  function flashLoan(
    IERC3156FlashBorrower receiver,
    address tokenAddress,
    uint256 amount,
    bytes calldata data
  ) external returns (bool) {
    require(IERC20(token).balanceOf(address(this)) >= amount, 'Insufficient balance');

    // Transfer the tokens to the borrower
    IERC20(token).transfer(address(receiver), amount);
    uint256 fee = flashFee(tokenAddress, amount);

    // Call the borrower's callback function
    require(
      receiver.onFlashLoan(msg.sender, address(token), amount, fee, data)
        == keccak256('ERC3156FlashBorrower.onFlashLoan'),
      'Callback failed'
    );

    // Transfer the fee back to the lender
    IERC20(token).transferFrom(address(receiver), address(this), amount + fee);

    return true;
  }
}

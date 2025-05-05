// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Flash} from 'src/Flash.sol';

import {IAAVE} from 'src/interfaces/IAave.sol';
import {IBalancer} from 'src/interfaces/IBalancer.sol';

contract FlashloanAggregator {
  address public owner;
  address payable balancerAddress;
  address public aaveAddress;
  address public flashLenderAddress;

  uint256 public constant BALANCER_PCT = 50;
  uint256 public constant AAVE_PCT = 30;
  uint256 public constant FLASH_LENDER_PCT = 20;
  uint256 public constant PCT_BASE = 100;

  modifier onlyOwner() {
    require(msg.sender == owner, 'Only owner');
    _;
  }

  constructor(address payable _balancerAddress, address _aaveAddress, address _flashLenderAddress) {
    owner = msg.sender;
    balancerAddress = _balancerAddress;
    aaveAddress = _aaveAddress;
    flashLenderAddress = _flashLenderAddress;
  }

  function flashLoanMultiple(uint256 totalAmount, address token, bytes memory data) external onlyOwner {
    require(totalAmount > 0, 'Amount must be > 0');

    uint256 balancerAmount = (totalAmount * BALANCER_PCT) / PCT_BASE;
    uint256 aaveAmount = (totalAmount * AAVE_PCT) / PCT_BASE;
    uint256 flashLenderAmount = totalAmount - balancerAmount - aaveAmount; 

    address[] memory tokens = new address[](1);
    tokens[0] = token;

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = balancerAmount;

    if (balancerAmount > 0) {
      IBalancer(balancerAddress).flashLoan(address(this), tokens, amounts, data);
    }

    if (aaveAmount > 0) {
      IAAVE(aaveAddress).flashLoanSimple(address(this), token, aaveAmount, data, 0);
    }

    if (flashLenderAmount > 0) {
      Flash(flashLenderAddress).flashLoan(IERC3156FlashBorrower(address(this)), token, flashLenderAmount, data);
    }
  }

 
  function receiveFlashLoan(
    address[] memory tokens,
    uint256[] memory amounts,
    uint256[] memory feeAmounts,
    bytes memory userData
  ) external {
    require(msg.sender == balancerAddress, 'Only Balancer');
    uint256 loanAmount = amounts[0];
    IERC20(tokens[0]).transfer(balancerAddress, loanAmount);
  }

  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    require(msg.sender == aaveAddress, 'Only Aave');
    require(initiator == address(this), 'Unauthorized');
    IERC20(asset).approve(aaveAddress, type(uint256).max);
    return true;
  }

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external returns (bytes32) {
    require(msg.sender == flashLenderAddress, 'Only Flash Lender');
    require(initiator == address(this), 'Unauthorized');
    IERC20(token).approve(msg.sender, type(uint256).max);
    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  function approveTokens(address token, uint256 amount) external onlyOwner {
    IERC20(token).approve(balancerAddress, amount);
    IERC20(token).approve(aaveAddress, amount);
    IERC20(token).approve(flashLenderAddress, amount);
  }
}

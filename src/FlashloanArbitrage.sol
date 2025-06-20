// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IUniswapV2Router02} from 'src/interfaces/uniswap.sol';


contract FlashloanArbitrage is IERC3156FlashBorrower {
  address public owner;
  IERC3156FlashLender public flashLender;
  IUniswapV2Router02 public uniswapRouter;
  IUniswapV2Router02 public sushiswapRouter;
  
error Unauthorized();
error NotOwner();
error InsufficientBalance();

  modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner(); 
    _;
  }
  constructor(address _flashLender, address _uniswapRouter, address _sushiswapRouter) {
    owner = msg.sender;
    flashLender = IERC3156FlashLender(_flashLender);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    sushiswapRouter = IUniswapV2Router02(_sushiswapRouter);
  }

  function executeArbitrage(address tokenBorrow, uint256 amount, bytes calldata data) external onlyOwner {
    flashLender.flashLoan(IERC3156FlashBorrower(address(this)), tokenBorrow, amount, data);
  }

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    if (msg.sender != address(flashLender)) revert Unauthorized();
    if (initiator != address(this)) revert Unauthorized();

    (address tokenBuy) = abi.decode(data, (address));
    IERC20(token).approve(address(uniswapRouter), amount);
    IERC20(token).approve(address(sushiswapRouter), amount);

 
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = tokenBuy;

    uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
      amount,
      0, 
      path,
      address(this),
      block.timestamp
    );

    IERC20(tokenBuy).approve(address(sushiswapRouter), amounts[1]);

    address[] memory pathReverse = new address[](2);
    pathReverse[0] = tokenBuy;
    pathReverse[1] = token;

    sushiswapRouter.swapExactTokensForTokens(
      amounts[1],
      0, 
      pathReverse,
      address(this),
      block.timestamp
    );

    IERC20(token).transfer(address(flashLender), amount + fee);

    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  function withdrawToken(
    address tokenAddress
  ) external onlyOwner {
    IERC20 token = IERC20(tokenAddress);
    uint256 balance = token.balanceOf(address(this));
    if (balance == 0) revert InsufficientBalance();
    token.transfer(owner, balance);
  }
}

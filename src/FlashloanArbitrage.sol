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

  constructor(address _flashLender, address _uniswapRouter, address _sushiswapRouter) {
    owner = msg.sender;
    flashLender = IERC3156FlashLender(_flashLender);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    sushiswapRouter = IUniswapV2Router02(_sushiswapRouter);
  }

  modifier onlyOwner() {
    require(msg.sender == owner, 'Only owner');
    _;
  }

  function executeArbitrage(address tokenBorrow, uint256 amount, bytes calldata data) external onlyOwner {
    // Decodificar los datos: token a comprar y ruta de arbitraje
    (address tokenBuy) = abi.decode(data, (address));
    // Solicitar el flash loan
    flashLender.flashLoan(IERC3156FlashBorrower(address(this)), tokenBorrow, amount, data);
  }

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    require(msg.sender == address(flashLender), 'Unauthorized');
    require(initiator == address(this), 'Unauthorized');

    (address tokenBuy) = abi.decode(data, (address));
    // Aprobar los routers para gastar los tokens
    IERC20(token).approve(address(uniswapRouter), amount);
    IERC20(token).approve(address(sushiswapRouter), amount);

    // Ejecutar la estrategia de arbitraje
    // Comprar en Uniswap y vender en Sushiswap
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = tokenBuy;

    // Swap en Uniswap
    uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
      amount,
      0, // Aceptamos cualquier cantidad (mejor implementar mínimo esperado)
      path,
      address(this),
      block.timestamp
    );

    // Aprobar Sushiswap para gastar los tokens comprados
    IERC20(tokenBuy).approve(address(sushiswapRouter), amounts[1]);

    // Swap de vuelta en Sushiswap
    address[] memory pathReverse = new address[](2);
    pathReverse[0] = tokenBuy;
    pathReverse[1] = token;

    sushiswapRouter.swapExactTokensForTokens(
      amounts[1],
      0, // Necesitamos al menos suficiente para pagar el préstamo + fee
      pathReverse,
      address(this),
      block.timestamp
    );

    // Pagar el préstamo
    IERC20(token).transfer(address(flashLender), amount + fee);

    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }

  function withdrawToken(
    address tokenAddress
  ) external onlyOwner {
    IERC20 token = IERC20(tokenAddress);
    uint256 balance = token.balanceOf(address(this));
    require(balance > 0, 'No balance');
    token.transfer(owner, balance);
  }
}

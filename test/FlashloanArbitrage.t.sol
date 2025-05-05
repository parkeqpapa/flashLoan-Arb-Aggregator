// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {Flash} from 'src/Flash.sol';
import {FlashloanArbitrage} from 'src/FlashloanArbitrage.sol';
import {IUniswapV2Router02} from 'src/interfaces/uniswap.sol';

contract FlashLoanArbitrageTest is Test {
  uint256 internal constant _FORK_BLOCK = 22_344_656;
  address internal governor;
  address internal alice;
  Flash internal flash;
  FlashloanArbitrage internal arb;
  IERC20 internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IERC20 internal weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IUniswapV2Router02 internal uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IUniswapV2Router02 internal sushiswapRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

  function setUp() public {
    // Fork the Ethereum mainnet
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    governor = makeAddr('governor');
    alice = makeAddr('alice');
    // Deploy the flash loan contract
    deal(address(dai), alice, 100 ether);
    vm.startPrank(address(governor));
    flash = new Flash(address(dai));
    vm.stopPrank();
    vm.startPrank(address(alice));
    arb = new FlashloanArbitrage(address(flash), address(uniswapRouter), address(sushiswapRouter));
    vm.stopPrank();

    deal(address(dai), address(arb), 100 ether);
    deal(address(dai), address(flash), 100 ether);
  }

  function test_flashLoan() public {
    vm.startPrank(address(arb));
    dai.approve(address(flash), type(uint256).max);
    vm.stopPrank();
    vm.startPrank(alice);
    dai.approve(address(arb), type(uint256).max);
    dai.transfer(address(arb), 1 ether);
    // Flash loan
    bytes memory data = abi.encode(address(weth));
    arb.executeArbitrage(address(dai), 1 ether, data);
    arb.withdrawToken(address(dai));
    assertEq(dai.balanceOf(address(arb)), 0);
    console2.log(dai.balanceOf(alice));
    vm.stopPrank();
  }
}

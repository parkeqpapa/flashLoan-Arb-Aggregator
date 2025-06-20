// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {IUniswapV2Router02} from 'src/interfaces/uniswap.sol';
import {FlashloanArbitrage} from 'src/FlashloanArbitrage.sol';
import {Flash} from 'src/Flash.sol';

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
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    governor = makeAddr('governor');
    alice = makeAddr('alice');
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
    bytes memory data = abi.encode(address(weth));
    arb.executeArbitrage(address(dai), 1 ether, data);
    arb.withdrawToken(address(dai));
    assertEq(dai.balanceOf(address(arb)), 0);
    console2.log(dai.balanceOf(alice));
    vm.stopPrank();
  }

  function test_onFlashLoan_revertsWhenNotFlashLender() public {
    vm.startPrank(makeAddr("attacker"));
    vm.expectRevert(FlashloanArbitrage.Unauthorized.selector);
    arb.onFlashLoan(address(this), address(dai), 1 ether, 0, abi.encode(address(weth)));
    vm.stopPrank();
}

function test_onFlashLoan_revertsWhenWrongInitiator() public {
    vm.startPrank(address(flash));
    vm.expectRevert(FlashloanArbitrage.Unauthorized.selector);
    arb.onFlashLoan(makeAddr("wrong"), address(dai), 1 ether, 0, abi.encode(address(weth)));
    vm.stopPrank();
}

function test_executeArbitrage_revertsWhenNotOwner() public {
    address attacker = makeAddr("attacker");
    vm.startPrank(attacker);
    vm.expectRevert(FlashloanArbitrage.NotOwner.selector);
    arb.executeArbitrage(address(dai), 1 ether, abi.encode(address(weth)));
    vm.stopPrank();
}

function test_withdrawToken_revertsWhenNotOwner() public {
    address attacker = makeAddr("attacker");
    vm.startPrank(attacker);
    vm.expectRevert(FlashloanArbitrage.NotOwner.selector);
    arb.withdrawToken(address(dai));
    vm.stopPrank();
}

function test_withdrawToken_revertsWhenZeroBalance() public {
    vm.startPrank(alice);
    deal(address(dai), address(arb), 0);
    vm.expectRevert(FlashloanArbitrage.InsufficientBalance.selector);
    arb.withdrawToken(address(dai));
    vm.stopPrank();
}

function test_withdrawToken_worksWithBalance() public {
    uint256 initialBalance = 1 ether;
    deal(address(dai), address(arb), initialBalance);
    
    vm.startPrank(alice);
    uint256 ownerBefore = dai.balanceOf(alice);
    arb.withdrawToken(address(dai));
    
    assertEq(dai.balanceOf(address(arb)), 0, "Contract should have 0 balance");
    assertEq(dai.balanceOf(alice), ownerBefore + initialBalance, "Owner should receive funds");
    vm.stopPrank();
}
}

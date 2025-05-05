// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {Flash} from 'src/Flash.sol';
import {FlashloanAggregator} from 'src/FlashloanAggregator.sol';

contract FlashloanAggregatorTest is Test {
  address internal governor;
  address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address aave = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  FlashloanAggregator internal aggregator;

  function setUp() public {
    // Fork the Ethereum mainnet
    vm.createSelectFork(vm.rpcUrl('mainnet'), 22_344_656);
    governor = makeAddr('governor');
    // balancer = makeAddr("balancer");
    // aave = makeAddr("aave");
    // flashLender = makeAddr("flashLender");

    // Deploy the flash loan contract
    vm.startPrank(governor);
    Flash flash = new Flash(address(dai));
    deal(address(dai), address(flash), 100 ether);
    vm.stopPrank();

    // Deploy the aggregator contract
    vm.startPrank(governor);
    aggregator = new FlashloanAggregator(payable(balancer), aave, address(flash));
    vm.stopPrank();
  }

  function test_flashLoanMultiple() public {
    // Test the flash loan functionality
    vm.startPrank(governor);
    // Approve the aggregator to spend DAI
    dai.approve(address(aggregator), type(uint256).max);
    deal(address(dai), address(aggregator), 100 ether);
    aggregator.approveTokens(address(dai), type(uint256).max);
    // Execute the flash loan
    aggregator.flashLoanMultiple(1 ether, address(dai), '');
    vm.stopPrank();
  }
}

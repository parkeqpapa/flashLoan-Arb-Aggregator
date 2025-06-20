// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {Flash} from 'src/Flash.sol';
import {FlashloanAggregator} from 'src/FlashloanAggregator.sol';

interface IBalancer {
    function flashLoan(
        address receiver,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

interface IAAVE {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}
contract FlashloanAggregatorTest is Test {
  address internal governor;
  address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address aave = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  FlashloanAggregator internal aggregator;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 22_344_656);
    governor = makeAddr('governor');
    // balancer = makeAddr("balancer");
    // aave = makeAddr("aave");
    // flashLender = makeAddr("flashLender");

    vm.startPrank(governor);
    Flash flash = new Flash(address(dai));
    deal(address(dai), address(flash), 100 ether);
    vm.stopPrank();

    vm.startPrank(governor);
    aggregator = new FlashloanAggregator(payable(balancer), aave, address(flash));
    vm.stopPrank();
  }

  function test_flashLoanMultiple() public {
    vm.startPrank(governor);
    dai.approve(address(aggregator), type(uint256).max);
    deal(address(dai), address(aggregator), 100 ether);
    aggregator.approveTokens(address(dai), type(uint256).max);
    aggregator.flashLoanMultiple(1 ether, address(dai), '');
    vm.stopPrank();
  }


  function test_flashLoanMultiple_revertsWhenAmountZero() public {
    vm.startPrank(governor);
    vm.expectRevert("Amount must be > 0");
    aggregator.flashLoanMultiple(0, address(dai), '');
    vm.stopPrank();
}

function test_approveTokens_worksWithPartialAmounts() public {
    vm.startPrank(governor);
    uint256 amount = 1000;
    aggregator.approveTokens(address(dai), amount);
    
    assertEq(dai.allowance(address(aggregator), balancer), amount);
    assertEq(dai.allowance(address(aggregator), aave), amount);
    assertEq(dai.allowance(address(aggregator), aggregator.flashLenderAddress()), amount);
    vm.stopPrank();
}

function test_approveTokens_withoutAuthorization() public {
    vm.expectRevert('Only owner');
    aggregator.approveTokens(address(dai), 1000);
    vm.stopPrank();
}

function test_flashLoanMultiple_worksWithOnlyBalancer() public {
    vm.startPrank(governor);
    dai.approve(address(aggregator), type(uint256).max);
    deal(address(dai), address(aggregator), 100 ether);
    aggregator.approveTokens(address(dai), type(uint256).max);
    
    vm.mockCall(
        balancer,
        abi.encodeWithSelector(IBalancer.flashLoan.selector),
        abi.encode()
    );
    
    aggregator.flashLoanMultiple(1 ether, address(dai), '');
    vm.stopPrank();
}

function test_flashLoanMultiple_worksWithOnlyAave() public {
    vm.startPrank(governor);
    dai.approve(address(aggregator), type(uint256).max);
    deal(address(dai), address(aggregator), 100 ether);
    aggregator.approveTokens(address(dai), type(uint256).max);
    
    vm.mockCall(
        aave,
        abi.encodeWithSelector(IAAVE.flashLoanSimple.selector),
        abi.encode(true)
    );
    
    aggregator.flashLoanMultiple(1 ether, address(dai), '');
    vm.stopPrank();
}


function test_receiveFlashLoan_revertsWhenNotBalancer() public {
    vm.startPrank(makeAddr("attacker"));
    address[] memory tokens = new address[](1);
    uint256[] memory amounts = new uint256[](1);
    uint256[] memory feeAmounts = new uint256[](1);
    vm.expectRevert("Only Balancer");
    aggregator.receiveFlashLoan(tokens, amounts, feeAmounts, '');
    vm.stopPrank();
}

function test_executeOperation_revertsWhenNotAave() public {
    vm.startPrank(makeAddr("attacker"));
    vm.expectRevert("Only Aave");
    aggregator.executeOperation(address(dai), 1 ether, 0, address(this), '');
    vm.stopPrank();
}

function test_executeOperation_revertsWhenWrongInitiator() public {
    vm.startPrank(aave);
    vm.expectRevert("Unauthorized");
    aggregator.executeOperation(address(dai), 1 ether, 0, makeAddr("wrong"), '');
    vm.stopPrank();
}

function test_onFlashLoan_revertsWhenNotFlashLender() public {
    vm.startPrank(makeAddr("attacker"));
    vm.expectRevert("Only Flash Lender");
    aggregator.onFlashLoan(address(this), address(dai), 1 ether, 0, '');
    vm.stopPrank();
}

function test_onFlashLoan_revertsWhenWrongInitiator() public {
    vm.startPrank(address(aggregator.flashLenderAddress()));
    vm.expectRevert("Unauthorized");
    aggregator.onFlashLoan(makeAddr("wrong"), address(dai), 1 ether, 0, '');
    vm.stopPrank();
}

}

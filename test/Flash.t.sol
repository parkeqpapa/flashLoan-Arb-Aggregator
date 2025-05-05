// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {Flash} from 'src/Flash.sol';

contract FlashLoanVaultTest is Test {
  address OwnerWallet;
  address user1;
  address user2;
  address user3;
  Flash flash;
  MockFlashLoanReceiver borrower;
  MockUSDC usdc;

  function setUp() public {
    OwnerWallet = makeAddr('OwnerWallet');
    user1 = makeAddr('user1');
    user2 = makeAddr('user2');

    usdc = new MockUSDC();
    usdc.mint(user1, 10 ether);
    usdc.mint(user2, 10 ether);
    usdc.mint(OwnerWallet, 10 ether);
    flash = new Flash(address(usdc));

    vm.startPrank(OwnerWallet);
    usdc.approve(address(flash), type(uint256).max);
    usdc.transfer(address(flash), 10 ether);
    vm.stopPrank();

    vm.startPrank(user1);
    borrower = new MockFlashLoanReceiver(address(flash));
    // console2.log(address(borrower).balance);
    // console2.log(usdc.balanceOf(address(borrower)));
    console2.log(usdc.balanceOf(address(flash)));
    vm.stopPrank();
  }

  function test_flashLoan() public {
    vm.startPrank(user1);
    usdc.transfer(address(borrower), 0.0001 ether);
    flash.flashLoan(borrower, address(usdc), 10, '');
    assertEq(usdc.balanceOf(address(flash)), 10.0001 ether);
    assertEq(usdc.balanceOf(address(borrower)), 0);
    console2.log(usdc.balanceOf(address(borrower)));
  }

  function test_revert_loan_repay_failed() public {
    vm.startPrank(user1);
    FlashLoanAttacker attacker = new FlashLoanAttacker();
    usdc.transfer(address(attacker), 0.1 ether);
    vm.expectRevert();
    flash.flashLoan(attacker, address(usdc), 10, '');
  }
}

contract MockFlashLoanReceiver is IERC3156FlashBorrower, Test {
  address public lender;

  constructor(
    address _lender
  ) {
    lender = _lender;
  }

  function onFlashLoan(
    address sender,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external returns (bytes32) {
    // Perform your logic here
    IERC20(token).approve(msg.sender, type(uint256).max);
    return keccak256('ERC3156FlashBorrower.onFlashLoan');
  }
}

contract MockUSDC is ERC20 {
  constructor() ERC20('USDC', 'USDC') {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

contract FlashLoanAttacker is IERC3156FlashBorrower {
  constructor() {}

  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    // try to send the loan to ourselves
    IERC20(token).transfer(initiator, amount + fee);
    return keccak256('IERC3156FlashBorrower.onFlashLoan');
  }
}

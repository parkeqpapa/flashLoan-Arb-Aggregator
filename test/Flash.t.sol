// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Test, console2} from 'forge-std/Test.sol';

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {Flash} from 'src/Flash.sol';

contract FlashLoanVaultTest is Test {
  address public ownerWallet;
  address public user1;
  address public user2;
  address public user3;
  Flash public flash;
  MockFlashLoanReceiver public borrower;
  MockUSDC public usdc;

  function setUp() public {
    ownerWallet = makeAddr('OwnerWallet');
    user1 = makeAddr('user1');
    user2 = makeAddr('user2');

    usdc = new MockUSDC();
    usdc.mint(user1, 10 ether);
    usdc.mint(user2, 10 ether);
    usdc.mint(ownerWallet, 10 ether);
    flash = new Flash(address(usdc));

    vm.startPrank(ownerWallet);
    usdc.approve(address(flash), type(uint256).max);
    usdc.transfer(address(flash), 10 ether);
    vm.stopPrank();

    vm.startPrank(user1);
    borrower = new MockFlashLoanReceiver(address(flash));
    // console2.log(address(borrower).balance);
    // console2.log(usdc.balanceOf(address(borrower)));
    // console2.log(usdc.balanceOf(address(flash)));
    vm.stopPrank();
  }

  function testflashLoan() public {
    vm.startPrank(user1);
    usdc.transfer(address(borrower), 0.0001 ether);
    flash.flashLoan(borrower, address(usdc), 10, '');
    assertEq(usdc.balanceOf(address(flash)), 10.0001 ether);
    assertEq(usdc.balanceOf(address(borrower)), 0);
    // console2.log(usdc.balanceOf(address(borrower)));
  }

  function testRevertLoanRepayFailed() public {
    vm.startPrank(user1);
    FlashLoanAttacker attacker = new FlashLoanAttacker();
    usdc.transfer(address(attacker), 0.1 ether);
    vm.expectRevert();
    flash.flashLoan(attacker, address(usdc), 10, '');
  }

  function testFlashLoanRevertsWhenInsufficientBalance() public {
    vm.startPrank(user1);
    uint256 excessiveAmount = usdc.balanceOf(address(flash)) + 1;
    vm.expectRevert("Insufficient balance");
    flash.flashLoan(borrower, address(usdc), excessiveAmount, '');
    vm.stopPrank();
}

function testFlashLoanRevertsWhenCallbackFails() public {
    vm.startPrank(user1);
    BadBorrower badBorrower = new BadBorrower();
    usdc.transfer(address(badBorrower), 0.0001 ether);
    
    vm.expectRevert("Callback failed");
    flash.flashLoan(badBorrower, address(usdc), 10, '');
    vm.stopPrank();
}

function testFlashLoanTransfersCorrectAmounts() public {
    vm.startPrank(user1);
    usdc.transfer(address(borrower), 1.1 ether);
    uint256 initialBalance = usdc.balanceOf(address(flash));
    uint256 loanAmount = 0.001 ether;
    uint256 fee = flash.flashFee(address(usdc), loanAmount);
    
    flash.flashLoan(borrower, address(usdc), loanAmount, '');
    
    uint256 expectedFinalBalance = initialBalance + fee;
    assertEq(
        usdc.balanceOf(address(flash)), 
        expectedFinalBalance,
        "Contract should end with initial balance + fee"
    );
    vm.stopPrank();
}

function testFlashLoanZeroAmount() public {
    vm.startPrank(user1);
    usdc.transfer(address(borrower), 1.1 ether);
    flash.flashLoan(borrower, address(usdc), 0, '');
    vm.stopPrank();
}

function testFlashLoanMaxAmount() public {
    vm.startPrank(user1);
    uint256 maxAmount = flash.maxFlashLoan(address(usdc));
    usdc.transfer(address(borrower), flash.flashFee(address(usdc), maxAmount));
    flash.flashLoan(borrower, address(usdc), maxAmount, '');
    vm.stopPrank();
}

function testMaxFlashLoanReturnsZeroForNonSupportedToken() public view {
    address randomToken = address(0x123);
    uint256 maxLoan = flash.maxFlashLoan(randomToken);
    assertEq(maxLoan, 0, "Should return 0 for non-supported token");
}

function testMaxFlashLoanReturnsCorrectBalanceForSupportedToken() public view {
    uint256 contractBalance = usdc.balanceOf(address(flash));
    uint256 maxLoan = flash.maxFlashLoan(address(usdc));
    assertEq(maxLoan, contractBalance, "Should return full balance for supported token");
}

}

contract MockUSDC is ERC20 {
  constructor() ERC20('USDC', 'USDC') {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
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
    IERC20(token).approve(msg.sender, type(uint256).max);
    return keccak256('ERC3156FlashBorrower.onFlashLoan');
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
    IERC20(token).transfer(initiator, amount + fee);
    return keccak256('IERC3156FlashBorrower.onFlashLoan');
  }
}
contract BadBorrower is IERC3156FlashBorrower {
    function onFlashLoan(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes32) {
        return keccak256("WrongSelector"); 
    }
}

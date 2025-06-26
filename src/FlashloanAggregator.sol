// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAAVE} from 'src/interfaces/IAave.sol';
import {IBalancer} from 'src/interfaces/IBalancer.sol';
import {Flash} from 'src/Flash.sol';

/**
 * @title FlashloanAggregator
 * @notice A flash loan aggregator that distributes loans across multiple DeFi protocols
 * @dev This contract aggregates flash loans from Balancer (50%), Aave (30%), and a custom Flash lender (20%)
 *      to optimize for better rates and liquidity distribution
 * @author parkeqpapa
 */
contract FlashloanAggregator is IERC3156FlashBorrower {
    /// @notice The owner of the contract who can execute flash loans and manage approvals
    address public owner;
    
    /// @notice The Balancer vault address for flash loans
    address payable balancerAddress;
    
    /// @notice The Aave lending pool address for flash loans
    address public aaveAddress;
    
    /// @notice The custom Flash lender contract address
    address public flashLenderAddress;

    /// @notice Percentage allocated to Balancer flash loans (50%)
    uint256 public constant BALANCER_PCT = 50;
    
    /// @notice Percentage allocated to Aave flash loans (30%)
    uint256 public constant AAVE_PCT = 30;
    
    /// @notice Percentage allocated to Flash lender (20%)
    uint256 public constant FLASH_LENDER_PCT = 20;
    
    /// @notice Base percentage for calculations (100%)
    uint256 public constant PCT_BASE = 100;

    /**
     * @notice Restricts function access to the contract owner only
     * @dev Reverts with "Only owner" if caller is not the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, 'Only owner');
        _;
    }

    /**
     * @notice Constructs the FlashloanAggregator contract
     * @dev Sets the owner to the deployer and initializes all protocol addresses
     * @param _balancerAddress The Balancer vault address
     * @param _aaveAddress The Aave lending pool address
     * @param _flashLenderAddress The custom Flash lender address
     */
    constructor(address payable _balancerAddress, address _aaveAddress, address _flashLenderAddress) {
        owner = msg.sender;
        balancerAddress = _balancerAddress;
        aaveAddress = _aaveAddress;
        flashLenderAddress = _flashLenderAddress;
    }

    /**
     * @notice Executes flash loans across multiple protocols simultaneously
     * @dev Distributes the total amount across Balancer (50%), Aave (30%), and Flash lender (20%)
     * @param totalAmount The total amount to borrow across all protocols
     * @param token The token address to borrow
     * @param data Arbitrary data to pass to the flash loan callbacks
     */
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

    /**
     * @notice Callback function for Balancer flash loans
     * @dev This function is called by Balancer after the flash loan is executed
     *      It repays the loan by transferring tokens back to Balancer
     * @param tokens Array of token addresses borrowed
     * @param amounts Array of amounts borrowed for each token
     * @param feeAmounts Array of fees charged for each token
     * @param userData Arbitrary data passed from the flash loan request
     */
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

    /**
     * @notice Callback function for Aave flash loans
     * @dev This function is called by Aave after the flash loan is executed
     *      It approves Aave to pull back the loan amount plus premium
     * @param asset The address of the asset being borrowed
     * @param amount The amount borrowed
     * @param premium The fee charged by Aave
     * @param initiator The address that initiated the flash loan
     * @param params Arbitrary data passed from the flash loan request
     * @return success Always returns true to indicate successful execution
     */
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

    /**
     * @inheritdoc IERC3156FlashBorrower
     * @dev Callback function for ERC-3156 compliant flash loans
     *      Approves the flash lender to pull back the loan amount plus fee
     * @notice This function is called by the Flash lender after the loan is executed
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == flashLenderAddress, 'Only Flash Lender');
        require(initiator == address(this), 'Unauthorized');
        IERC20(token).approve(msg.sender, type(uint256).max);
        return keccak256('ERC3156FlashBorrower.onFlashLoan');
    }

    /**
     * @notice Approves tokens for all flash loan protocols
     * @dev Allows the owner to set token approvals for Balancer, Aave, and Flash lender
     * @param token The token address to approve
     * @param amount The amount to approve for each protocol
     */
    function approveTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).approve(balancerAddress, amount);
        IERC20(token).approve(aaveAddress, amount);
        IERC20(token).approve(flashLenderAddress, amount);
    }
}
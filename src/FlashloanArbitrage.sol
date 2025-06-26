// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC3156FlashBorrower} from '@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol';
import {IERC3156FlashLender} from '@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IUniswapV2Router02} from 'src/interfaces/uniswap.sol';

/**
 * @title FlashloanArbitrage
 * @notice A flash loan arbitrage contract that exploits price differences between Uniswap and Sushiswap
 * @dev This contract borrows tokens via flash loans, executes arbitrage trades between DEXs,
 *      and repays the loan while keeping the profit
 * @author parkeqpapa
 */
contract FlashloanArbitrage is IERC3156FlashBorrower {
    /// @notice The owner of the contract who can execute arbitrage and withdraw profits
    address public owner;
    
    /// @notice The flash lender contract used for borrowing tokens
    IERC3156FlashLender public flashLender;
    
    /// @notice Uniswap V2 router for executing trades
    IUniswapV2Router02 public uniswapRouter;
    
    /// @notice Sushiswap router for executing trades
    IUniswapV2Router02 public sushiswapRouter;

    /// @notice Thrown when caller is not authorized to perform the operation
    error Unauthorized();
    
    /// @notice Thrown when caller is not the contract owner
    error NotOwner();
    
    /// @notice Thrown when there are insufficient tokens to withdraw
    error InsufficientBalance();

    /**
     * @notice Restricts function access to the contract owner only
     * @dev Reverts with NotOwner error if caller is not the owner
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(); 
        _;
    }

    /**
     * @notice Constructs the FlashloanArbitrage contract
     * @dev Initializes all necessary contract addresses and sets the deployer as owner
     * @param _flashLender The ERC-3156 compliant flash lender contract address
     * @param _uniswapRouter The Uniswap V2 router contract address
     * @param _sushiswapRouter The Sushiswap router contract address
     */
    constructor(address _flashLender, address _uniswapRouter, address _sushiswapRouter) {
        owner = msg.sender;
        flashLender = IERC3156FlashLender(_flashLender);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        sushiswapRouter = IUniswapV2Router02(_sushiswapRouter);
    }

    /**
     * @notice Executes an arbitrage opportunity using flash loans
     * @dev Initiates a flash loan and triggers the arbitrage logic in the callback
     * @param tokenBorrow The token to borrow for the arbitrage
     * @param amount The amount of tokens to borrow
     * @param data Encoded data containing the target token for arbitrage
     */
    function executeArbitrage(address tokenBorrow, uint256 amount, bytes calldata data) external onlyOwner {
        flashLender.flashLoan(IERC3156FlashBorrower(address(this)), tokenBorrow, amount, data);
    }

    /**
     * @inheritdoc IERC3156FlashBorrower
     * @dev Executes the arbitrage strategy:
     *      1. Swaps borrowed tokens for target token on Uniswap
     *      2. Swaps target token back to borrowed token on Sushiswap
     *      3. Repays the flash loan with fee
     *      4. Keeps any remaining profit
     * @notice This function is called automatically by the flash lender
     * @notice The arbitrage profit (if any) remains in the contract for later withdrawal
     */
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

    /**
     * @notice Withdraws accumulated profits from the contract
     * @dev Transfers the entire balance of the specified token to the owner
     * @param tokenAddress The address of the token to withdraw
     */
    function withdrawToken(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert InsufficientBalance();
        token.transfer(owner, balance);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library DataTypes {
  type InterestRateMode is uint8;

  struct CollateralConfig {
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
  }

  struct EModeCategoryBaseConfiguration {
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    string label;
  }

  struct EModeCategoryLegacy {
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    address priceSource;
    string label;
  }

  struct ReserveConfigurationMap {
    uint256 data;
  }

  struct ReserveDataLegacy {
    ReserveConfigurationMap configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 unbacked;
    uint128 isolationModeTotalDebt;
  }

  struct UserConfigurationMap {
    uint256 data;
  }
}

interface IAAVE {
  event BackUnbacked(address indexed reserve, address indexed backer, uint256 amount, uint256 fee);
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 borrowRate,
    uint16 indexed referralCode
  );
  event DeficitCovered(address indexed reserve, address caller, uint256 amountCovered);
  event DeficitCreated(address indexed user, address indexed debtAsset, uint256 amountCreated);
  event FlashLoan(
    address indexed target,
    address initiator,
    address indexed asset,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 premium,
    uint16 indexed referralCode
  );
  event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );
  event MintUnbacked(
    address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint16 indexed referralCode
  );
  event MintedToTreasury(address indexed reserve, uint256 amountMinted);
  event Repay(address indexed reserve, address indexed user, address indexed repayer, uint256 amount, bool useATokens);

  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );
  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);
  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);
  event Supply(
    address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint16 indexed referralCode
  );
  event UserEModeSet(address indexed user, uint8 categoryId);
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  function ADDRESSES_PROVIDER() external view returns (address);
  function BRIDGE_PROTOCOL_FEE() external view returns (uint256);
  function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
  function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);
  function MAX_NUMBER_RESERVES() external view returns (uint16);
  function POOL_REVISION() external view returns (uint256);
  function UMBRELLA() external view returns (bytes32);
  function backUnbacked(address asset, uint256 amount, uint256 fee) external returns (uint256);
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;
  function configureEModeCategory(uint8 id, DataTypes.EModeCategoryBaseConfiguration memory category) external;
  function configureEModeCategoryBorrowableBitmap(uint8 id, uint128 borrowableBitmap) external;
  function configureEModeCategoryCollateralBitmap(uint8 id, uint128 collateralBitmap) external;
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function dropReserve(
    address asset
  ) external;
  function eliminateReserveDeficit(address asset, uint256 amount) external;
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) external;
  function flashLoan(
    address receiverAddress,
    address[] memory assets,
    uint256[] memory amounts,
    uint256[] memory interestRateModes,
    address onBehalfOf,
    bytes memory params,
    uint16 referralCode
  ) external;
  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes memory params,
    uint16 referralCode
  ) external;
  function getBorrowLogic() external pure returns (address);
  function getBridgeLogic() external pure returns (address);
  function getConfiguration(
    address asset
  ) external view returns (DataTypes.ReserveConfigurationMap memory);
  function getEModeCategoryBorrowableBitmap(
    uint8 id
  ) external view returns (uint128);
  function getEModeCategoryCollateralBitmap(
    uint8 id
  ) external view returns (uint128);
  function getEModeCategoryCollateralConfig(
    uint8 id
  ) external view returns (DataTypes.CollateralConfig memory);
  function getEModeCategoryData(
    uint8 id
  ) external view returns (DataTypes.EModeCategoryLegacy memory);
  function getEModeCategoryLabel(
    uint8 id
  ) external view returns (string memory);
  function getEModeLogic() external pure returns (address);
  function getFlashLoanLogic() external pure returns (address);
  function getLiquidationGracePeriod(
    address asset
  ) external view returns (uint40);
  function getLiquidationLogic() external pure returns (address);
  function getPoolLogic() external pure returns (address);
  function getReserveAToken(
    address asset
  ) external view returns (address);
  function getReserveAddressById(
    uint16 id
  ) external view returns (address);
  function getReserveData(
    address asset
  ) external view returns (DataTypes.ReserveDataLegacy memory);
  function getReserveDeficit(
    address asset
  ) external view returns (uint256);
  function getReserveNormalizedIncome(
    address asset
  ) external view returns (uint256);
  function getReserveNormalizedVariableDebt(
    address asset
  ) external view returns (uint256);
  function getReserveVariableDebtToken(
    address asset
  ) external view returns (address);
  function getReservesCount() external view returns (uint256);
  function getReservesList() external view returns (address[] memory);
  function getSupplyLogic() external pure returns (address);
  function getUserAccountData(
    address user
  )
    external
    view
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );
  function getUserConfiguration(
    address user
  ) external view returns (DataTypes.UserConfigurationMap memory);
  function getUserEMode(
    address user
  ) external view returns (uint256);
  function getVirtualUnderlyingBalance(
    address asset
  ) external view returns (uint128);
  function initReserve(
    address asset,
    address aTokenAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external;
  function initialize(
    address provider
  ) external;
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;
  function mintToTreasury(
    address[] memory assets
  ) external;
  function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256);
  function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256);
  function rescueTokens(address token, address to, uint256 amount) external;
  function resetIsolationModeTotalDebt(
    address asset
  ) external;
  function setConfiguration(address asset, DataTypes.ReserveConfigurationMap memory configuration) external;
  function setLiquidationGracePeriod(address asset, uint40 until) external;
  function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress) external;
  function setUserEMode(
    uint8 categoryId
  ) external;
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
  function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;
  function syncIndexesState(
    address asset
  ) external;
  function syncRatesState(
    address asset
  ) external;
  function updateBridgeProtocolFee(
    uint256 protocolFee
  ) external;
  function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

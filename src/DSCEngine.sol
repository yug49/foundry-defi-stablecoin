//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Yug Agarwal
 *
 * The system is desined to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg
 * This stable coin has the properties
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed value of all DSC.
 *
 * @notice This contract is the core of the DSC System. it handles all the lofic for mining and redeeming DSC, as well as depositing & withdrawing collateral
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    /* Errors */
    error DSCEngine__NeedMoreThanZeroAmount();
    error DSCEngine__TokenNotAllowedToBeUsedAsCollateral();
    error DSCEngine__TokkenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);

    /* State Variables */
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private i_dsc;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;    //200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;  
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    /* Events */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    /* Modifiers */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedMoreThanZeroAmount();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowedToBeUsedAsCollateral();
        }
        _;
    }

    /* Functions */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        //USD Price Feed
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokkenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /* External Functions */
    function depositCollateralAndMintDsc() external {}

    /**
     * @notice follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success) revert DSCEngine__TransferFailed();
        else{
            s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
            emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        }

    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    // Threshold to let's day 150%
    // $100 ETH -> $74 ETH -> UNDERCOLLATERALIZED!!!
    // $50 DSC
    // Hey, if someone pays back you minted DSC, they can hace all your collateral for a discount

    //Check if Collateral value > DSC amount
    /**
     * @notice follows CEI
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than min threshold
     */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant{
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted) {
            revert DSCEngine__MintFailed();
        }
        
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /* Private and Internal View Functions */
    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);

        return(totalDscMinted, collateralValueInUsd);
    }

    /**
     * Retuns how close to liquidation a user is
     * If user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns(uint256) {
        // total DSC minted
        // total Collateral value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral)
        // 2. revert is bad health factor
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR) revert DSCEngine__BreaksHealthFactor(userHealthFactor);

    }

    /* Public and External Functions */
    function getAccountCollateralValueInUsd(address user) public view returns(uint256 totalCollateralValueInUse) {
        // loop through each collateral token, get the amount they have deposited, and map it to the price, to get the usd value
        for(uint256 i = 0 ; i < s_collateralTokens.length; i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUse += getUsdValue(token, amount);
        }

        return totalCollateralValueInUse;
    }

    function getUsdValue(address token , uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // if 1 eth = 1000 usd
        // then the returned value from the cl will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}

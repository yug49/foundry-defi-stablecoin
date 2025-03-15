// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant INTITIAL_MINT = 1 ether;
    uint256 public constant HEALTH_FACTOR = 10000;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed,, weth,wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        
    }

    /* Constructor Tests */
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    function testRevertsIfTokenLengthDoesntMathPriceFeedLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokkenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    

    /* Price Tests */
    function testGetUsdValue() public view{
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view{
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /* Deposite Collateral Tests */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount); 

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedMoreThanZeroAmount.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public{
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowedToBeUsedAsCollateral.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositeCollateralAndGetAccountInfo() public depositedCollateral{
        (uint256 totalDscMinted, uint256 collateralValueUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositeAmount = dsce.getTokenAmountFromUsd(weth, collateralValueUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositeAmount);
    }

    function testDepositeCollateralemitsCollateralDeposited() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectEmit(true,true, true, false);
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    /* Mint Dsc and HealthFactor */
    function testIfNoMintThenHealthFactorIsZero() public depositedCollateral{
        assertEq(dsce.getHealthFactor(USER), type(uint256).max);
    }

    modifier mintDsc(){
        vm.prank(USER);
        dsce.mintDsc(INTITIAL_MINT);
        _;
    }
    
    function testMintDscMints() public depositedCollateral mintDsc{
        assertEq(dsce.getDscOfAUser(USER), INTITIAL_MINT);
    }

    function testHealthFactor() public depositedCollateral mintDsc{
        // assertEq(dsce.getHealthFactor(USER), 
        console.log(dsce.getHealthFactor(USER));
        assertEq(dsce.getHealthFactor(USER), HEALTH_FACTOR);
    }

    function test_revertIfHealthFactorIsBrokenRevertsIfHealthFactorIsBroken() public depositedCollateral{
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0);
        dsce.mintDsc(10000 ether);
    }


    /* redeem collatoeral */
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    function testUserRedeemsCollatralAndEmitsTheEvent() public depositedCollateral{
        vm.prank(USER);
        vm.expectEmit(true, true, true, true);
        emit CollateralRedeemed(USER, USER, weth, 1 ether);
        dsce.redeemCollateral(weth, 1 ether);
        assertEq(dsce.getCollateralTokenAmount(USER, weth), 9 ether);
    }

    function testRevertIfUserRedeemsTooMuchCollateral() public depositedCollateral mintDsc{
        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
    }

    /* burn DSC */
    function testBurnDscBurnsDscb() public depositedCollateral mintDsc{
        vm.startPrank(USER);
        dsc.approve(address(dsce), 0.4 ether);
        dsce.burnDsc(0.4 ether);
        (uint256 dscLeft,) = dsce.getAccountInformation(USER);
        assertEq(dscLeft, 0.6 ether);
    }

    function testDepositeCollateralAndMintDSC() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, INTITIAL_MINT);
        vm.stopPrank();
        assertEq(dsce.getDscOfAUser(USER), INTITIAL_MINT);
        assertEq(dsce.getCollateralTokenAmount(USER, weth), AMOUNT_COLLATERAL);
    }

    function testRedeemCollateralForDsc() public depositedCollateral mintDsc{
        vm.startPrank(USER);
        dsc.approve(address(dsce), 0.5 ether);
        dsce.redeemCollateralForDsc(weth, 5 ether, 0.5 ether);
        vm.stopPrank();
        assertEq(dsce.getCollateralTokenAmount(USER, weth), 5 ether);
        (uint256 dscLeft,) = dsce.getAccountInformation(USER);
        assertEq(dscLeft, 0.5 ether);
    }

    function testTotalCollateralInUsd() public depositedCollateral{
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);
        
        vm.startPrank(USER);
        ERC20Mock(wbtc).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(wbtc, AMOUNT_COLLATERAL);

        
        vm.stopPrank();

        uint256 totalCollateralInUsd = dsce.getAccountCollateralValueInUsd(USER);
        
        uint256 actualValue =  dsce.getUsdValue(weth, AMOUNT_COLLATERAL) + dsce.getUsdValue(wbtc, AMOUNT_COLLATERAL);

        assertEq(totalCollateralInUsd,actualValue);

    }

    /* liquidate */

    function testLiquidate() public depositedCollateral{
        // Liquidator setup
        ERC20Mock(weth).mint(LIQUIDATOR, 200 ether);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), 200 ether);
        dsce.depositCollateral(weth, 200 ether);
        dsce.mintDsc(100 ether);
        vm.stopPrank();

        // depositing 10 ether = 2000 * 10 = 20,000 usd
        // minting 100 ether = 100 * 1 = 100 usd

        // Mint more DSC 
        vm.prank(USER);
        dsce.mintDsc(100 ether); // Mint 100 DSC (pegged to $100)

        // Simulate a price drop to make the user undercollateralized
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(15e8); // Price dropped to $15 (from $2000) -> user's collateral = 150 usd against 100 usd dsc

        // new health factor = 0.75
        uint256 healthFactorBefore = dsce.getHealthFactor(USER);
        console.log("Health Factor before Liquidation:", healthFactorBefore);

        uint256 debtToClear = 100 ether;    //100 dsc

        // Liquidator approves DSCEngine to spend their DSC tokens
        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dsce), debtToClear); // Approve 100 DSC for liquidation

        console.log("before liq balance: ", dsce.getCollateralTokenAmount(LIQUIDATOR, weth));

        // Liquidator liquidates the user
        dsce.liquidate(weth, USER, debtToClear); // Liquidate 100 DSC
        vm.stopPrank();

        // Check user's health factor after liquidation
        uint256 healthFactorAfter = dsce.getHealthFactor(USER);
        console.log("Health Factor After Liquidation:", healthFactorAfter);
        assertGt(healthFactorAfter, healthFactorBefore, "Health factor should improve after liquidation");

        // Check liquidator's collateral balance
        console.log("after liq balance: ", dsce.getCollateralTokenAmount(LIQUIDATOR, weth));
        uint256 liquidatorCollateralBalance = dsce.getCollateralTokenAmount(LIQUIDATOR, weth);
        uint256 initialMint = 200 ether;
        uint256 redeemedWeth = (debtToClear/15e8) * 1e8;
        uint256 bonus = redeemedWeth/10;

        assertEq(liquidatorCollateralBalance, initialMint + redeemedWeth + bonus, "Liquidators balance should be his initial + redeemed + 10 % bonus of redeemed collateral");

        // Check user's DSC balance
        uint256 userDscBalance = dsce.getDscOfAUser(USER);
        assertEq(userDscBalance, 0, "User's DSC balance should be zero after liquidation");

        // Check user's collateral balance
        uint256 userCollateralBalance = dsce.getCollateralTokenAmount(USER, weth);
        assertLt(userCollateralBalance, AMOUNT_COLLATERAL, "User's collateral balance should be reduced");

    }
}

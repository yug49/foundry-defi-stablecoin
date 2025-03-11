// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

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
        assertEq(dsce.getHealthFactor(USER), 100);
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

    function testLiquidateU() public depositedCollateral mintDsc{
        
    }


}

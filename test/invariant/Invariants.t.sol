// SPDX-License-Identifier: MIT

// Have ur invariants aka properties

// what are our invariants?
// 1. the total supply of dsc should be less than total value of collateral
// 2. getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";


contract Invariants is StdInvariant, Test{
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;
    uint256 public constant TEST_AMOUNT = 100;
    

    function setUp() external{
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,,weth,wbtc,) = config.activeNetworkConfig();
        // targetContract(address(dsce));   
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
        // hey don't call redeem collateral unless there is a collaretal to redeem
    }

    function invariant_protocalMustHaveMoreValueThanTheTotalSupply() public view{
        // get the value of all the collateral in the protocol
        // compare it to all the debt(dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value:", wethValue);
        console.log("wbtc value:", wbtcValue);
        console.log("total supply:", totalSupply);
        console.log("time mint called:", handler.timesMintIsCalled());



        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShoulNotRevert() public view{
        dsce.getHealthFactor(msg.sender);
        dsce.getAccountCollateralValueInUsd(msg.sender);
        dsce.getUsdValue(weth, TEST_AMOUNT);
        dsce.getUsdValue(wbtc, TEST_AMOUNT);
        dsce.getTokenAmountFromUsd(weth, TEST_AMOUNT);
        dsce.getTokenAmountFromUsd(wbtc, TEST_AMOUNT);
        dsce.getAccountInformation(msg.sender);
        dsce.getDscOfAUser(msg.sender);
        dsce.getCollateralTokenAmount(msg.sender, wbtc);
        dsce.getCollateralTokenAmount(msg.sender, weth);
        dsce.getCollateralTokens();
        dsce.getMaxCollateralToRedeem(msg.sender, wbtc);
        dsce.getMaxCollateralToRedeem(msg.sender, weth);
        dsce.getCollateralTokenPriceFeed(wbtc);
        dsce.getCollateralTokenPriceFeed(weth);
    }
}

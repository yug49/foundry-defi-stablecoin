//SPDX-License-Identifier: MIT

// handler is going to narrow down the way we call functions

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 MAX_DEPOSIT_SIZE = 100e30;  // max deposite limit is 100 trillion tokens

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }

    function mintDsc(uint256 amount) public {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(msg.sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if(maxDscToMint < 0) return;
        amount = bound(amount, 0, uint256(maxDscToMint));
        if(amount == 0) return;
        vm.startPrank(msg.sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
    }

    // redeem collateral -> call only when you have collateral
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        console.log(msg.sender);
        uint256 maxCollateralToReedeem = dsce.getMaxCollateralToRedeem(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateralToReedeem);
        if(amountCollateral == 0) return;
        //vm.assume(amountCollateral != 0); // same for above commented 
        vm.prank(msg.sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    /* Helper Function */
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if(collateralSeed % 2 == 0 ) return weth;
        else return wbtc;
    }
}
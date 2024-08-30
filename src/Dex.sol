// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Dex is ERC20 {

    IERC20 public tokenX;
    IERC20 public tokenY;

    uint public totalLiquidity;
    uint public constant FEE_RATE = 999; // 0.1% fee (1000 - 999)

    constructor(address _tokenX, address _tokenY) ERC20("Dex Liquidity Token", "DLP") {
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
    }

    function _sqrt(uint x) public returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
            }
    }

    function addLiquidity(uint amountX, uint amountY, uint minLP) external returns (uint lpTokens) {
        require(amountX > 0 && amountY > 0, "Invalid amounts");
        require(amountX <= tokenX.allowance(msg.sender, address(this)) &&
         amountY <= tokenY.allowance(msg.sender, address(this)), "ERC20: insufficient allowance");
        require(amountX <= tokenX.balanceOf(msg.sender) &&
         amountY <= tokenY.balanceOf(msg.sender), "ERC20: transfer amount exceeds balance");

        if (totalLiquidity == 0) {
            lpTokens = _sqrt(amountX * amountY);
        } else {
            uint poolX = tokenX.balanceOf(address(this));
            uint poolY = tokenY.balanceOf(address(this));

            uint lpTokenX = (amountX * totalSupply()) / poolX;
            uint lpTokenY = (amountY * totalSupply()) / poolY;

            lpTokens = lpTokenX < lpTokenY ? lpTokenX : lpTokenY;
        }

        require(lpTokens >= minLP, "LP tokens less than minimum");

        _mint(msg.sender, lpTokens);
        totalLiquidity += lpTokens;

        tokenX.transferFrom(msg.sender, address(this), amountX);
        tokenY.transferFrom(msg.sender, address(this), amountY);
    }

    function removeLiquidity(uint lpTokens, uint minX, uint minY) external returns (uint amountX, uint amountY) {
        require(lpTokens > 0 && lpTokens <= balanceOf(msg.sender), "Invalid LP amount");

        uint poolX = tokenX.balanceOf(address(this));
        uint poolY = tokenY.balanceOf(address(this));

        amountX = (poolX * lpTokens) / totalSupply();
        amountY = (poolY * lpTokens) / totalSupply();

        require(amountX >= minX && amountY >= minY, "Insufficient output");

        _burn(msg.sender, lpTokens);
        totalLiquidity -= lpTokens;

        require(tokenX.transfer(msg.sender, amountX), "Transfer failed");
        require(tokenY.transfer(msg.sender, amountY), "Transfer failed");
    }

    function swap(uint amountX, uint amountY, uint minOutput) external returns (uint output) {
        require((amountX == 0 && amountY > 0) || (amountX > 0 && amountY == 0), "Invalid swap amounts");

        uint poolX = tokenX.balanceOf(address(this));
        uint poolY = tokenY.balanceOf(address(this));

        if (amountX > 0) {
            uint newPoolX = poolX + amountX;
            uint newPoolY = (poolX * poolY) / newPoolX;
            output = poolY - newPoolY;

            output = (output * FEE_RATE) / 1000;

            require(output >= minOutput, "Insufficient output");

            tokenX.transferFrom(msg.sender, address(this), amountX);
            tokenY.transfer(msg.sender, output);
        } else {
            uint newPoolY = poolY + amountY;
            uint newPoolX = (poolX * poolY) / newPoolY;
            output = poolX - newPoolX;

            output = (output * FEE_RATE) / 1000;

            require(output >= minOutput, "Insufficient output");

            tokenY.transferFrom(msg.sender, address(this), amountY);
            tokenX.transfer(msg.sender, output);
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dex {
    ERC20 public tokenX;
    ERC20 public tokenY;
    uint public totalSupply;

    cosntructor(address _tokenX, address _tokenY) {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }

    function addLiquidity(uint256 amountX, uint256 amountY) public onlyOwner returns(uint256 lpToken){
        if(totalSupply == 0) {
            lpToken = amountX + amountY;
        } else {
            uint lpX
        }
    }


}

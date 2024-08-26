// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "src/DreamAcademyLending.sol";

contract CUSDC is ERC20 {
    constructor() ERC20("Circle Stable Coin", "USDC") {
        _mint(msg.sender, type(uint256).max);
    }
}

contract DreamOracle {
    address public operator;
    mapping(address => uint256) prices;

    constructor() {
        operator = msg.sender;
    }

    function getPrice(address token) external view returns (uint256) {
        require(prices[token] != 0, "the price cannot be zero");
        return prices[token];
    }

    function setPrice(address token, uint256 price) external {
        require(msg.sender == operator, "only operator can set the price");
        prices[token] = price;
    }
}

contract Testx is Test {
    DreamOracle dreamOracle;
    DreamAcademyLending lending;
    ERC20 usdc;

    address user1;
    address user2;
    address user3;
    address user4;

    function setUp() external {
        user1 = address(0x1337);
        user2 = address(0x1337 + 1);
        user3 = address(0x1337 + 2);
        user4 = address(0x1337 + 3);
        dreamOracle = new DreamOracle();

        vm.deal(address(this), 10000000 ether);
        usdc = new CUSDC();

        // TDOO 아래 setUp이 정상작동 할 수 있도록 여러분의 Lending Contract를 수정하세요.
        lending = new DreamAcademyLending(IPriceOracle(address(dreamOracle)), address(usdc));
        usdc.approve(address(lending), type(uint256).max);

        lending.initializeLendingProtocol{value: 1}(address(usdc)); // set reserve ^__^

        dreamOracle.setPrice(address(0x0), 1339 ether);
        dreamOracle.setPrice(address(usdc), 1 ether);
    }

    function testDepositEtherWithoutTxValueFails() external {
        (bool success,) = address(lending).call{value: 0 ether}(
            abi.encodeWithSelector(DreamAcademyLending.deposit.selector, address(0x0), 1 ether)
        );
        assertFalse(success);
    }

    function testDepositEtherWithInsufficientValueFails() external {
        (bool success,) = address(lending).call{value: 2 ether}(
            abi.encodeWithSelector(DreamAcademyLending.deposit.selector, address(0x0), 3 ether)
        );
        assertFalse(success);
    }

    function testDepositEtherWithEqualValueSucceeds() external {
        (bool success,) = address(lending).call{value: 2 ether}(
            abi.encodeWithSelector(DreamAcademyLending.deposit.selector, address(0x0), 2 ether)
        );
        assertTrue(success);
        assertTrue(address(lending).balance == 2 ether + 1);
    }

    function testDepositUSDCWithInsufficientValueFails() external {
        usdc.approve(address(lending), 1);
        (bool success,) = address(lending).call(
            abi.encodeWithSelector(DreamAcademyLending.deposit.selector, address(usdc), 3000 ether)
        );
        assertFalse(success);
    }

    function testDepositUSDCWithEqualValueSucceeds() external {
        (bool success,) = address(lending).call(
            abi.encodeWithSelector(DreamAcademyLending.deposit.selector, address(usdc), 2000 ether)
        );
        assertTrue(success);
        assertTrue(usdc.balanceOf(address(lending)) == 2000 ether + 1);
    }

    function supplyUSDCDepositUser1() private {
        usdc.transfer(user1, 100000000 ether);
        vm.startPrank(user1);
        usdc.approve(address(lending), type(uint256).max);
        lending.deposit(address(usdc), 100000000 ether);
        vm.stopPrank();
    }

    function supplyEtherDepositUser2() private {
        vm.deal(user2, 100000000 ether);
        vm.prank(user2);
        lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);
    }

    function supplySmallEtherDepositUser2() private {
        vm.deal(user2, 100000000 ether);
        vm.startPrank(user2);
        lending.deposit{value: 1 ether}(address(0x00), 1 ether);
        vm.stopPrank();
    }

    function testBorrowWithInsufficientCollateralFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 1339 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertFalse(success);
            assertTrue(usdc.balanceOf(user2) == 0 ether);
        }
        vm.stopPrank();
    }

    function testBorrowWithInsufficientSupplyFails() external {
        supplySmallEtherDepositUser2();
        dreamOracle.setPrice(address(0x0), 99999999999 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertFalse(success);
            assertTrue(usdc.balanceOf(user2) == 0 ether);
        }
        vm.stopPrank();
    }

    function testBorrowWithSufficientCollateralSucceeds() external {
        supplyUSDCDepositUser1();
        supplyEtherDepositUser2();

        vm.startPrank(user2);
        {
            lending.borrow(address(usdc), 1000 ether);
            assertTrue(usdc.balanceOf(user2) == 1000 ether);
        }
        vm.stopPrank();
    }

    function testBorrowWithSufficientSupplySucceeds() external {
        supplyUSDCDepositUser1();
        supplyEtherDepositUser2();

        vm.startPrank(user2);
        {
            lending.borrow(address(usdc), 1000 ether);
        }
        vm.stopPrank();
    }

    function testBorrowMultipleWithInsufficientCollateralFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 3000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertFalse(success);

            assertTrue(usdc.balanceOf(user2) == 1000 ether);
        }
        vm.stopPrank();
    }

    function testBorrowMultipleWithSufficientCollateralSucceeds() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);
        }
        vm.stopPrank();
    }

    function testBorrowWithSufficientCollateralAfterRepaymentSucceeds() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.repay.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testBorrowWithInSufficientCollateralAfterRepaymentFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);

            vm.roll(block.number + 1);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.repay.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertFalse(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 999 ether)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testWithdrawInsufficientBalanceFails() external {
        vm.deal(user2, 100000000 ether);
        vm.startPrank(user2);
        {
            lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);

            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000001 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testWithdrawUnlockedBalanceSucceeds() external {
        vm.deal(user2, 100000000 ether);
        vm.startPrank(user2);
        {
            lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);

            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000001 ether - 1 ether)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testWithdrawMultipleUnlockedBalanceSucceeds() external {
        vm.deal(user2, 100000000 ether);
        vm.startPrank(user2);
        {
            lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);

            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000000 ether / 4)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000000 ether / 4)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000000 ether / 4)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 100000000 ether / 4)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testWithdrawLockedCollateralFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 1 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testWithdrawLockedCollateralAfterBorrowSucceeds() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether); // 4000 usdc

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            // 2000 / (4000 - 1333) * 100 = 74.xxxx
            // LT = 75%
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 1 ether * 1333 / 4000)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testWithdrawLockedCollateralAfterInterestAccuredFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether); // 4000 usdc

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            // 2000 / (4000 - 1333) * 100 = 74.xxxx
            // LT = 75%
            vm.roll(block.number + 1000);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 1 ether * 1333 / 4000)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testWithdrawYieldSucceeds() external {
        usdc.transfer(user3, 30000000 ether);
        vm.startPrank(user3);
        usdc.approve(address(lending), type(uint256).max);
        lending.deposit(address(usdc), 30000000 ether);
        vm.stopPrank();

        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        bool success;

        vm.startPrank(user2);
        {
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 1 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();

        vm.roll(block.number + (86400 * 1000 / 12));
        vm.prank(user3);
        assertTrue(lending.getAccruedSupplyAmount(address(usdc)) / 1e18 == 30000792);

        vm.roll(block.number + (86400 * 500 / 12));
        vm.prank(user3);
        assertTrue(lending.getAccruedSupplyAmount(address(usdc)) / 1e18 == 30001605);

        vm.prank(user3);
        (success,) = address(lending).call(
            abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(usdc), 30001605 ether)
        );
        assertTrue(success);
        assertTrue(usdc.balanceOf(user3) == 30001605 ether);

        assertTrue(lending.getAccruedSupplyAmount(address(usdc)) / 1e18 == 0);
    }

    function testExchangeRateChangeAfterUserBorrows() external {
        usdc.transfer(user3, 30000000 ether);
        vm.startPrank(user3);
        usdc.approve(address(lending), type(uint256).max);
        lending.deposit(address(usdc), 30000000 ether);
        vm.stopPrank();

        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 1000 ether)
            );
            assertTrue(success);

            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.withdraw.selector, address(0x0), 1 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();

        vm.roll(block.number + (86400 * 1000 / 12));
        vm.prank(user3);
        assertTrue(lending.getAccruedSupplyAmount(address(usdc)) / 1e18 == 30000792);

        // other lender deposits USDC to our protocol.
        usdc.transfer(user4, 10000000 ether);
        vm.startPrank(user4);
        usdc.approve(address(lending), type(uint256).max);
        lending.deposit(address(usdc), 10000000 ether);
        vm.stopPrank();

        vm.roll(block.number + (86400 * 500 / 12));
        vm.prank(user3);
        uint256 a = lending.getAccruedSupplyAmount(address(usdc));

        vm.prank(user4);
        uint256 b = lending.getAccruedSupplyAmount(address(usdc));

        vm.prank(user1);
        uint256 c = lending.getAccruedSupplyAmount(address(usdc));

        assertEq((a + b + c) / 1e18 - 30000000 - 10000000 - 100000000, 6956);
        assertEq(a / 1e18 - 30000000, 1547);
        assertEq(b / 1e18 - 10000000, 251);
    }

    function testWithdrawFullUndilutedAfterDepositByOtherAccountSucceeds() external {
        vm.deal(user2, 100000000 ether);
        vm.startPrank(user2);
        {
            lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);
        }
        vm.stopPrank();

        vm.deal(user3, 100000000 ether);
        vm.startPrank(user3);
        {
            lending.deposit{value: 100000000 ether}(address(0x00), 100000000 ether);
        }
        vm.stopPrank();

        vm.startPrank(user2);
        {
            lending.withdraw(address(0x00), 100000000 ether);
            assertEq(address(user2).balance, 100000000 ether);
        }
        vm.stopPrank();
    }

    function testLiquidationHealthyLoanFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        usdc.transfer(user3, 3000 ether);
        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 800 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testLiquidationUnhealthyLoanSucceeds() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        dreamOracle.setPrice(address(0x0), (4000 * 66 / 100) * 1e18); // drop price to 66%
        usdc.transfer(user3, 3000 ether);

        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 500 ether)
            );
            assertTrue(success);
        }
        vm.stopPrank();
    }

    function testLiquidationExceedingDebtFails() external {
        // ** README **
        // can liquidate the whole position when the borrowed amount is less than 100,
        // otherwise only 25% can be liquidated at once.
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        dreamOracle.setPrice(address(0x0), (4000 * 66 / 100) * 1e18); // drop price to 66%
        usdc.transfer(user3, 3000 ether);

        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 501 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testLiquidationHealthyLoanAfterPriorLiquidationFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        dreamOracle.setPrice(address(0x0), (4000 * 66 / 100) * 1e18); // drop price to 66%
        usdc.transfer(user3, 3000 ether);

        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 500 ether)
            );
            assertTrue(success);
            (success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 100 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testLiquidationAfterBorrowerCollateralDepositFails() external {
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), (4000 * 66 / 100) * 1e18); // drop price to 66%
        usdc.transfer(user3, 3000 ether);

        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 500 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    function testLiquidationAfterDebtPriceDropFails() external {
        // just imagine if USDC falls down
        supplyUSDCDepositUser1();
        supplySmallEtherDepositUser2();

        dreamOracle.setPrice(address(0x0), 4000 ether);

        vm.startPrank(user2);
        {
            // use all collateral
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.borrow.selector, address(usdc), 2000 ether)
            );
            assertTrue(success);

            assertTrue(usdc.balanceOf(user2) == 2000 ether);

            usdc.approve(address(lending), type(uint256).max);
        }
        vm.stopPrank();

        dreamOracle.setPrice(address(0x0), (4000 * 66 / 100) * 1e18); // drop Ether price to 66%
        dreamOracle.setPrice(address(usdc), 1e17); // drop USDC price to 0.1, 90% down
        usdc.transfer(user3, 3000 ether);

        vm.startPrank(user3);
        {
            usdc.approve(address(lending), type(uint256).max);
            (bool success,) = address(lending).call(
                abi.encodeWithSelector(DreamAcademyLending.liquidate.selector, user2, address(usdc), 500 ether)
            );
            assertFalse(success);
        }
        vm.stopPrank();
    }

    receive() external payable {
        // for ether receive
    }
}
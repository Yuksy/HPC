// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.0;

import  "../token/ERC20/IERC20.sol";
import  "../token/ERC20/utils/SafeERC20.sol";
import  "../utils/Address.sol";
import  "../utils/Context.sol";
import  "../access/Ownable.sol";

/**
 * @dev A vesting wallet is an ownable contract that can receive native currency and ERC-20 tokens, and release these
 * assets to the wallet owner, also referred to as "beneficiary", according to a vesting schedule.
 *
 * Any assets transferred to this contract will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, any amount of tokens sent to this contract will (at least partly)
 * be immediately releasable.
 *
 * By setting the duration to 0, one can configure this contract to behave like an asset timelock that hold tokens for
 * a beneficiary until a specified time.
 *
 * NOTE: Since the wallet is {Ownable}, and ownership can be transferred, it is possible to sell unvested tokens.
 * Preventing this in a smart contract is difficult, considering that: 1) a beneficiary address could be a
 * counterfactually deployed contract, 2) there is likely to be a migration path for EOAs to become contracts in the
 * near future.
 *
 * NOTE: When using this contract with any token whose balance is adjusted automatically (i.e. a rebase token), make
 * sure to account the supply/balance adjustment in the vesting schedule to ensure the vested amount is as intended.
 */
contract VestingWallet is Context, Ownable {

    using SafeERC20 for IERC20;
    
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    event VestingSchedule(uint256 index,uint256 preStageSupply,uint256 amount);
    event ReleasedAmount(uint256 amount);

    event DebugInfo(uint256 tokenBalance, address receiver, uint256 amount);

    uint256 private _released;
    mapping(address => uint256) private erc20Released;
    uint64 private immutable _start;
    uint64 private immutable _duration;

    uint256[10] public stageArrary;
    uint256[10] public stageSupplyArrary;
    uint256 public constant startTime = 946656000;
    uint256 public constant endTime = 2208960000;
    uint256 public constant totalSupply = 210000000 * 10 ** 18;
    uint256 private constant fourYearSec =  (60 * 60 * 24 * 36525 * 4) / 100;

    /**
     * @dev Sets the sender as the initial owner, the beneficiary as the pending owner, the start timestamp and the
     * vesting duration of the vesting wallet.
     */
    // constructor(address beneficiary, uint64 startTimestamp, uint64 durationSeconds) payable Ownable(beneficiary) {
    constructor(address beneficiary) payable Ownable(beneficiary) {
        // uint256 startTimestamp = 946656000;
        // uint256 durationSeconds = 1262304000;
        _start = 946656000;
        _duration = 1262304000;
        generateStageSupply(10000000 * 10 ** 18);
        generateStage(_start);
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Amount of eth already released
     */
    // function released() public view virtual returns (uint256) {
    //     return _released;
    // }

    /**
     * @dev Amount of token already released
     */
    function released(address token) public view virtual returns (uint256) {
        return erc20Released[token];
    }

    /**
     * @dev Getter for the amount of releasable eth.
     */
    // function releasable(uint256 timestamp) public virtual returns (uint256) {
    //     return vestedAmount(timestamp) - released();
    // }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * {IERC20} contract.
     */
    function releasable(address token,uint256 timestamp) public virtual returns (uint256) {
        uint256 releasedAmount = vestedAmount(token, timestamp) - released(token);
        emit ReleasedAmount(releasedAmount);
        return releasedAmount;
    }

    /**
     * @dev Release the native token (ether) that have already vested.
     *
     * Emits a {EtherReleased} event.
     */
    // function release(uint256 timestamp) public virtual {
    //     uint256 amount = releasable(timestamp);
    //     _released += amount;
    //     emit EtherReleased(amount);
    //     Address.sendValue(payable(owner()), amount);
    // }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token,uint256 timestamp) public virtual {
        uint256 amount = releasable(token,timestamp);
        erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        // SafeERC20.safeTransfer(IERC20(token), owner(), amount);
        IERC20(token).safeTransfer(owner(), amount);
    }

    function give(address token,uint256 amount,address receiver)public virtual{
        emit DebugInfo(IERC20(token).balanceOf(address(this)), receiver, amount);
        IERC20(token).safeTransfer(receiver, amount);
    }

    /**
     * @dev Calculates the amount of ether that has already vested. Default implementation is a linear vesting curve.
     */
    // function vestedAmount(uint256 timestamp) public virtual returns (uint256) {
    //     return _vestingSchedule(address(this).balance + released(), timestamp);
    // }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(address token, uint256 timestamp) public virtual returns (uint256) {
        // return vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token), timestamp);
        return vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token),timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function vestingSchedule(uint256 totalAllocation,uint256 timestamp) public virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            uint index = getStageIndex(timestamp);
            uint durationSupply = stageSupplyArrary[index];
            uint currentStage = stageArrary[index];
            uint256 preStageSupply = 0;
            for (uint256 i = 0; i < index; i++) {
                    preStageSupply += stageSupplyArrary[i];
                }   
            uint256 amount =  preStageSupply + ((durationSupply * (timestamp - currentStage)) / fourYearSec);
            emit VestingSchedule(index,preStageSupply, amount);
            return amount ;

            // return (totalAllocation * (timestamp - start())) / duration();
        }
    }

    function generateStage(uint256 timestamp)private returns (uint256[10] memory){
        require(timestamp > 0);
       
        // uint256[10] memory stageArrary ;
        for(uint256 i = 0; i < 10; i++) {
            stageArrary[i] = timestamp ;
            timestamp += fourYearSec ;
        }
        return stageArrary;
    }

    function generateStageSupply(uint256 totalsupply)private returns (uint256[10] memory){
        require(totalsupply > 0);
        // uint256[10] memory stageSupplyArrary ;
        uint256 stageSupply = (totalsupply * 10 / 1023) ;
        for (uint256 i = 0; i < 10; i ++){
            stageSupplyArrary[9-i] = stageSupply / 10;
            stageSupply = stageSupply * 2;
        }
        return stageSupplyArrary;
    }

    function getStageSupplyArrary() public view  returns (uint256[10] memory){
        return stageSupplyArrary;
    }

    function getStageArrary () public view returns (uint256[10] memory){
        return stageArrary;
    }

    function getStageIndex(uint256 timestamp) public view virtual returns (uint256){
        uint256 duraction = (endTime - startTime);
        uint256 gap = (timestamp - startTime);
        return (gap * 100 / duraction) / 10;
    }
}

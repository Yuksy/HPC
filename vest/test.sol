pragma solidity ^0.8.0;

import {IERC20} from "../tokens/IERC20.sol";
import {SafeERC20} from "../tokens/utils/SafeERC20.sol";
import {Ownable} from "../access/Ownable.sol";

contract TestContract {

    uint256[10] public stageArrary;
    uint256[10] public stageSupplyArrary;
    uint256 public constant startTime = 946656000;
    uint256 public constant endTime = 2208960000;
    uint256 public constant totalSupply = 210000000;
    uint256 private constant fourYearSec =  (60 * 60 * 24 * 36525 * 4) / 100;
    uint256 public released;

    event VestingSchedule(
        uint256 index,
        uint256 preStageSupply,
        uint256 amount
    );

    event ReleasedAmount(
        uint256 amount
    );


    // constructor (uint256 _startTimeStamp, uint256 _endTimeStamp,uint256 _totalSupply){
    constructor (){

        stageArrary = generateStage(startTime);
        stageSupplyArrary = generateStageSupply(totalSupply);

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

    function release(uint256 timestamp,address token,address beneficiary) public virtual returns (uint256) {
        uint256 amount = releasable(timestamp);
        released += amount;
        emit ReleasedAmount(amount);
        SafeERC20.safeTransfer(IERC20(token), owner(), amount);
        
    }

    function releasable(uint256 timestamp) private returns (uint256) {
        return vestedAmount(timestamp) - released;
    }

    function vestedAmount(uint256 timestamp) private returns (uint256) {
        return _vestingSchedule(timestamp);
    }

    function _vestingSchedule(uint timestamp) private returns (uint256){
        if (timestamp < startTime) {
            return 0;
        }
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
    }

}
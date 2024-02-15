
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SnoozupContract { 

    struct userPool {
        address wallet;
        bytes32 pool;
    }
    struct winnersList {
        uint challengeId;
        address[] winners;
    }
    // All of below variable should be private
    address public owner;
    address[] public owners;
    mapping(uint => userPool[]) public challengeUsers;
    mapping(uint => uint) public challengeBalances;
    mapping(bytes32 => address) public allowedTokens;
    uint public paymentLimit;
    uint public commission;

    constructor() {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier isValidPayment() {
        require(msg.value == paymentLimit, "Incorrect payment amount");
        _;
    }

    function setOwner(address newOwner) public isOwner {
        owners.push(newOwner);
    }

    function getOwners() public view isOwner returns(address[] memory){
        return owners;
    }


    function removeOwner(address targetOwner) public isOwner {
        for ( uint i = 0; i < owners.length; i++) 
        {
            if (owners[i] == targetOwner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
    }

    function addAllowedToken(bytes32 pool, address tokenAddress) public isOwner {
        allowedTokens[pool] = tokenAddress;
    }

    function setCommision(uint limit) public isOwner {
        commission = limit;
    }

    function getCommision() public view isOwner returns(uint) {
        return commission;
    }

    function setPaymentLimit(uint limit) public isOwner {
        paymentLimit = limit;
    }

    function getPaymentLimit() public view isOwner returns(uint){
        return paymentLimit;
    }

    function joinToChallenge( uint challengeId, bytes32 pool, uint amount ) public {
        // require(allowedTokens[pool] != address(0), "Token is not allowed/supported");

        // require(IERC20(allowedTokens[pool]).allowance(msg.sender, address(this)) >= msg.value, "Not approved to send balance requested");
        
        // bool success = IERC20(allowedTokens[pool]).transferFrom(msg.sender, address(this), msg.value);

        // require(success, "Transaction was not successful");

        // challengeBalances[challengeId] += msg.value;

        challengeUsers[challengeId].push(userPool(msg.sender, pool));

        // Check that the sender has sufficient token balance

        require(IERC20(allowedTokens[pool]).balanceOf(msg.sender) >= amount, "Insufficient token balance");

        ERC20(allowedTokens[pool]).approve(address(this), amount);

        // Transfer the tokens from the sender to this contract
        ERC20(allowedTokens[pool]).transferFrom(msg.sender, address(this), amount);

        // // Invoke the payable function
        // payable(msg.sender).transfer(amount);
    }

    function releaseEscrowedTokens(bytes32 pool, uint amount, address to) public {

        require(IERC20(allowedTokens[pool]).balanceOf(address(this)) >= amount, "Insufficient token balance");

        ERC20(allowedTokens[pool]).transfer(to, amount);
    }


    function calculateCompetitionBonus(uint challengeId, address[] memory winners) public {
        uint balance = challengeBalances[challengeId];

        require(balance > 0, "Insufficient balance");

        uint calculatedCommision = balance / commission;

        challengeBalances[challengeId] -= calculatedCommision;

        uint bonus = challengeBalances[challengeId] / winners.length;

        for ( uint i = 0; i < winners.length; i++) 
        {

            challengeBalances[challengeId] -= bonus;

            payable(winners[i]).transfer(bonus);

        }

    }

}
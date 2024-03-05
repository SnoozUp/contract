
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

contract SnzupBeta { 

    enum ChallengeStatus{ PENDING, INPROGRESS, CLOSED }
    
    struct UserPool {
        address wallet;
        bytes32 pool;
        bool subscribe;
    }

    struct Challenge {
        uint startDate;
        uint finishDate;
        ChallengeStatus status;
        uint fee;
    }

    address private owner;

    address[] private allowedUsers;
    
    mapping(address => bool) private whitelistAddress;
    mapping(uint => Challenge) private challenges;
    mapping(uint => UserPool[]) private challengeUsers;
    mapping(uint => uint) private challengeBalances;
    mapping(uint => address) private winnersList;

    uint private commission;

    event SubscriptionCreated(address indexed subscriber, uint timestamp);
    event SubscriptionCancelled(address indexed subscriber, uint timestamp);

    constructor() {
        owner = msg.sender;
        whitelistAddress[msg.sender] = true;
        allowedUsers.push(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    modifier onlyAllowedUsers() {
        require( whitelistAddress[msg.sender], "Only contract owner an allowed users can call this function");
        _;
    }

    modifier subscribed(uint challengeId) {
        bool exists = false;
        for (uint i = 0; i < challengeUsers[challengeId].length; i++) {
            if (challengeUsers[challengeId][i].wallet == msg.sender) {
                exists = true;
                break;
            }
        }
        require(exists, "User not subscribed");
        _;
    }

    modifier notSubscribed(uint challengeId) {
        bool exists = false;
        for (uint i = 0; i < challengeUsers[challengeId].length; i++) {
            if (challengeUsers[challengeId][i].wallet == msg.sender) {
                exists = true;
                break;
            }
        }
        require(!exists, "User already subscribed");
        _;
    }

    modifier chalengeIsValid(uint challengeId) {
        require(challenges[challengeId].status == ChallengeStatus.PENDING, "Challenge is in progress or expired");
        _;
    }

    function setOwner(address user) public onlyOwner {
       whitelistAddress[user] = true;
       allowedUsers.push(user);
    }

    function getOwners() public view onlyOwner returns(address[] memory){
        return  allowedUsers;
    }

    function removeOwner(address user) public onlyOwner {
        delete whitelistAddress[user];
        for ( uint i = 0; i < allowedUsers.length; i++) 
        {
            if (allowedUsers[i] == user) {
                allowedUsers[i] = allowedUsers[allowedUsers.length - 1];
                allowedUsers.pop();
                break;
            }
        }

    }

    function setCommision(uint commissionPercentage) public onlyAllowedUsers {
        commission = commissionPercentage;
    }

    function getCommision() public view onlyAllowedUsers returns(uint) {
        return commission;
    }

    function setChallenge(uint challengeId, uint startDate, uint finishDate, uint fee) public onlyAllowedUsers {
        challenges[challengeId] = Challenge(startDate, finishDate, ChallengeStatus.PENDING, fee);
    }

    function getChallenge(uint challengeId) external view returns(Challenge memory) {
        return challenges[challengeId];
    }

    function changeChallengeStatus(uint challengeId, ChallengeStatus status) public onlyAllowedUsers {
        challenges[challengeId].status = status;
    }

    function subscribe(uint challengeId, bytes32 pool) external payable notSubscribed(challengeId) chalengeIsValid(challengeId) {
        require(msg.value == challenges[challengeId].fee, "Incorrect subscription fee");
        challengeUsers[challengeId].push(UserPool(msg.sender, pool, true));
        challengeBalances[challengeId] += challenges[challengeId].fee;
        emit SubscriptionCreated(msg.sender, block.timestamp);
    }

    function cancelSubscription(uint challengeId) external {
        for (uint i = 0; i < challengeUsers[challengeId].length; i++) {
            if (challengeUsers[challengeId][i].wallet == msg.sender) {
                challengeUsers[challengeId][i].subscribe = false;
                payable(msg.sender).transfer(challenges[challengeId].fee); // Refund subscription fee
                challengeBalances[challengeId] -= challenges[challengeId].fee;
                emit SubscriptionCancelled(msg.sender, block.timestamp);
                break;
            }
        }
    }

    function calculateCompetitionBonus(uint challengeId, uint winnersCount) internal onlyAllowedUsers returns(uint, uint) {
        uint balance = challengeBalances[challengeId];

        require(balance > 0, "Insufficient balance");

        uint calculatedCommision = balance * commission / 100; 

        challengeBalances[challengeId] -= calculatedCommision;

        uint bonus = challengeBalances[challengeId] / winnersCount;

        return (calculatedCommision, bonus);

    }

    function sendBonusToWinners(uint challengeId, address[] memory winners) external onlyAllowedUsers {

        (, uint bonus) = calculateCompetitionBonus(challengeId, winners.length);

        for ( uint i = 0; i < winners.length; i++) 
        {

            challengeBalances[challengeId] -= bonus;

            payable(winners[i]).transfer(bonus);

        }

    }

    function withdrawFunds() external onlyOwner {
        uint share = address(this).balance /  allowedUsers.length;
        for ( uint i = 0; i < allowedUsers.length; i++) 
        {
            payable(allowedUsers[i]).transfer(share);
        }
    }
}
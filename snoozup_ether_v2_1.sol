// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

contract SnzupBeta {
    enum ChallengeStatus {
        PENDING,
        INPROGRESS,
        CLOSED
    }

    struct UserSubscription {
        address wallet;
        bool subscribe;
    }

    address private owner;

    address[] private allowedUsers;
    ChallengeStatus private status;
    uint private fee;
    mapping(address => bool) private whitelistAddress;
    uint private challengeId;
    UserSubscription[] private challengeUsers;
    address[] private winnersList;

    uint private commission;

    event SubscriptionCreated(address indexed subscriber, uint timestamp);
    event SubscriptionCancelled(address indexed subscriber, uint timestamp);
    event KeepUpTriggered(uint indexed timestamp);
    event CommisionAndBonusCalculated(
        uint indexed commission,
        uint indexed bonus,
        uint timestamp
    );
    event BonusSent(address indexed subscriber, uint timestamp);

    constructor() {
        owner = msg.sender;
        whitelistAddress[msg.sender] = true;
        allowedUsers.push(msg.sender);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can call this function"
        );
        _;
    }

    modifier onlyAllowedUsers() {
        require(
            whitelistAddress[msg.sender],
            "Only contract owner an allowed users can call this function"
        );
        _;
    }

    modifier subscribed() {
        bool exists = false;
        for (uint i = 0; i < challengeUsers.length; i++) {
            if (
                challengeUsers[i].wallet == msg.sender &&
                challengeUsers[i].subscribe
            ) {
                exists = true;
            }
        }

        require(exists, "User not subscribed");
        _;
    }

    modifier notSubscribed() {
        bool exists = false;
        for (uint i = 0; i < challengeUsers.length; i++) {
            if (
                challengeUsers[i].wallet == msg.sender &&
                challengeUsers[i].subscribe
            ) {
                exists = true;
                break;
            }
        }
        require(!exists, "User already subscribed");
        _;
    }

    modifier chalengeIsValid() {
        require(
            status == ChallengeStatus.PENDING,
            "Challenge is in progress or expired"
        );
        _;
    }

    function setOwner(address user) public onlyOwner {
        whitelistAddress[user] = true;
        allowedUsers.push(user);
    }

    function getOwners() public view onlyOwner returns (address[] memory) {
        return allowedUsers;
    }

    function removeOwner(address user) public onlyOwner {
        delete whitelistAddress[user];
        for (uint i = 0; i < allowedUsers.length; i++) {
            if (allowedUsers[i] == user) {
                allowedUsers[i] = allowedUsers[allowedUsers.length - 1];
                allowedUsers.pop();
                break;
            }
        }
    }

    function setCommision(uint commissionPercentage) external onlyAllowedUsers {
        commission = commissionPercentage;
    }

    function getCommision() external view onlyAllowedUsers returns (uint) {
        return commission;
    }

    function changeChallengeStatus(
        ChallengeStatus _status
    ) external onlyAllowedUsers {
        status = _status;
    }

    function setWinnersList(
        address[] memory winners
    ) external onlyAllowedUsers {
        for (uint i = 0; i < winners.length; i++) {
            winnersList.push(winners[i]);
        }
    }

    function getWinnersList()
        external
        view
        onlyAllowedUsers
        returns (address[] memory)
    {
        return winnersList;
    }

    function setFee(uint _fee) external {
        fee = _fee;
    }

    function getFee() external view returns (uint) {
        return fee;
    }

    function subscribe() external payable notSubscribed chalengeIsValid {
        require(msg.value == fee, "Incorrect subscription fee");
        challengeUsers.push(UserSubscription(msg.sender, true));
        emit SubscriptionCreated(msg.sender, block.timestamp);
    }

    function cancelSubscription() external {
        for (uint i = 0; i < challengeUsers.length; i++) {
            if (challengeUsers[i].wallet == msg.sender) {
                challengeUsers[i].subscribe = false;
                payable(msg.sender).transfer(fee); // Refund subscription fee
                emit SubscriptionCancelled(msg.sender, block.timestamp);
                break;
            }
        }
    }

    function calculateCompetitionBonus(
        uint winnersCount
    ) internal view onlyAllowedUsers returns (uint, uint) {
        uint balance = address(this).balance;

        require(balance > 0, "Insufficient balance");

        uint calculatedCommision = (balance * commission) / 100;

        uint challengeBalance = balance - calculatedCommision;

        uint bonus = challengeBalance / winnersCount;

        return (calculatedCommision, bonus);
    }

    function sendBonusToWinners() external onlyAllowedUsers {
        if (winnersList.length > 0) {
            emit KeepUpTriggered(block.timestamp);
            (uint calculatedCommision, uint bonus) = calculateCompetitionBonus(
                winnersList.length
            );
            emit CommisionAndBonusCalculated(
                calculatedCommision,
                bonus,
                block.timestamp
            );

            for (uint i = 0; i < winnersList.length; i++) {
                payable(winnersList[i]).transfer(bonus);
                emit BonusSent(winnersList[i], block.timestamp);
            }
        }
    }

    function withdrawFunds() external onlyOwner {
        uint share = address(this).balance / allowedUsers.length;
        for (uint i = 0; i < allowedUsers.length; i++) {
            payable(allowedUsers[i]).transfer(share);
        }
    }
}

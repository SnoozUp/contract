// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

contract Snzup {
    enum ChallengeStatus {
        PENDING,
        INPROGRESS,
        CLOSED
    }

    address private owner;
    ChallengeStatus private status;
    uint private fee;
    mapping(address => bool) private whitelistAddress;
    uint private challengeId;
    mapping(address => bool) private challengeUsers;
    address[] private winnersList;

    uint private commission;
    uint private operationFee = 0;

    uint private _callDepth = 0;

    event SubscriptionCreated(address indexed subscriber,uint indexed value, uint timestamp);
    event SubscriptionCancelled(address indexed subscriber, uint timestamp);
    event KeepUpTriggered(uint indexed timestamp);
    event CommisionAndBonusCalculated(
        uint indexed commission,
        uint indexed bonus,
        uint timestamp
    );
    event BonusSent(address indexed subscriber, uint timestamp);
    event RefundSent(address indexed subscriber, uint timestamp);

    constructor(uint _challengeId, uint _fee, uint _commission) {
        owner = msg.sender;
        whitelistAddress[msg.sender] = true;
        challengeId = _challengeId;
        fee = _fee;
        commission = _commission;
        status = ChallengeStatus.PENDING;
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

    function setOwner(address user) public onlyOwner {
        whitelistAddress[user] = true;
    }

    function isOwner(address user) public view onlyOwner returns (bool) {
        return whitelistAddress[user];
    }

    function removeOwner(address user) public onlyOwner {
        if (whitelistAddress[user]) {
            whitelistAddress[user] = false;
        }
    }

    function setCommision(uint commissionPercentage) external onlyOwner {
        commission = commissionPercentage;
    }

    function getCommision() external view onlyOwner returns (uint) {
        return commission;
    }

    function changeChallengeStatus(ChallengeStatus _status) external onlyOwner {
        uint gasBefore = gasleft();

        status = _status;

        uint gasAfter = gasleft();
        operationFee += gasBefore - gasAfter;
    }

    function setWinnersList(address[] memory winners) external onlyOwner {
        uint gasBefore = gasleft();
        for (uint i = 0; i < winners.length; i++) {
            winnersList.push(winners[i]);
        }
        uint gasAfter = gasleft();
        operationFee += gasBefore - gasAfter;
    }

    function getWinnersList()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return winnersList;
    }

    function getOperationFee() external view onlyOwner returns (uint) {
        return operationFee;
    }

    function getFee() external view onlyOwner returns (uint) {
        return fee;
    }

    function subscribe() external payable {
        require(!challengeUsers[msg.sender], "User already subscribed");
        require(
            status == ChallengeStatus.PENDING,
            "Challenge is in progress or expired"
        );
        require(msg.value == fee, "Incorrect subscription fee");
        challengeUsers[msg.sender] = true;
        emit SubscriptionCreated(msg.sender, msg.value, block.timestamp);
    }

    function calculateCompetitionBonus(
        uint winnersCount
    ) internal view onlyAllowedUsers returns (uint, uint) {
        uint balance = address(this).balance;

        require(balance > 0, "Insufficient balance");

        uint calculatedCommision = ((balance - operationFee) * commission) /
            100;

        uint challengeBalance = (balance + operationFee) - calculatedCommision;

        uint bonus = challengeBalance / winnersCount;

        return (calculatedCommision, bonus);
    }

    function sendBonusToWinners(address snoozupWallet) external onlyAllowedUsers {
        require(snoozupWallet != address(0), "Invalid snoozupWallet address");
        require(address(this).balance > 0, "Insufficient contract balance");

        if (winnersList.length > 0) {
            (uint calculatedCommision, uint bonus) = calculateCompetitionBonus(
                winnersList.length
            );
            emit CommisionAndBonusCalculated(
                calculatedCommision,
                bonus,
                block.timestamp
            );

            for (uint i = 0; i < winnersList.length; i++) {
                address winner = winnersList[i];
                require(winner != address(0), "Invalid winner address");

                (bool sendToWinnersSuccess, ) = payable(winner).call{value: bonus}("");
                    
                require(sendToWinnersSuccess, "Transfer to winner failed");
                emit BonusSent(winnersList[i], block.timestamp);
            }
        }

        uint remainingBalance = address(this).balance;
        require(remainingBalance > 0, "No balance left for snoozup");

        (bool sendToSnoozupSuccess, ) = payable(snoozupWallet).call{value: remainingBalance}("");
        require(sendToSnoozupSuccess, "Transfer to snoozup wallet failed");

        status = ChallengeStatus.CLOSED;
    }

    function refund(address[] calldata subscribers) external onlyOwner {
        uint totalRefund = fee * subscribers.length;

        require(address(this).balance >= totalRefund, "Insufficient contract balance");

        uint gasBefore = gasleft();
        for (uint256 i = 0; i < subscribers.length; i++) {
            address subscriber = subscribers[i];

            require(subscriber != address(0), "Invalid subscriber address");
            
            (bool sendToSubscriberSuccess, ) = payable(subscriber).call{value: fee}("");

            require(sendToSubscriberSuccess, "Transfer to subscriber failed");

            challengeUsers[subscriber] = false;

            emit RefundSent(subscriber, block.timestamp);
        }
        uint gasAfter = gasleft();
        operationFee += gasBefore - gasAfter;
    }

    function withdrawFunds() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }
}

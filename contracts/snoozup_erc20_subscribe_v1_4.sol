// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

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
    IERC20 private erc20Token;
    mapping(address => bool) private challengeUsers;
    address[] private winnersList;

    uint private commission;
    uint private operationFee = 0;

    event SubscriptionCreated(address indexed subscriber, uint timestamp);
    event SubscriptionCancelled(address indexed subscriber, uint timestamp);
    event CommisionAndBonusCalculation(
        uint indexed balance,
        uint indexed challengeBalance,
        uint timestamp
    );
    event CommisionAndBonusCalculated(
        uint indexed commission,
        uint indexed bonus,
        uint timestamp
    );
    event BonusSent(address indexed subscriber, uint timestamp);
    event RefundSent(address indexed subscriber, uint timestamp);

    constructor(
        address _erc20Address,
        uint _challengeId,
        uint _fee,
        uint _commission
    ) {
        owner = msg.sender;
        whitelistAddress[msg.sender] = true;
        challengeId = _challengeId;
        fee = _fee;
        commission = _commission;
        erc20Token = IERC20(_erc20Address);
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

    function subscribe() external {
        require(!challengeUsers[msg.sender], "User already subscribed");
        require(
            status == ChallengeStatus.PENDING,
            "Challenge is in progress or expired"
        );
        require(
            erc20Token.balanceOf(msg.sender) >= fee,
            "Insufficient balance"
        );
        require(
            erc20Token.allowance(msg.sender, address(this)) >= fee,
            "Insufficient allowance"
        );
        require(
            erc20Token.transferFrom(msg.sender, address(this), fee),
            "erc20 token transfer failed"
        );

        challengeUsers[msg.sender] = true;

        emit SubscriptionCreated(msg.sender, block.timestamp);
    }

    function calculateCompetitionBonus(
        uint winnersCount
    ) internal onlyAllowedUsers returns (uint, uint) {
        uint balance = erc20Token.balanceOf(address(this));

        require(balance > 0, "Insufficient balance");

        uint calculatedCommision = (balance * commission) / 100;

        uint challengeBalance = balance - calculatedCommision;

        uint bonus = challengeBalance / winnersCount;

        emit CommisionAndBonusCalculation(
            balance,
            challengeBalance,
            block.timestamp
        );

        return (calculatedCommision, bonus);
    }

    function sendBonusToWinners(
        address snoozupWallet
    ) external onlyAllowedUsers {
        require(snoozupWallet != address(0), "Invalid snoozupWallet address");
        require(
            erc20Token.balanceOf(address(this)) > 0,
            "Insufficient contract balance"
        );

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

                require(
                    erc20Token.approve(winner, bonus),
                    "Approval winner failed"
                );

                bool winnerTransferSuccess = erc20Token.transfer(winner, bonus);

                require(winnerTransferSuccess, "Transfer to winner failed");

                emit BonusSent(winner, block.timestamp);
            }
        }

        uint remainingBalance = erc20Token.balanceOf(address(this));
        require(remainingBalance > 0, "No balance left for snoozup");

        require(
            erc20Token.approve(snoozupWallet, remainingBalance),
            "Approval snoozup wallet failed"
        );

        bool snoozupTransferSuccess = erc20Token.transfer(
            snoozupWallet,
            remainingBalance
        );

        require(snoozupTransferSuccess, "Transfer to snoozup wallet failed");

        status = ChallengeStatus.CLOSED;
    }

    function refund(address[] calldata subscribers) external onlyOwner {
        uint totalRefund = fee * subscribers.length;

        require(
            erc20Token.balanceOf(address(this)) >= totalRefund,
            "Insufficient contract balance"
        );

        uint gasBefore = gasleft();
        for (uint256 i = 0; i < subscribers.length; i++) {
            address subscriber = subscribers[i];

            require(subscriber != address(0), "Invalid subscriber address");

            bool sendToSubscriberSuccess = erc20Token.transfer(subscriber, fee);

            require(sendToSubscriberSuccess, "Transfer to subscriber failed");

            challengeUsers[subscriber] = false;

            emit RefundSent(subscriber, block.timestamp);
        }
        uint gasAfter = gasleft();
        operationFee += gasBefore - gasAfter;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = erc20Token.balanceOf(address(this));
        require(balance > 0, "No USDC available");

        bool success = erc20Token.transfer(owner, balance);
        require(success, "USDC transfer failed");
    }
}

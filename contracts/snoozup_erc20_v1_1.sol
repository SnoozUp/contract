// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract SnzupErc20 {
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
    event CommisionAndBonusCalculated(
        uint indexed commission,
        uint indexed bonus,
        uint timestamp
    );
    event BonusSent(address indexed subscriber, uint timestamp);

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

    function sendBonusToWinners() external onlyAllowedUsers {
        if (winnersList.length > 0) {
            uint balance = erc20Token.balanceOf(address(this));

            require(balance > 0, "Insufficient balance");

            uint calculatedCommision = ((balance - operationFee) * commission) /
                100;

            uint challengeBalance = (balance + operationFee) -
                calculatedCommision;

            uint bonus = challengeBalance / winnersList.length;

            emit CommisionAndBonusCalculated(
                calculatedCommision,
                bonus,
                block.timestamp
            );

            for (uint i = 0; i < winnersList.length; i++) {
                require(
                    erc20Token.approve(winnersList[i], bonus),
                    "Approval failed"
                );

                erc20Token.transfer(winnersList[i], bonus);

                emit BonusSent(winnersList[i], block.timestamp);
            }
        }

        status = ChallengeStatus.CLOSED;
    }

    function approve(
        address to,
        uint amount
    ) external onlyOwner returns (bool) {
        return erc20Token.approve(to, amount);
    }

    function sendBonusTo(
        address to,
        uint bonus
    ) external onlyOwner returns (bool) {
        return erc20Token.transfer(to, bonus);
    }

    function withdrawFund() external onlyOwner {
        erc20Token.transferFrom(
            address(this),
            msg.sender,
            erc20Token.balanceOf(address(this))
        );
    }
}

# Snzup Ethereum Subscription Contract

This repository contains the **Snzup** Ethereum-based subscription smart contract.  
It allows participants to subscribe to challenges using native ETH, manage winners, calculate bonuses, and handle refunds.  

## Overview

- Designed for **subscription-based competitions/challenges** using **ETH** as the participation fee.  
- Implements a full challenge lifecycle: subscription, status updates, winner rewards, refunds, and fund withdrawals.  
- Commission and bonus calculations are performed automatically based on contract balance.  
- Securely distributes ETH to winners and the SnoozUp wallet at the end of a challenge.  

## Supported Networks

The contract is currently deployed and active on:

- **Ethereum Mainnet**

## Features (High-Level)

- **Subscriptions in ETH** – users join by sending the exact fee.  
- **Challenge lifecycle management** – pending → in-progress → closed.  
- **Commission + bonus distribution** – winnings are automatically calculated and distributed to winners.  

---

🚀 This smart contract powers the [SnoozUp](https://www.snoozup.io/) ecosystem.
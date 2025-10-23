# Raisr

## Overview

**Raisr** is a decentralized crowdfunding platform built on the Stacks blockchain. It enables project creators to raise funds transparently through milestone-based funding, ensuring accountability and progressive disbursement of raised capital. Contributors can fund projects confidently, track progress, and request refunds if campaign goals are not achieved.

## Key Features

* **Milestone-Based Funding:** Projects are structured into milestones with specific targets, ensuring creators can only withdraw funds upon completion of each milestone.
* **Transparent Contribution Tracking:** Every contribution is logged on-chain, allowing backers to verify their support history and amounts.
* **Refund Mechanism:** Contributors can claim refunds for unsuccessful projects after deadlines or unmet goals.
* **Platform Fee System:** A configurable percentage fee is deducted from each milestone withdrawal to sustain the platform.
* **Ownership Management:** The contract owner can transfer ownership and adjust the platform fee rate as needed.

## Core Components

### 1. **Data Structures**

* **`projects`**: Stores project metadata such as creator, goal, deadline, status, and funds raised.
* **`contributions`**: Tracks each contributor’s amount, timestamp, and refund status.
* **`milestones`**: Defines project milestones with target amounts, descriptions, and withdrawal states.
* **`project-backers`**: Keeps count of backers per project.
* **`milestone-count`**: Records the total number of milestones for each project.

### 2. **Project Lifecycle Functions**

* **`create-project`**: Initializes a new crowdfunding campaign with milestones and funding targets.
* **`contribute`**: Allows backers to contribute STX tokens to a project before the deadline.
* **`withdraw-milestone`**: Enables creators to withdraw funds for completed milestones once their targets are met.
* **`request-refund`**: Allows backers to retrieve their funds if the project fails or misses its goal.
* **`mark-project-successful` / `mark-project-failed`**: Updates project status based on goal achievements and deadlines.

### 3. **Administrative Functions**

* **`set-platform-fee`**: Adjusts the platform’s fee rate (up to 10%).
* **`transfer-ownership`**: Transfers control of the contract to a new administrator.

### 4. **Read-Only Accessors**

Provides transparency through multiple read-only endpoints:

* **Project Data:** `get-project`, `get-project-progress`, `is-project-successful`, `is-deadline-passed`
* **Milestones:** `get-milestone`, `get-milestone-count`, `can-withdraw-milestone`
* **Contributions:** `get-contribution`, `get-project-backers`
* **System Info:** `get-project-count`, `get-platform-fee`, `get-contract-owner`

## Error Codes

* **u400–u411**: Range covers authorization, invalid input, milestone mismatch, insufficient funds, and withdrawal-related issues.

## Summary

**Raisr** ensures accountability and efficiency in decentralized fundraising by integrating milestone-based releases, contributor protection, and transparent tracking. It reduces risk for backers and provides creators with a structured approach to achieving funding goals.

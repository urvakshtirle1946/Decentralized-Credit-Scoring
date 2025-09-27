// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Credit Scoring
 * @dev A smart contract for managing decentralized credit scores based on on-chain financial behavior
 */
contract Project {
    
    struct CreditProfile {
        uint256 creditScore;
        uint256 totalTransactions;
        uint256 totalVolume;
        uint256 loanDefaults;
        uint256 onTimePayments;
        bool isActive;
        uint256 lastUpdated;
    }
    
    struct LoanRecord {
        uint256 amount;
        uint256 dueDate;
        bool isPaid;
        uint256 paidDate;
        address lender;
    }
    
    mapping(address => CreditProfile) public creditProfiles;
    mapping(address => LoanRecord[]) public loanHistory;
    mapping(address => bool) public authorizedLenders;
    
    address public owner;
    uint256 public constant MIN_CREDIT_SCORE = 300;
    uint256 public constant MAX_CREDIT_SCORE = 850;
    uint256 public constant INITIAL_CREDIT_SCORE = 600;
    
    event CreditScoreUpdated(address indexed user, uint256 newScore);
    event LoanRecorded(address indexed borrower, address indexed lender, uint256 amount);
    event PaymentMade(address indexed borrower, uint256 loanIndex, bool onTime);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthorizedLender() {
        require(authorizedLenders[msg.sender], "Not an authorized lender");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedLenders[msg.sender] = true;
    }
    
    /**
     * @dev Core Function 1: Calculate and update credit score based on financial behavior
     * @param user Address of the user whose credit score needs to be updated
     */
    function updateCreditScore(address user) public {
        CreditProfile storage profile = creditProfiles[user];
        
        if (!profile.isActive) {
            profile.creditScore = INITIAL_CREDIT_SCORE;
            profile.isActive = true;
        }
        
        uint256 newScore = calculateCreditScore(user);
        
        // Ensure score stays within bounds
        if (newScore < MIN_CREDIT_SCORE) {
            newScore = MIN_CREDIT_SCORE;
        } else if (newScore > MAX_CREDIT_SCORE) {
            newScore = MAX_CREDIT_SCORE;
        }
        
        profile.creditScore = newScore;
        profile.lastUpdated = block.timestamp;
        
        emit CreditScoreUpdated(user, newScore);
    }
    
    /**
     * @dev Core Function 2: Record loan and payment history
     * @param borrower Address of the borrower
     * @param amount Loan amount in wei
     * @param dueDate Due date timestamp
     */
    function recordLoan(address borrower, uint256 amount, uint256 dueDate) 
        external 
        onlyAuthorizedLender 
    {
        require(amount > 0, "Loan amount must be greater than 0");
        require(dueDate > block.timestamp, "Due date must be in the future");
        
        loanHistory[borrower].push(LoanRecord({
            amount: amount,
            dueDate: dueDate,
            isPaid: false,
            paidDate: 0,
            lender: msg.sender
        }));
        
        // Update transaction count and volume
        CreditProfile storage profile = creditProfiles[borrower];
        if (!profile.isActive) {
            profile.isActive = true;
            profile.creditScore = INITIAL_CREDIT_SCORE;
        }
        
        profile.totalTransactions++;
        profile.totalVolume += amount;
        
        emit LoanRecorded(borrower, msg.sender, amount);
        
        // Auto-update credit score
        updateCreditScore(borrower);
    }
    
    /**
     * @dev Core Function 3: Record loan payment and update credit metrics
     * @param borrower Address of the borrower
     * @param loanIndex Index of the loan in the borrower's loan history
     */
    function recordPayment(address borrower, uint256 loanIndex) 
        external 
        onlyAuthorizedLender 
    {
        require(loanIndex < loanHistory[borrower].length, "Invalid loan index");
        
        LoanRecord storage loan = loanHistory[borrower][loanIndex];
        require(!loan.isPaid, "Loan already paid");
        require(loan.lender == msg.sender, "Only the lender can record payment");
        
        loan.isPaid = true;
        loan.paidDate = block.timestamp;
        
        CreditProfile storage profile = creditProfiles[borrower];
        
        bool onTime = block.timestamp <= loan.dueDate;
        
        if (onTime) {
            profile.onTimePayments++;
        } else {
            profile.loanDefaults++;
        }
        
        emit PaymentMade(borrower, loanIndex, onTime);
        
        // Auto-update credit score
        updateCreditScore(borrower);
    }
    
    /**
     * @dev Internal function to calculate credit score based on user's financial behavior
     * @param user Address of the user
     * @return Calculated credit score
     */
    function calculateCreditScore(address user) internal view returns (uint256) {
        CreditProfile memory profile = creditProfiles[user];
        
        if (profile.totalTransactions == 0) {
            return INITIAL_CREDIT_SCORE;
        }
        
        uint256 score = INITIAL_CREDIT_SCORE;
        
        // Payment history (35% weight) - most important factor
        if (profile.totalTransactions > 0) {
            uint256 paymentRatio = (profile.onTimePayments * 100) / profile.totalTransactions;
            if (paymentRatio >= 95) {
                score += 85; // Excellent payment history
            } else if (paymentRatio >= 80) {
                score += 60; // Good payment history
            } else if (paymentRatio >= 60) {
                score += 30; // Fair payment history
            } else {
                score -= 50; // Poor payment history
            }
        }
        
        // Default ratio penalty (20% weight)
        if (profile.loanDefaults > 0) {
            uint256 defaultRatio = (profile.loanDefaults * 100) / profile.totalTransactions;
            score -= (defaultRatio * 2); // Penalty for defaults
        }
        
        // Transaction volume bonus (15% weight)
        if (profile.totalVolume > 1 ether) {
            score += 25;
        } else if (profile.totalVolume > 0.1 ether) {
            score += 15;
        }
        
        // Transaction frequency bonus (10% weight)
        if (profile.totalTransactions >= 10) {
            score += 20;
        } else if (profile.totalTransactions >= 5) {
            score += 10;
        }
        
        return score;
    }
    
    /**
     * @dev Get comprehensive credit profile for a user
     * @param user Address of the user
     * @return CreditProfile struct containing all credit information
     */
    function getCreditProfile(address user) external view returns (CreditProfile memory) {
        return creditProfiles[user];
    }
    
    /**
     * @dev Get loan history for a user
     * @param user Address of the user
     * @return Array of LoanRecord structs
     */
    function getLoanHistory(address user) external view returns (LoanRecord[] memory) {
        return loanHistory[user];
    }
    
    /**
     * @dev Add or remove authorized lenders
     * @param lender Address of the lender
     * @param authorized Boolean indicating authorization status
     */
    function setAuthorizedLender(address lender, bool authorized) external onlyOwner {
        authorizedLenders[lender] = authorized;
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}

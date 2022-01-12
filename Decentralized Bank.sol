// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <=0.8.0;

import "./Token.sol";

contract DecentralizedBank {

  Token private token;

  // Deposit Start mapping
  mapping(address => uint) public depositStart;
  // Balance mapping
  mapping(address => uint) public oneBalanceOf;
  // Collateral mapping
  mapping(address => uint) public collateralone;
  // Money deposited mapping
  mapping(address => bool) public isDeposited;
  // Money borrowed mapping
  mapping(address => bool) public isBorrowed;

  // Deposit event
  event Deposit(
    address indexed user, 
    uint oneAmount, 
    uint timeStart
  );
  
  // Withdraw event
  event Withdraw(
    address indexed user, 
    uint oneAmount, 
    uint depositTime, 
    uint interest
  );
  
  // Borrowed event
  event Borrow(
    address indexed user, 
    uint collateraloneAmount, 
    uint borrowedTokenAmount
  );
  
  // Payoff Event
  event PayOff(
    address indexed user, 
    uint fee
  );

  // Constructor
  constructor(Token _token) {
    token = _token;
  }

  // Deposit Function to deposit ONE to earn interest
  function deposit() payable public {
    // Check if already has deposit
    require(isDeposited[msg.sender] == false, 'Error, deposit already active');
    // Check if value to be deposited is greater than 0.01 ONE
    require(msg.value>=1e16, 'Error, deposit must be >= 0.01 ONE');

    // Increment value in mapping
    oneBalanceOf[msg.sender] = oneBalanceOf[msg.sender] + msg.value;
    // Appending Timestamp in mapping
    depositStart[msg.sender] = depositStart[msg.sender] + block.timestamp;
    // Activate deposit status
    isDeposited[msg.sender] = true;
    // Emit Deposit Event
    emit Deposit(msg.sender, msg.value, block.timestamp);
  }

  // Withdraw Function to withdraw ONE to earn interest
  function withdraw() public {
    // Check if has deposit in contract
    require(isDeposited[msg.sender]==true, 'Error, no previous deposit');
    
    uint userBalance = oneBalanceOf[msg.sender];

    // Check user's deposited time
    uint depositTime = block.timestamp - depositStart[msg.sender];

    //31668017 - interest(10% APY) per second for min. deposit amount (0.01 one), cuz:
    //1e15(10% of 0.01 one) / 31577600 (seconds in 365.25 days)
    //(oneBalanceOf[msg.sender] / 1e16) - calc. how much higher interest will be (based on deposit), e.g.:
    //for min. deposit (0.01 one), (oneBalanceOf[msg.sender] / 1e16) = 1 (the same, 31668017/s)
    //for deposit 0.02 one, (oneBalanceOf[msg.sender] / 1e16) = 2 (doubled, (2*31668017)/s)

    // Calculate interest per second as per above calculation
    uint interestPerSecond = 31668017 * (oneBalanceOf[msg.sender] / 1e16);
    
    // Calculate total interest
    uint interest = interestPerSecond * depositTime;

    // Send Funds back to user
    payable(msg.sender).transfer(oneBalanceOf[msg.sender]);
    // Send interest to user by minting new tokens
    token.mint(msg.sender, interest);

    // Reset depositer data
    depositStart[msg.sender] = 0;
    oneBalanceOf[msg.sender] = 0;
    isDeposited[msg.sender] = false;

    // Emit Withdraw event
    emit Withdraw(msg.sender, userBalance, depositTime, interest);
  }


  // Function to provide collaterlaized loans
  function borrow() payable public {
    // Collateral should be more than 0.01 ETH
    require(msg.value>=1e16, 'Error, collateral must be >= 0.01 one');
    // Check if loan is already taken
    require(isBorrowed[msg.sender] == false, 'Error, loan already taken');

    // This collateral will be locked till user payOff the loan
    collateralone[msg.sender] = collateralone[msg.sender] + msg.value;

    // Calculate tokens amount to mint, 50% of msg.value
    uint tokensToMint = collateralone[msg.sender]/2;

    // Mint and send tokens to user
    token.mint(msg.sender, tokensToMint);

    // Activate borrower's loan status
    isBorrowed[msg.sender] = true;

    // Emit Borrow Event
    emit Borrow(msg.sender, collateralone[msg.sender], tokensToMint);
  }


  // Function to payoff existing loan
  function payOff() public {
    // Check loan status
    require(isBorrowed[msg.sender] == true, 'Error, loan not active');

    require(token.transferFrom(msg.sender, address(this), collateralone[msg.sender]/2), "Error, can't receive tokens");

    // 5% Fees on loan
    uint fee = collateralone[msg.sender]/20;

    // Send user's collateral minus fee
    payable(msg.sender).transfer(collateralone[msg.sender]-fee);

    // Reset borrower's data
    collateralone[msg.sender] = 0;
    isBorrowed[msg.sender] = false;

    // Emit Payoff event
    emit PayOff(msg.sender, fee);
  }
}

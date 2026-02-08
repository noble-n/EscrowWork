# TaskMarketplace Smart Contract

A decentralized task marketplace similar to TaskRabbit, built with Solidity.

## Features

### Core Functionality
- **Post Tasks**: Users can post tasks with a reward (deposited into the contract)
- **Accept Tasks**: Workers can accept open tasks
- **Complete Tasks**: Workers mark tasks as completed
- **Confirm Completion**: Posters confirm completion and release payment
- **Cancel Tasks**: Posters can cancel tasks (only if not accepted)
- **Withdraw from Task**: Workers can withdraw from accepted tasks

### Security Features
- ✅ Funds locked once task is accepted (poster cannot withdraw)
- ✅ Worker cannot withdraw funds until poster confirms completion
- ✅ Re-entrancy protection on payment transfers
- ✅ Role-based access control (poster vs worker)
- ✅ Task state validation

## Task Lifecycle

```
1. OPEN → Task posted with reward deposited
   ↓ (worker accepts)
   
2. ACCEPTED → Worker assigned, funds locked
   ↓ (worker completes) OR (worker withdraws → back to OPEN)
   
3. COMPLETED → Waiting for poster confirmation
   ↓ (poster confirms)
   
4. CONFIRMED → Payment released to worker ✓
```

Alternative flow:
```
OPEN → (poster cancels) → CANCELLED → Refund to poster
```

## Contract Functions

### For Task Posters

**postTask(string description) payable**
- Post a new task with description
- Must send ETH as reward (msg.value)
- Funds are locked in contract

**confirmCompletion(uint256 taskId)**
- Confirm task is completed satisfactorily
- Releases payment to worker
- Can only be called after worker marks as completed

**cancelTask(uint256 taskId)**
- Cancel an open task
- Returns funds to poster
- ⚠️ Only works if task hasn't been accepted

### For Workers

**acceptTask(uint256 taskId)**
- Accept an open task
- Assigns you as the worker
- Poster can no longer withdraw funds

**completeTask(uint256 taskId)**
- Mark task as completed
- Notifies poster for confirmation
- Cannot withdraw funds yet

**withdrawFromTask(uint256 taskId)**
- Withdraw from an accepted task
- Task returns to OPEN status
- Allows poster to cancel or reassign

### View Functions

**getTask(uint256 taskId)** - Get full task details

**getOpenTasks()** - Get all open task IDs

**getTasksByPoster(address poster)** - Get tasks posted by address

**getTasksByWorker(address worker)** - Get tasks accepted by address

## Usage Examples

### Example 1: Successful Task Flow

```solidity
// 1. Alice posts a task with 1 ETH reward
taskMarketplace.postTask{value: 1 ether}("Paint my fence");
// taskId = 0

// 2. Bob accepts the task
taskMarketplace.acceptTask(0);

// 3. Alice tries to cancel (will FAIL - task is accepted)
taskMarketplace.cancelTask(0); // ❌ Reverts

// 4. Bob completes the work
taskMarketplace.completeTask(0);

// 5. Alice confirms completion
taskMarketplace.confirmCompletion(0);
// Bob receives 1 ETH ✓
```

### Example 2: Worker Withdraws

```solidity
// 1. Alice posts task
taskMarketplace.postTask{value: 0.5 ether}("Clean garage");

// 2. Bob accepts
taskMarketplace.acceptTask(0);

// 3. Bob realizes he can't do it
taskMarketplace.withdrawFromTask(0);

// 4. Now Alice can cancel and get refund
taskMarketplace.cancelTask(0); // ✓ Works now
```

### Example 3: Cancellation Before Acceptance

```solidity
// 1. Alice posts task
taskMarketplace.postTask{value: 2 ether}("Fix my computer");

// 2. Alice changes her mind
taskMarketplace.cancelTask(0); // ✓ Gets 2 ETH back
```

## Security Considerations

### Protection Against Common Attacks

**Re-entrancy Protection**
- Funds set to 0 before external calls
- Prevents re-entrancy attacks during payment

**Access Control**
- Modifiers ensure only authorized parties can call functions
- Poster cannot accept their own tasks

**State Validation**
- Functions check task status before execution
- Prevents invalid state transitions

### Known Limitations

1. **No Dispute Resolution**: If poster refuses to confirm completion, funds are stuck
   - **Solution**: Consider adding a dispute mechanism or time-based auto-release

2. **No Partial Payments**: All-or-nothing payment model
   - **Solution**: Could add milestone-based payments

3. **No Reputation System**: No way to track user reliability
   - **Solution**: Add rating/review functionality

4. **Gas Costs**: View functions iterate through all tasks
   - **Solution**: Use events and off-chain indexing for production

## Potential Enhancements

```solidity
// 1. Add dispute resolution with arbitrator
mapping(uint256 => address) public arbitrator;
uint256 public disputeTimeout = 7 days;

// 2. Add task deadlines
uint256 public deadline;

// 3. Add reputation scores
mapping(address => uint256) public workerRating;

// 4. Add categories/tags
string[] public categories;

// 5. Add platform fee
uint256 public platformFee = 25; // 2.5%
address public feeCollector;
```

## Testing Checklist

- [ ] Post task with 0 ETH (should fail)
- [ ] Post task with valid reward (should succeed)
- [ ] Accept own task (should fail)
- [ ] Accept task twice (should fail)
- [ ] Cancel accepted task as poster (should fail)
- [ ] Cancel open task (should succeed)
- [ ] Complete task without accepting (should fail)
- [ ] Confirm completion before worker completes (should fail)
- [ ] Worker withdraw and then poster cancel (should succeed)
- [ ] Verify payment transfer on confirmation
- [ ] Test re-entrancy attack scenarios

<!-- ## Deployment

```javascript
// Using Hardhat
const TaskMarketplace = await ethers.getContractFactory("TaskMarketplace");
const marketplace = await TaskMarketplace.deploy();
await marketplace.deployed();

console.log("TaskMarketplace deployed to:", marketplace.address);
``` -->

## Events

Monitor these events for frontend integration:

- `TaskPosted` - New task created
- `TaskAccepted` - Worker accepted task
- `TaskCompleted` - Worker marked complete
- `TaskConfirmed` - Payment released
- `TaskCancelled` - Task cancelled
- `WorkerWithdrew` - Worker withdrew from task

## License

MIT
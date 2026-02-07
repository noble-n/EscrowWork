// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EscrowWork
 * @dev A decentralized task marketplace similar to TaskRabbit
 */
contract EscrowWork {
    
    error OnlyPoster();
    error OnlyWorker();
    error TaskDoesNotExist();
    error RewardMustBeGreaterThanZero();
    error DescriptionCannotBeEmpty();
    error TaskNotOpen();
    error PosterCannotAcceptOwnTask();
    error TaskMustBeAccepted();
    error TaskMustBeCompleted();
    error PaymentTransferFailed();
    error CanOnlyCancelOpenTasks();
    error RefundTransferFailed();
    
    enum TaskStatus {
        Open,           // Task posted, accepting workers
        Accepted,       // Worker accepted the task
        Completed,      // Worker marked as completed
        Confirmed,      // Poster confirmed completion
        Cancelled       // Task cancelled
    }
    
    struct Task {
        uint256 id;
        address poster;
        address worker;
        string description;
        uint256 reward;
        TaskStatus status;
        uint256 createdAt;
        uint256 acceptedAt;
        uint256 completedAt;
    }
    
    // State variables
    uint256 public taskCounter;
    mapping(uint256 => Task) public tasks;
    
    // Events
    event TaskPosted(uint256 indexed taskId, address indexed poster, uint256 reward, string description);
    event TaskAccepted(uint256 indexed taskId, address indexed worker);
    event TaskCompleted(uint256 indexed taskId, address indexed worker);
    event TaskConfirmed(uint256 indexed taskId, address indexed poster, address indexed worker, uint256 reward);
    event TaskCancelled(uint256 indexed taskId, address indexed canceller);
    event WorkerWithdrew(uint256 indexed taskId, address indexed worker);
    
    // Modifiers
    modifier onlyPoster(uint256 _taskId) {
        if(tasks[_taskId].poster != msg.sender) revert OnlyPoster();
        _;
    }
    
    modifier onlyWorker(uint256 _taskId) {
        if(tasks[_taskId].worker != msg.sender) revert OnlyWorker();
        _;
    }
    
    modifier taskExists(uint256 _taskId) {
        if(_taskId >= taskCounter) revert TaskDoesNotExist();
        _;
    }
    
    /**
     * @dev Post a new task with reward
     * @param _description Description of the task
     */
    function postTask(string memory _description) external payable {
        if(msg.value == 0) revert RewardMustBeGreaterThanZero();
        if(bytes(_description).length == 0) revert DescriptionCannotBeEmpty();
        
        tasks[taskCounter] = Task({
            id: taskCounter,
            poster: msg.sender,
            worker: address(0),
            description: _description,
            reward: msg.value,
            status: TaskStatus.Open,
            createdAt: block.timestamp,
            acceptedAt: 0,
            completedAt: 0
        });
        
        emit TaskPosted(taskCounter, msg.sender, msg.value, _description);
        taskCounter++;
    }
    
    /**
     * @dev Accept a task as a worker
     * @param _taskId ID of the task to accept
     */
    function acceptTask(uint256 _taskId) external taskExists(_taskId) {
        Task storage task = tasks[_taskId];
        
        if(task.status != TaskStatus.Open) revert TaskNotOpen();
        if(task.poster == msg.sender) revert PosterCannotAcceptOwnTask();
        
        task.worker = msg.sender;
        task.status = TaskStatus.Accepted;
        task.acceptedAt = block.timestamp;
        
        emit TaskAccepted(_taskId, msg.sender);
    }
    
    /**
     * @dev Worker marks task as completed
     * @param _taskId ID of the task
     */
    function completeTask(uint256 _taskId) external taskExists(_taskId) onlyWorker(_taskId) {
        Task storage task = tasks[_taskId];
        
        if(task.status != TaskStatus.Accepted) revert TaskMustBeAccepted();
        
        task.status = TaskStatus.Completed;
        task.completedAt = block.timestamp;
        
        emit TaskCompleted(_taskId, msg.sender);
    }
    
    /**
     * @dev Poster confirms task completion and releases payment
     * @param _taskId ID of the task
     */
    function confirmCompletion(uint256 _taskId) external taskExists(_taskId) onlyPoster(_taskId) {
        Task storage task = tasks[_taskId];
        
        if(task.status != TaskStatus.Completed) revert TaskMustBeCompleted();
        
        task.status = TaskStatus.Confirmed;
        
        // Transfer reward to worker
        uint256 reward = task.reward;
        task.reward = 0; // Prevent re-entrancy
        
        (bool success, ) = task.worker.call{value: reward}("");
        if(!success) revert PaymentTransferFailed();
        
        emit TaskConfirmed(_taskId, msg.sender, task.worker, reward);
    }
    
    /**
     * @dev Poster cancels task (only if not accepted or worker withdrew)
     * @param _taskId ID of the task
     */
    function cancelTask(uint256 _taskId) external taskExists(_taskId) onlyPoster(_taskId) {
        Task storage task = tasks[_taskId];
        
        if(task.status != TaskStatus.Open) revert CanOnlyCancelOpenTasks();
        
        task.status = TaskStatus.Cancelled;
        
        // Refund poster
        uint256 refund = task.reward;
        task.reward = 0; // Prevent re-entrancy
        
        (bool success, ) = task.poster.call{value: refund}("");
        if(!success) revert RefundTransferFailed();
        
        emit TaskCancelled(_taskId, msg.sender);
    }
    
    /**
     * @dev Worker withdraws from accepted task
     * @param _taskId ID of the task
     */
    function withdrawFromTask(uint256 _taskId) external taskExists(_taskId) onlyWorker(_taskId) {
        Task storage task = tasks[_taskId];
        
        if(task.status != TaskStatus.Accepted) revert TaskMustBeAccepted();
        
        task.status = TaskStatus.Open;
        task.worker = address(0);
        task.acceptedAt = 0;
        
        emit WorkerWithdrew(_taskId, msg.sender);
    }
    
    /**
     * @dev Get task details
     * @param _taskId ID of the task
     */
    function getTask(uint256 _taskId) external view taskExists(_taskId) returns (
        uint256 id,
        address poster,
        address worker,
        string memory description,
        uint256 reward,
        TaskStatus status,
        uint256 createdAt,
        uint256 acceptedAt,
        uint256 completedAt
    ) {
        Task memory task = tasks[_taskId];
        return (
            task.id,
            task.poster,
            task.worker,
            task.description,
            task.reward,
            task.status,
            task.createdAt,
            task.acceptedAt,
            task.completedAt
        );
    }
    
    /**
     * @dev Get all open tasks
     */
    function getOpenTasks() external view returns (uint256[] memory) {
        uint256 openCount = 0;
        
        // Count open tasks
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                openCount++;
            }
        }
        
        // Create array of open task IDs
        uint256[] memory openTasks = new uint256[](openCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                openTasks[index] = i;
                index++;
            }
        }
        
        return openTasks;
    }
    
    /**
     * @dev Get tasks posted by an address
     */
    function getTasksByPoster(address _poster) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].poster == _poster) {
                count++;
            }
        }
        
        uint256[] memory posterTasks = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].poster == _poster) {
                posterTasks[index] = i;
                index++;
            }
        }
        
        return posterTasks;
    }
    
    /**
     * @dev Get tasks accepted/completed by a worker
     */
    function getTasksByWorker(address _worker) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].worker == _worker) {
                count++;
            }
        }
        
        uint256[] memory workerTasks = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < taskCounter; i++) {
            if (tasks[i].worker == _worker) {
                workerTasks[index] = i;
                index++;
            }
        }
        
        return workerTasks;
    }
}

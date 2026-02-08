// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {EscrowWork} from "src/EscrowWork.sol";

contract EscrowWorkTest is Test {
    EscrowWork public escrowWork;
    
    // Test accounts
    address public poster = makeAddr("poster");
    address public worker = makeAddr("worker");
    address public otherUser = makeAddr("otherUser");
    
    // Constants
    uint256 constant TASK_REWARD = 1 ether;
    string constant TASK_DESCRIPTION = "Paint my fence";
    
    // Events for testing
    event TaskPosted(uint256 indexed taskId, address indexed poster, uint256 reward, string description);
    event TaskAccepted(uint256 indexed taskId, address indexed worker);
    event TaskCompleted(uint256 indexed taskId, address indexed worker);
    event TaskConfirmed(uint256 indexed taskId, address indexed poster, address indexed worker, uint256 reward);
    event TaskCancelled(uint256 indexed taskId, address indexed canceller);
    event WorkerWithdrew(uint256 indexed taskId, address indexed worker);
    
    function setUp() public {
        escrowWork = new EscrowWork();
        
        // Fund test accounts
        vm.deal(poster, 10 ether);
        vm.deal(worker, 10 ether);
        vm.deal(otherUser, 10 ether);
    }
    
    modifier taskPosted() {
        vm.prank(poster);
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        _;
    }
    
    modifier taskAccepted() {
        vm.prank(poster);
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        vm.prank(worker);
        escrowWork.acceptTask(0);
        _;
    }
    
    modifier taskCompleted() {
        vm.prank(poster);
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        vm.prank(worker);
        escrowWork.acceptTask(0);
        vm.prank(worker);
        escrowWork.completeTask(0);
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                            POST TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_PostTask() public {
        vm.startPrank(poster);
        
        vm.expectEmit(true, true, false, true);
        emit TaskPosted(0, poster, TASK_REWARD, TASK_DESCRIPTION);
        
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        
        vm.stopPrank();
        
        // Verify task was created correctly
        (
            uint256 id,
            address taskPoster,
            address taskWorker,
            string memory description,
            uint256 reward,
            EscrowWork.TaskStatus status,
            uint256 createdAt,
            uint256 acceptedAt,
            uint256 completedAt
        ) = escrowWork.getTask(0);
        
        assertEq(id, 0);
        assertEq(taskPoster, poster);
        assertEq(taskWorker, address(0));
        assertEq(description, TASK_DESCRIPTION);
        assertEq(reward, TASK_REWARD);
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Open));
        assertEq(createdAt, block.timestamp);
        assertEq(acceptedAt, 0);
        assertEq(completedAt, 0);
        assertEq(escrowWork.taskCounter(), 1);
    }
    
    function test_PostTask_RevertWhen_NoReward() public {
        vm.prank(poster);
        vm.expectRevert(EscrowWork.RewardMustBeGreaterThanZero.selector);
        escrowWork.postTask{value: 0}(TASK_DESCRIPTION);
    }
    
    function test_PostTask_RevertWhen_EmptyDescription() public {
        vm.prank(poster);
        vm.expectRevert(EscrowWork.DescriptionCannotBeEmpty.selector);
        escrowWork.postTask{value: TASK_REWARD}("");
    }
    
    function test_PostTask_MultipleTasks() public {
        vm.startPrank(poster);
        
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 2 ether}("Task 2");
        escrowWork.postTask{value: 3 ether}("Task 3");
        
        vm.stopPrank();
        
        assertEq(escrowWork.taskCounter(), 3);
        
        (, , , , uint256 reward1, , , , ) = escrowWork.getTask(0);
        (, , , , uint256 reward2, , , , ) = escrowWork.getTask(1);
        (, , , , uint256 reward3, , , , ) = escrowWork.getTask(2);
        
        assertEq(reward1, 1 ether);
        assertEq(reward2, 2 ether);
        assertEq(reward3, 3 ether);
    }
    
    function testFuzz_PostTask(uint256 reward, string memory description) public {
        vm.assume(reward > 0 && reward <= 100 ether);
        vm.assume(bytes(description).length > 0 && bytes(description).length < 1000);
        
        vm.deal(poster, reward);
        vm.prank(poster);
        escrowWork.postTask{value: reward}(description);
        
        (, , , string memory storedDesc, uint256 storedReward, , , , ) = escrowWork.getTask(0);
        assertEq(storedReward, reward);
        assertEq(storedDesc, description);
    }
    
    /*//////////////////////////////////////////////////////////////
                          ACCEPT TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_AcceptTask() public taskPosted {
        vm.startPrank(worker);
        
        vm.expectEmit(true, true, false, true);
        emit TaskAccepted(0, worker);
        
        escrowWork.acceptTask(0);
        vm.stopPrank();
        
        // Verify task was accepted
        (, , address taskWorker, , , EscrowWork.TaskStatus status, , uint256 acceptedAt, ) = escrowWork.getTask(0);
        
        assertEq(taskWorker, worker);
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Accepted));
        assertEq(acceptedAt, block.timestamp);
    }
    
    function test_AcceptTask_RevertWhen_TaskDoesNotExist() public {
        vm.prank(worker);
        vm.expectRevert(EscrowWork.TaskDoesNotExist.selector);
        escrowWork.acceptTask(999);
    }
    
    function test_AcceptTask_RevertWhen_TaskNotOpen() public taskAccepted {
        // Try to accept again
        vm.prank(otherUser);
        vm.expectRevert(EscrowWork.TaskNotOpen.selector);
        escrowWork.acceptTask(0);
    }
    
    function test_AcceptTask_RevertWhen_PosterTriesToAccept() public {
        vm.startPrank(poster);
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        
        vm.expectRevert(EscrowWork.PosterCannotAcceptOwnTask.selector);
        escrowWork.acceptTask(0);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                         COMPLETE TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CompleteTask() public taskAccepted {
        vm.startPrank(worker);
        
        vm.expectEmit(true, true, false, true);
        emit TaskCompleted(0, worker);
        
        escrowWork.completeTask(0);
        vm.stopPrank();
        
        // Verify task was completed
        (, , , , , EscrowWork.TaskStatus status, , , uint256 completedAt) = escrowWork.getTask(0);
        
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Completed));
        assertEq(completedAt, block.timestamp);
    }
    
    function test_CompleteTask_RevertWhen_NotWorker() public taskAccepted {
        vm.prank(otherUser);
        vm.expectRevert(EscrowWork.OnlyWorker.selector);
        escrowWork.completeTask(0);
    }
    
    function test_CompleteTask_RevertWhen_TaskNotAccepted() public taskCompleted {
        // Try to complete again
        vm.prank(worker);
        vm.expectRevert(EscrowWork.TaskMustBeAccepted.selector);
        escrowWork.completeTask(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                      CONFIRM COMPLETION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_ConfirmCompletion() public taskCompleted {
        uint256 workerBalanceBefore = worker.balance;
        
        // Confirm completion
        vm.startPrank(poster);
        
        vm.expectEmit(true, true, true, true);
        emit TaskConfirmed(0, poster, worker, TASK_REWARD);
        
        escrowWork.confirmCompletion(0);
        vm.stopPrank();
        
        // Verify task status
        (, , , , uint256 reward, EscrowWork.TaskStatus status, , , ) = escrowWork.getTask(0);
        
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Confirmed));
        assertEq(reward, 0); // Reward should be zero after payment
        
        // Verify worker received payment
        assertEq(worker.balance, workerBalanceBefore + TASK_REWARD);
    }
    
    function test_ConfirmCompletion_RevertWhen_NotPoster() public taskCompleted {
        vm.prank(otherUser);
        vm.expectRevert(EscrowWork.OnlyPoster.selector);
        escrowWork.confirmCompletion(0);
    }
    
    function test_ConfirmCompletion_RevertWhen_TaskNotCompleted() public taskAccepted {
        // Try to confirm without worker completing
        vm.prank(poster);
        vm.expectRevert(EscrowWork.TaskMustBeCompleted.selector);
        escrowWork.confirmCompletion(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                         CANCEL TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CancelTask() public {
        vm.startPrank(poster);
        escrowWork.postTask{value: TASK_REWARD}(TASK_DESCRIPTION);
        
        uint256 posterBalanceBefore = poster.balance;
        
        vm.expectEmit(true, true, false, true);
        emit TaskCancelled(0, poster);
        
        escrowWork.cancelTask(0);
        vm.stopPrank();
        
        // Verify task was cancelled
        (, , , , uint256 reward, EscrowWork.TaskStatus status, , , ) = escrowWork.getTask(0);
        
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Cancelled));
        assertEq(reward, 0); // Reward should be zero after refund
        
        // Verify poster received refund
        assertEq(poster.balance, posterBalanceBefore + TASK_REWARD);
    }
    
    function test_CancelTask_RevertWhen_TaskAccepted() public taskAccepted {
        // Poster tries to cancel after acceptance
        vm.prank(poster);
        vm.expectRevert(EscrowWork.CanOnlyCancelOpenTasks.selector);
        escrowWork.cancelTask(0);
    }
    
    function test_CancelTask_RevertWhen_NotPoster() public taskPosted {
        vm.prank(otherUser);
        vm.expectRevert(EscrowWork.OnlyPoster.selector);
        escrowWork.cancelTask(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                      WITHDRAW FROM TASK TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_WithdrawFromTask() public taskAccepted {
        vm.startPrank(worker);
        
        vm.expectEmit(true, true, false, true);
        emit WorkerWithdrew(0, worker);
        
        escrowWork.withdrawFromTask(0);
        vm.stopPrank();
        
        // Verify task is back to open
        (, , address taskWorker, , , EscrowWork.TaskStatus status, , uint256 acceptedAt, ) = escrowWork.getTask(0);
        
        assertEq(taskWorker, address(0));
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Open));
        assertEq(acceptedAt, 0);
    }
    
    function test_WithdrawFromTask_ThenPosterCanCancel() public taskAccepted {
        // Worker withdraws
        vm.prank(worker);
        escrowWork.withdrawFromTask(0);
        
        // Now poster can cancel
        uint256 posterBalanceBefore = poster.balance;
        
        vm.prank(poster);
        escrowWork.cancelTask(0);
        
        assertEq(poster.balance, posterBalanceBefore + TASK_REWARD);
    }
    
    function test_WithdrawFromTask_RevertWhen_NotWorker() public taskAccepted {
        vm.prank(otherUser);
        vm.expectRevert(EscrowWork.OnlyWorker.selector);
        escrowWork.withdrawFromTask(0);
    }
    
    function test_WithdrawFromTask_RevertWhen_TaskNotAccepted() public taskCompleted {
        // Try to withdraw after completing
        vm.prank(worker);
        vm.expectRevert(EscrowWork.TaskMustBeAccepted.selector);
        escrowWork.withdrawFromTask(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_GetOpenTasks() public {
        // Post multiple tasks
        vm.startPrank(poster);
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 1 ether}("Task 2");
        escrowWork.postTask{value: 1 ether}("Task 3");
        vm.stopPrank();
        
        // Accept one task
        vm.prank(worker);
        escrowWork.acceptTask(1);
        
        // Get open tasks
        uint256[] memory openTasks = escrowWork.getOpenTasks();
        
        assertEq(openTasks.length, 2);
        assertEq(openTasks[0], 0);
        assertEq(openTasks[1], 2);
    }
    
    function test_GetTasksByPoster() public {
        // Poster posts multiple tasks
        vm.startPrank(poster);
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 1 ether}("Task 2");
        vm.stopPrank();
        
        // Other user posts a task
        vm.prank(otherUser);
        escrowWork.postTask{value: 1 ether}("Task 3");
        
        // Get tasks by poster
        uint256[] memory posterTasks = escrowWork.getTasksByPoster(poster);
        
        assertEq(posterTasks.length, 2);
        assertEq(posterTasks[0], 0);
        assertEq(posterTasks[1], 1);
    }
    
    function test_GetTasksByWorker() public {
        // Post multiple tasks
        vm.startPrank(poster);
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 1 ether}("Task 2");
        escrowWork.postTask{value: 1 ether}("Task 3");
        vm.stopPrank();
        
        // Worker accepts two tasks
        vm.startPrank(worker);
        escrowWork.acceptTask(0);
        escrowWork.acceptTask(2);
        vm.stopPrank();
        
        // Get tasks by worker
        uint256[] memory workerTasks = escrowWork.getTasksByWorker(worker);
        
        assertEq(workerTasks.length, 2);
        assertEq(workerTasks[0], 0);
        assertEq(workerTasks[1], 2);
    }
    
    /*//////////////////////////////////////////////////////////////
                       INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_CompleteWorkflow() public taskCompleted {
        uint256 workerBalanceBefore = worker.balance;
        
        vm.prank(poster);
        escrowWork.confirmCompletion(0);
        
        // Verify final state
        (, , , , , EscrowWork.TaskStatus status, , , ) = escrowWork.getTask(0);
        assertEq(uint256(status), uint256(EscrowWork.TaskStatus.Confirmed));
        assertEq(worker.balance, workerBalanceBefore + TASK_REWARD);
    }
    
    function test_MultipleTasksWorkflow() public {
        // Post 3 tasks
        vm.startPrank(poster);
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 2 ether}("Task 2");
        escrowWork.postTask{value: 3 ether}("Task 3");
        vm.stopPrank();
        
        // Worker accepts task 0 and 2
        vm.startPrank(worker);
        escrowWork.acceptTask(0);
        escrowWork.acceptTask(2);
        vm.stopPrank();
        
        // Poster cancels task 1
        vm.prank(poster);
        escrowWork.cancelTask(1);
        
        // Worker completes task 0
        vm.prank(worker);
        escrowWork.completeTask(0);
        
        // Poster confirms task 0
        uint256 workerBalanceBefore = worker.balance;
        vm.prank(poster);
        escrowWork.confirmCompletion(0);
        
        assertEq(worker.balance, workerBalanceBefore + 1 ether);
        
        // Verify states
        (, , , , , EscrowWork.TaskStatus status0, , , ) = escrowWork.getTask(0);
        (, , , , , EscrowWork.TaskStatus status1, , , ) = escrowWork.getTask(1);
        (, , , , , EscrowWork.TaskStatus status2, , , ) = escrowWork.getTask(2);
        
        assertEq(uint256(status0), uint256(EscrowWork.TaskStatus.Confirmed));
        assertEq(uint256(status1), uint256(EscrowWork.TaskStatus.Cancelled));
        assertEq(uint256(status2), uint256(EscrowWork.TaskStatus.Accepted));
    }
    
    function test_ContractBalance() public {
        // Post 3 tasks
        vm.startPrank(poster);
        escrowWork.postTask{value: 1 ether}("Task 1");
        escrowWork.postTask{value: 2 ether}("Task 2");
        escrowWork.postTask{value: 3 ether}("Task 3");
        vm.stopPrank();
        
        // Contract should hold all rewards
        assertEq(address(escrowWork).balance, 6 ether);
        
        // Accept and complete task 0
        vm.prank(worker);
        escrowWork.acceptTask(0);
        
        vm.prank(worker);
        escrowWork.completeTask(0);
        
        // Confirm task 0 - 1 ether paid out
        vm.prank(poster);
        escrowWork.confirmCompletion(0);
        
        assertEq(address(escrowWork).balance, 5 ether);
        
        // Cancel task 1 - 2 ether refunded
        vm.prank(poster);
        escrowWork.cancelTask(1);
        
        assertEq(address(escrowWork).balance, 3 ether);
    }
}

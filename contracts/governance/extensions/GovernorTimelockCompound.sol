// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IGovernorTimelock.sol";
import "../Governor.sol";

/**
 * https://github.com/compound-finance/compound-protocol/blob/master/contracts/Timelock.sol[Compound's timelock] interface
 */
interface ICompoundTimelock {
    receive() external payable;

    function GRACE_PERIOD() external view returns (uint256);
    function MINIMUM_DELAY() external view returns (uint256);
    function MAXIMUM_DELAY() external view returns (uint256);

    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function delay() external view returns (uint256);
    function queuedTransactions(bytes32) external view returns (bool);

    function setDelay(uint256) external;
    function acceptAdmin() external;
    function setPendingAdmin(address) external;

    function queueTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) external;

    function executeTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) external payable returns (bytes memory);
}

/**
 * @dev Extension of {Governor} that binds the execution process to a Compound Timelock. This adds a delay, enforced by
 * the external timelock to all successfull proposal (in addition to the voting duration). The {Governor} needs to be
 * the admin of the timelock for any operation to be performed. A public, unrestricted,
 * {GovernorTimelockCompound-__acceptAdmin} is available to accept ownership of the timelock.
 *
 * Using this model means the proposal will be operated by the {TimelockController} and not by the {Governor}. Thus,
 * the assets and permissions must be attached to the {TimelockController}. Any asset sent to the {Governor} will be
 * inaccessible.
 *
 * _Available since v4.2._
 */
abstract contract GovernorTimelockCompound is IGovernorTimelock, Governor {
    using Time for Time.Timer;

    ICompoundTimelock private _timelock;
    mapping (uint256 => Time.Timer) private _executionTimers;

    /**
     * @dev Emitted when the minimum delay for future operations is modified.
     */
    event TimelockChange(address oldTimelock, address newTimelock);

    /**
     * @dev Set the timelock.
     */
    constructor(address timelock_) {
        _updateTimelock(timelock_);
    }

    /**
     * @dev Overriden version of the {Governor-state} function with added support for the `Queued` and `Expired` status.
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        ProposalState proposalState = super.state(proposalId);

        return (proposalState == ProposalState.Executed && _executionTimers[proposalId].isStarted())
            ? block.timestamp >= proposalEta(proposalId) + _timelock.GRACE_PERIOD()
            ? ProposalState.Expired
            : ProposalState.Queued
            : proposalState;
    }

    /**
     * @dev Public accessor to check the address of the timelock
     */
    function timelock() public view virtual override returns (address) {
        return address(_timelock);
    }

    /**
     * @dev Public accessor to check the eta of a queued proposal
     */
    function proposalEta(uint256 proposalId) public view virtual returns (uint256) {
        return _executionTimers[proposalId].getDeadline();
    }

    /**
     * @dev Function to queue a proposal to the timelock. It internally uses the {Governor-_execute} function to
     * perform all the proposal success checks.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    )
        public virtual override returns (uint256)
    {
        uint256 proposalId = _execute(targets, values, calldatas, salt);
        uint256 eta = block.timestamp + _timelock.delay();
        _executionTimers[proposalId].setDeadline(eta);

        for (uint256 i = 0; i < targets.length; ++i) {
            require(
                !_timelock.queuedTransactions(keccak256(abi.encode(
                    targets[i],
                    values[i],
                    "",
                    calldatas[i],
                    eta
                ))),
                "GovernorWithTimelockCompound:queue: identical proposal action already queued"
            );
            _timelock.queueTransaction(
                targets[i],
                values[i],
                "",
                calldatas[i],
                eta
            );
        }

        emit ProposalQueued(proposalId, eta);

        return proposalId;
    }

    /**
     * @dev Overloaded execute function that run the already queued proposal through the timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    )
        public payable virtual override returns (uint256)
    {
        uint256 proposalId = hashProposal(targets, values, calldatas, salt);
        Address.sendValue(payable(_timelock), msg.value);

        uint256 eta = proposalEta(proposalId);
        require(eta > 0, "GovernorWithTimelockCompound:execute: proposal not yet queued");
        for (uint256 i = 0; i < targets.length; ++i) {
            _timelock.executeTransaction(
                targets[i],
                values[i],
                "",
                calldatas[i],
                eta
            );
        }
        _executionTimers[proposalId].reset();

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    /**
     * @dev Overriden version of the {Governor-_cancel} function to cancel the timelocked proposal if it as already
     * been queued.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 salt
    )
        internal virtual override returns (uint256)
    {
        uint256 proposalId = super._cancel(targets, values, calldatas, salt);

        uint256 eta = proposalEta(proposalId);
        if (eta > 0) {
            for (uint256 i = 0; i < targets.length; ++i) {
                _timelock.cancelTransaction(
                    targets[i],
                    values[i],
                    "",
                    calldatas[i],
                    eta
                );
            }
            _executionTimers[proposalId].reset();
        }

        return proposalId;
    }

    /**
     * @dev Overriden internal {Governor-_calls} function. We don't do anything here as the proposal is not ready to be
     * executed and queueing  it to the timelock requiers knowledge of the `eta`. For gas efficiency, the queueing is
     * done directly in the {queue} function.
     */
    function _calls(
        uint256 /*proposalId*/,
        address[] memory /*targets*/,
        uint256[] memory /*values*/,
        bytes[] memory /*calldatas*/,
        bytes32 /*salt*/
    )
        internal virtual override
    {
    }

    /**
     * @dev Accept admin right over the timelock.
     */
    function __acceptAdmin() public {
        _timelock.acceptAdmin();
    }

    /**
     * @dev Public endpoint to update the underlying timelock instance. Restricted to the timelock itself, so updates
     * must be proposed, scheduled and executed using the {Governor} workflow.
     *
     * For security reason, the timelock must be handed over to another admin before setting up a new one. The two
     * operations (hand over the timelock) and do the update can be batched in a single proposal.
     */
    function updateTimelock(address newTimelock) external virtual {
        require(msg.sender == address(_timelock), "GovernorWithTimelockCompound: caller must be timelock");
        require(_timelock.pendingAdmin() != address(0), "GovernorWithTimelockCompound: old timelock must be transfered before update");
        _updateTimelock(newTimelock);
    }

    function _updateTimelock(address newTimelock) private {
        emit TimelockChange(address(_timelock), newTimelock);
        _timelock = ICompoundTimelock(payable(newTimelock));
    }
}

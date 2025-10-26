// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error NotAuthorized(address account);
error TokenNotAllowed(address token);
error InvalidKind();
error ContractPaused();
error InvalidValue(uint256 expectedAmount, uint256 valueSent);
error NoEthAllowed();
error InsufficientBalance();
error SponsorOnly();
error TimeNotReached(uint64 required);
error InvalidEscrow();
error IndexOutOfBounds();
error Refunded();
error AmountInvalid();
error Expired();
error NonceUsed();
error SponsorMismatch();
error OperatorMismatch();
error TokenMismatch();
error TransferFailed();
error OperatorNotSet();
error InvalidSignature();

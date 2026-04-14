#  EFP App Approval System - Product Requirements Document

## Executive Summary

This PRD outlines the implementation of an app approval system for Ethereum Follow Protocol (EFP) inspired by Ethereum Comment Protocol's dual signature architecture. The feature will allow users to pre-approve applications to submit list operations on their behalf, enabling gas-sponsored transactions and improved user experience.

## Background

### Current State
- EFP List Records contract requires list managers to submit operations directly
- Each list operation requires a transaction from the list manager
- No delegation mechanism exists for third-party applications
- Gas costs must be paid by list managers for each operation

### Inspiration from ECP
ECP's dual signature system provides three authentication methods:
1. **Direct Transaction**: User submits directly (current EFP model)
2. **App Approval**: Pre-approved apps can act on user's behalf
3. **Author Signature**: User signs operation hash, app submits with gas sponsorship

## Goals

### Primary Goals
1. **Enable app delegation**: Allow users to approve apps to manage their lists
2. **Gas sponsorship**: Apps can cover gas costs for user operations
3. **Improved UX**: Reduce transaction frequency for users
4. **Maintain security**: Preserve user control with approval expiry

### Secondary Goals
1. **Minimal disruption**: Avoid breaking changes to existing EFP functionality
2. **Batch operations**: Support multiple list ops in single transaction
3. **Signature flexibility**: Support both approval-based and signature-based auth

## Requirements

### Functional Requirements

#### FR1: App Approval System
- **FR1.1**: Users can approve apps with expiry timestamps
- **FR1.2**: Users can revoke app approvals at any time
- **FR1.3**: Apps can check approval status for any user
- **FR1.4**: Support signature-based approval granting (gasless for users)

#### FR2: Signature-Based List Operations
- **FR2.1**: Support EIP-712 structured signing for list operations
- **FR2.2**: Apps can submit operations on behalf of approved users
- **FR2.3**: Apps can submit operations with user signatures (no pre-approval needed)
- **FR2.4**: Maintain nonce-based replay protection per user-app pair

#### FR3: Batch Operations
- **FR3.1**: Support batching multiple list operations
- **FR3.2**: Support mixed operation types in single transaction
- **FR3.3**: Atomic execution (all ops succeed or all fail)

#### FR4: Gas Optimization
- **FR4.1**: Efficient storage for approvals and nonces
- **FR4.2**: Minimal gas overhead for signature verification
- **FR4.3**: Support for gas estimation

### Non-Functional Requirements

#### NFR1: Security
- **NFR1.1**: EIP-712 compliance for all signatures
- **NFR1.2**: Nonce-based replay attack prevention
- **NFR1.3**: Expiry-based approval management
- **NFR1.4**: Domain separation per contract and chain

#### NFR2: Compatibility
- **NFR2.1**: Backward compatibility with existing EFP contracts
- **NFR2.2**: No breaking changes to current list manager functionality
- **NFR2.3**: Compatible with existing EFP tooling

#### NFR3: Performance
- **NFR3.1**: Gas-efficient signature verification
- **NFR3.2**: Optimized storage layout
- **NFR3.3**: Support for large batch operations

## Technical Design

### Architecture Overview

```
EFPListRecordsV2 (new contract)
├── ListMetadata (existing)
├── ListRecords (existing)
├── AppApprovals (new library)
├── ListOpSigning (new library)
└── BatchOperations (new library)
```

### Core Components

#### 1. AppApprovals Library
Manages app approval state and validation:

```solidity
library AppApprovals {
    mapping(uint256 => mapping(address => mapping(address => uint256))) approvals; // slot => user => app => expiry
    mapping(uint256 => mapping(address => mapping(address => uint256))) nonces;    // slot => user => app => nonce

    function addApproval(uint256 slot, address user, address app, uint256 expiry) external;
    function revokeApproval(uint256 slot, address user, address app) external;
    function isApproved(uint256 slot, address user, address app) external view returns (bool);
    function getNonce(uint256 slot, address user, address app) external view returns (uint256);
}
```

#### 2. ListOpSigning Library
Handles EIP-712 signature generation and verification:

```solidity
library ListOpSigning {
    bytes32 constant APPLY_LIST_OP_TYPEHASH = keccak256("ApplyListOp(uint256 slot,address user,address app,bytes[] ops,uint256 nonce,uint256 deadline)");

    function getListOpHash(uint256 slot, address user, address app, bytes[] ops, uint256 nonce, uint256 deadline) external view returns (bytes32);
    function verifyUserSignature(address user, bytes32 hash, bytes signature) external view returns (bool);
    function verifyAppSignature(address app, bytes32 hash, bytes signature, address sender) external view returns (bool);
}
```

#### 3. Enhanced List Records Contract

```solidity
contract EFPListRecordsV2 is ListRecords {
    using AppApprovals for *;
    using ListOpSigning for *;

    // New signature-based operations
    function applyListOpsWithSig(
        uint256 slot,
        address user,
        bytes[] calldata ops,
        uint256 nonce,
        uint256 deadline,
        bytes calldata userSignature,
        bytes calldata appSignature
    ) external;

    // App approval management
    function addApproval(address app, uint256 expiry) external;
    function addApprovalWithSig(uint256 slot, address user, address app, uint256 expiry, uint256 nonce, uint256 deadline, bytes calldata signature) external;
    function revokeApproval(uint256 slot, address app) external;

    // Batch operations
    function batchListOperations(BatchOperation[] calldata operations) external payable;
}
```

### Authentication Flow

#### Method 1: Direct Transaction (Existing)
```
User → EFPListRecords.applyListOp(slot, op)
```

#### Method 2: App Approval
```
1. User → addApproval(app, expiry)
2. App → applyListOpsWithSig(slot, user, ops, ..., "", appSig)
   - Validates app approval
   - Verifies app signature
   - Applies operations
```

#### Method 3: User Signature + App Submission
```
1. User signs operation hash off-chain
2. App → applyListOpsWithSig(slot, user, ops, ..., userSig, appSig)
   - Verifies user signature
   - Verifies app signature
   - Applies operations
```

### Data Structures

#### Approval Storage
```solidity
// slot => user => app => expiry
mapping(uint256 => mapping(address => mapping(address => uint256))) public approvals;

// slot => user => app => nonce
mapping(uint256 => mapping(address => mapping(address => uint256))) public nonces;
```

#### Batch Operation Structure
```solidity
struct BatchOperation {
    uint256 slot;
    address user;
    bytes[] ops;
    uint256 nonce;
    uint256 deadline;
    bytes userSignature;
    bytes appSignature;
}
```

### EIP-712 Domain Setup
```solidity
string constant name = "Ethereum Follow Protocol List Records";
string constant version = "1";

DOMAIN_SEPARATOR = keccak256(abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes(name)),
    keccak256(bytes(version)),
    block.chainid,
    address(this)
));
```

## Migration Strategy

### Phase 1: New Contract Deployment
1. Deploy `EFPListRecordsV2` with enhanced functionality
2. Maintain full backward compatibility with existing methods
3. No impact to current users or applications

### Phase 2: App Integration
1. Applications integrate with new approval and signature methods
2. Users begin granting app approvals
3. Gas-sponsored operations become available

### Phase 3: Optimization
1. Monitor gas usage and optimize as needed
2. Add additional batch operation types based on usage patterns
3. Consider upgrading existing lists to new contract

## Risk Assessment

### Security Risks
- **Signature replay attacks**: Mitigated by nonce-based protection
- **Approval misuse**: Mitigated by expiry timestamps and revocation
- **Domain confusion**: Mitigated by EIP-712 domain separation

### Technical Risks
- **Gas optimization**: New signature verification adds overhead
- **Contract size**: Additional logic may approach size limits
- **Integration complexity**: Apps must implement signature generation

### Mitigation Strategies
1. Comprehensive testing with gas analysis
2. Modular library design for code reuse
3. Clear documentation and example implementations
4. Gradual rollout with monitoring

## Success Metrics

### Primary Metrics
- **Adoption rate**: Number of app approvals granted by users
- **Gas savings**: Reduction in total gas costs for list operations
- **Transaction frequency**: Increase in list operations per user
- **User experience**: Reduction in transaction confirmations needed

### Secondary Metrics
- **App integration**: Number of applications using signature system
- **Batch utilization**: Usage of batch operation functionality
- **Error rates**: Failed transactions due to signature issues

## Timeline

### Phase 1: Development (4-6 weeks)
- Week 1-2: Core library development (AppApprovals, ListOpSigning)
- Week 3-4: Enhanced contract implementation
- Week 5-6: Testing and optimization

### Phase 2: Testing (2-3 weeks)
- Week 1: Unit and integration testing
- Week 2: Gas optimization and security audit
- Week 3: Documentation and example implementation

### Phase 3: Deployment (1-2 weeks)
- Week 1: Testnet deployment and validation
- Week 2: Mainnet deployment and monitoring

## Open Questions

1. **List ownership**: Should approvals be per-slot or per-user globally?
   - **Recommendation**: Per-slot for granular control

2. **Signature format**: Support only EIP-712 or include EIP-191?
   - **Recommendation**: EIP-712 only for consistency with ECP

3. **Batch operation limits**: Maximum operations per batch?
   - **Recommendation**: Dynamic based on gas limit

4. **Upgrade path**: How to migrate existing lists?
   - **Recommendation**: Optional migration, maintain both contracts

## Conclusion

The EFP App Approval System will significantly enhance user experience by enabling gas-sponsored list operations and reducing transaction frequency. The design maintains security through proven cryptographic methods while preserving backward compatibility with existing EFP functionality.

The modular architecture allows for incremental adoption and future enhancements, making this a valuable addition to the Ethereum Follow Protocol ecosystem.
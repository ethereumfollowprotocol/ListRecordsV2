# Product Requirements Document: EIP-712 Relayer for EFP List Records

## Executive Summary

This document outlines the requirements for implementing EIP-712 typed structured data signing and relayer functionality for the Ethereum Follow Protocol (EFP) List Records system. The goal is to enable gasless transactions for users by allowing them to sign list operations off-chain while relayers execute the transactions on-chain, paying for gas costs.

## Background & Motivation

### Current State
- Users must pay gas fees for every list operation (add/remove records, metadata updates)
- Each transaction requires direct wallet interaction and ETH for gas
- This creates friction for users, especially on mainnet or during high gas periods
- Users may be deterred from frequent list updates due to cost concerns

### Desired State
- Users can sign list operations off-chain using EIP-712 structured data
- Relayers execute signed operations on behalf of users, paying gas costs
- Maintains security through cryptographic signatures
- Preserves existing functionality while adding gasless capabilities
- Enables new business models (sponsored transactions, subscription services)

## Goals & Success Criteria

### Primary Goals
1. **Gasless User Experience**: Enable users to perform list operations without holding ETH
2. **Backward Compatibility**: Maintain all existing functionality without breaking changes
3. **Security**: Ensure signed operations are tamper-proof and replay-resistant
4. **Scalability**: Support high-volume relayer operations efficiently

### Success Criteria
- 100% backward compatibility with existing EFPListRecordsV2 contract
- Sub-1% gas overhead for relayed transactions vs direct transactions
- Support for all existing list operations (metadata, list ops, manager changes)
- Robust nonce management preventing replay attacks
- Clear separation of concerns between relayer logic and core functionality

## Technical Requirements

### Architecture Overview

We propose a **modular architecture** that preserves the existing EFPListRecordsV2 contract while adding relayer capabilities through a separate contract layer.

#### Option A: Proxy Pattern (Recommended)
```
User → EIP-712 Signature → Relayer → EFPListRecordsRelayer → EFPListRecordsV2
```

#### Option B: Extension Contract
```
User → EIP-712 Signature → Relayer → EFPListRecordsExtension
                                            ↓
                                    EFPListRecordsV2 (via delegation)
```

### Core Components

#### 1. EFPListRecordsRelayer Contract

**Primary Responsibilities:**
- EIP-712 signature verification
- Nonce management for replay protection
- Relayer authorization and fee management
- Delegation to existing EFPListRecordsV2 functionality

**Key Functions:**
```solidity
interface IEFPListRecordsRelayer {
    // Core relayer functions
    function executeSignedOperation(
        SignedOperation calldata signedOp,
        bytes calldata signature
    ) external;
    
    function executeSignedBatch(
        SignedBatch calldata signedBatch,
        bytes calldata signature
    ) external;
    
    // Nonce management
    function getNonce(address user) external view returns (uint256);
    function invalidateNonce(uint256 nonce) external;
    
    // Relayer management
    function addRelayer(address relayer) external;
    function removeRelayer(address relayer) external;
    function isAuthorizedRelayer(address relayer) external view returns (bool);
}
```

#### 2. EIP-712 Type Definitions

**Domain Separator:**
```solidity
struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
}
```

**Operation Types:**
```solidity
struct SignedListOp {
    address user;
    uint256 slot;
    bytes op;
    uint256 nonce;
    uint256 deadline;
}

struct SignedMetadataUpdate {
    address user;
    uint256 slot;
    KeyValue[] records;
    uint256 nonce;
    uint256 deadline;
}

struct SignedBatch {
    address user;
    uint256 slot;
    KeyValue[] metadata;
    bytes[] ops;
    uint256 nonce;
    uint256 deadline;
}
```

#### 3. Security Features

**Nonce Management:**
- Per-user sequential nonces to prevent replay attacks
- Support for nonce invalidation for emergency scenarios
- Optional expiration timestamps for time-bounded operations

**Domain Separation:**
- Unique domain separator per deployment
- Chain ID validation to prevent cross-chain replay
- Contract address binding

**Authorization:**
- Whitelist of authorized relayers (configurable)
- Optional fee mechanisms for relayer compensation
- User consent verification through signatures

### Implementation Strategy

#### Phase 1: Core Relayer Contract
1. **EFPListRecordsRelayer Contract**
   - Implement EIP-712 signature verification
   - Add nonce management system
   - Create delegation functions to EFPListRecordsV2
   - Implement basic relayer authorization

2. **Integration Points**
   - Add relayer contract as authorized proxy in EFPListRecordsV2
   - Implement access control for relayed operations
   - Ensure manager validation works with relayed calls

#### Phase 2: Enhanced Features
1. **Batch Operations**
   - Support for signing multiple operations in one signature
   - Gas optimization for batch execution
   - Atomic batch processing (all or nothing)

2. **Advanced Security**
   - Deadline-based expiration
   - Selective nonce invalidation
   - Emergency pause mechanisms

#### Phase 3: Ecosystem Integration
1. **Relayer Infrastructure**
   - Reference relayer implementation
   - Fee market mechanisms
   - Monitoring and analytics

2. **Client Libraries**
   - JavaScript SDK for signature generation
   - Wallet integration examples
   - Developer documentation

### Required Modifications to Existing Contracts

#### EFPListRecordsV2 (Minimal Changes)
```solidity
// Add relayer authorization
mapping(address => bool) public authorizedRelayers;

modifier onlyAuthorizedCaller(uint256 slot) {
    if (authorizedRelayers[msg.sender]) {
        // For relayed calls, verify the actual user from relayer context
        _verifyRelayedManager(slot);
    } else {
        // Existing logic for direct calls
        _verifyDirectManager(slot);
    }
    _;
}
```

### Gas Economics

**Cost Analysis:**
- EIP-712 signature verification: ~5,000 gas
- Nonce management: ~2,000 gas
- Delegation overhead: ~1,000 gas
- **Total overhead: ~8,000 gas per relayed transaction**

**Comparison:**
- Direct transaction: Base operation cost
- Relayed transaction: Base operation cost + 8,000 gas
- **Overhead: <1% for typical list operations**

### Security Considerations

#### Threat Model
1. **Replay Attacks**: Mitigated by nonce management and domain separation
2. **Front-running**: Inherent blockchain risk, same as direct transactions
3. **Malicious Relayers**: Addressed through relayer authorization and signature validation
4. **Cross-chain Replay**: Prevented by chain ID in domain separator

#### Security Mechanisms
1. **Signature Verification**: Full EIP-712 compliance with typed data hashing
2. **Nonce Management**: Sequential nonces with optional invalidation
3. **Time Bounds**: Optional deadline enforcement
4. **Access Control**: Authorized relayer whitelist

## Development Plan

### Phase 1: Core Implementation (4-6 weeks)
- [ ] Design and implement EFPListRecordsRelayer contract
- [ ] Add EIP-712 signature verification
- [ ] Implement nonce management system
- [ ] Create delegation mechanisms to EFPListRecordsV2
- [ ] Write comprehensive test suite

### Phase 2: Integration & Testing (2-3 weeks)
- [ ] Integrate with existing EFPListRecordsV2 contract
- [ ] Implement relayer authorization in ListRecordsV2
- [ ] End-to-end testing with signature generation
- [ ] Gas optimization and benchmarking

### Phase 3: Advanced Features (3-4 weeks)
- [ ] Batch operation support
- [ ] Enhanced security features (deadlines, emergency controls)
- [ ] Reference relayer implementation
- [ ] Client library development

## Risk Assessment

### High Risk
- **Signature Verification Bugs**: Could lead to unauthorized operations
  - *Mitigation*: Extensive testing, formal verification, audit
- **Nonce Management Issues**: Could enable replay attacks
  - *Mitigation*: Battle-tested nonce patterns, comprehensive test coverage

### Medium Risk
- **Gas Optimization**: Overhead could make relaying uneconomical
  - *Mitigation*: Early gas benchmarking, optimization focus
- **Relayer Centralization**: Limited relayer set could create dependencies
  - *Mitigation*: Open relayer ecosystem, multiple implementations

### Low Risk
- **EIP-712 Compatibility**: Standard is well-established
- **Integration Complexity**: Modular design minimizes existing code changes

## Success Metrics

### Technical Metrics
- Gas overhead < 10% vs direct transactions
- 99.9% signature verification accuracy
- Zero replay attack incidents
- 100% backward compatibility maintained

### User Experience Metrics
- Reduction in transaction costs for users
- Increase in list operation frequency
- Reduction in failed transactions due to insufficient gas

### Ecosystem Metrics
- Number of relayer implementations
- Volume of relayed transactions
- Developer adoption of client libraries

## Conclusion

This design provides a path to gasless EFP list operations while maintaining security and backward compatibility. The modular architecture allows for iterative implementation and testing while preserving the existing system's stability. The EIP-712 approach ensures standardized, secure off-chain signing that integrates well with existing wallet infrastructure.

The proposed solution addresses the core user experience problem of gas costs while maintaining the decentralized, trustless nature of the EFP protocol through cryptographic signatures and careful security design.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {Pausable} from 'lib/openzeppelin-contracts/contracts/utils/Pausable.sol';
import {IEFPListMetadata, IEFPListRecords} from './interfaces/IEFPListRecords.sol';
import {ENSReverseClaimer} from './lib/ENSReverseClaimer.sol';

/**
 * @title ListMetadata
 * @author Cory Gabrielsen (cory.eth)
 * @custom:contributor throw; (0xthrpw.eth)
 * @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVS MEAM
 *
 * @notice Manages key-value pairs associated with EFP List NFTs.
 *         Provides functionalities for list managers to set and retrieve metadata for their lists.
 */
abstract contract ListMetadata is IEFPListMetadata, Pausable, Ownable {
  ///////////////////////////////////////////////////////////////////////////
  // Data Structures
  ///////////////////////////////////////////////////////////////////////////

  /// @dev The key-value set for each token ID
  mapping(uint256 => mapping(string => bytes)) private values;

  /////////////////////////////////////////////////////////////////////////////
  // Pausable
  /////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Pauses the contract. Can only be called by the contract owner.
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @dev Unpauses the contract. Can only be called by the contract owner.
   */
  function unpause() public onlyOwner {
    _unpause();
  }

  /////////////////////////////////////////////////////////////////////////////
  // Helpers
  /////////////////////////////////////////////////////////////////////////////

  function bytesToAddress(bytes memory b) internal pure returns (address) {
    if (b.length != 20) {
      revert InvalidLength(b.length);
    }
    address addr;
    assembly {
      addr := mload(add(b, 20))
    }
    return addr;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Getters
  /////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Retrieves metadata value for token ID and key.
   * @param tokenId The token Id to query.
   * @param key The key to query.
   * @return The associated value.
   */
  function getMetadataValue(uint256 tokenId, string calldata key) external view returns (bytes memory) {
    return values[tokenId][key];
  }

  /**
   * @dev Retrieves metadata values for token ID and keys.
   * @param tokenId The token Id to query.
   * @param keys The keys to query.
   * @return The associated values.
   */
  function getMetadataValues(uint256 tokenId, string[] calldata keys) external view returns (bytes[] memory) {
    uint256 length = keys.length;
    bytes[] memory result = new bytes[](length);
    for (uint256 i = 0; i < length;) {
      string calldata key = keys[i];
      result[i] = values[tokenId][key];
      unchecked {
        ++i;
      }
    }
    return result;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Setters
  /////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Sets metadata records for token ID with the unique key key to value,
   * overwriting anything previously stored for token ID and key. To clear a
   * field, set it to the empty string.
   * @param slot The slot corresponding to the list to update.
   * @param key The key to set.
   * @param value The value to set.
   */
  function _setMetadataValue(uint256 slot, string memory key, bytes memory value) internal {
    values[slot][key] = value;
    emit UpdateListMetadata(slot, key, value);
  }

  /**
   * @dev Sets metadata records for token ID with the unique key key to value,
   * overwriting anything previously stored for token ID and key. To clear a
   * field, set it to the empty string. Only callable by the list manager.
   * @param slot The slot corresponding to the list to update.
   * @param key The key to set.
   * @param value The value to set.
   */
  function setMetadataValue(uint256 slot, string calldata key, bytes calldata value)
    external
    whenNotPaused
    onlyListManager(slot)
  {
    _setMetadataValue(slot, key, value);
  }

  /**
   * @dev Sets an array of metadata records for a token ID. Each record is a
   * key/value pair.
   * @param slot The slot corresponding to the list to update.
   * @param records The records to set.
   */
  function _setMetadataValues(uint256 slot, KeyValue[] calldata records) internal {
    uint256 length = records.length;
    for (uint256 i = 0; i < length;) {
      KeyValue calldata record = records[i];
      _setMetadataValue(slot, record.key, record.value);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Sets an array of metadata records for a token ID. Each record is a
   * key/value pair. Only callable by the list manager.
   * @param slot The slot corresponding to the list to update.
   * @param records The records to set.
   */
  function setMetadataValues(uint256 slot, KeyValue[] calldata records) external whenNotPaused onlyListManager(slot) {
    _setMetadataValues(slot, records);
  }

  ///////////////////////////////////////////////////////////////////////////
  // Modifiers
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Ensures that the caller is the manager of the specified list.
   * @param slot The unique identifier of the list.
   * @dev Used to restrict function access to the list's manager.
   */
  modifier onlyListManager(uint256 slot) {
    bytes memory existing = values[slot]['manager'];
    // if not set, claim for msg.sender
    if (existing.length != 20) {
      _claimListManager(slot, msg.sender);
    } else {
      address existingManager = bytesToAddress(existing);
      if (existingManager == address(0)) {
        _claimListManager(slot, msg.sender);
      } else {
        if (existingManager != msg.sender) {
          revert NotListManager(msg.sender);
        }
      }
    }
    _;
  }

  ///////////////////////////////////////////////////////////////////////////
  // List Manager - Claim
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Allows an address to claim management of an unclaimed list slot.
   * @param slot The slot that the sender wishes to claim.
   * @param manager The address to be set as the manager.
   * @dev This function establishes the first-come-first-serve basis for slot claiming.
   */
  function _claimListManager(uint256 slot, address manager) internal {
    bytes memory existing = values[slot]['manager'];
    if (existing.length == 20) {
      address existingManager = bytesToAddress(existing);
      if (existingManager != manager) {
        revert SlotAlreadyClaimed(slot, existingManager);
      }
    }
    _setMetadataValue(slot, 'manager', abi.encodePacked(manager));
  }

  /**
   * @notice Allows the sender to claim management of an unclaimed list slot.
   * @param slot The slot that the sender wishes to claim.
   */
  function claimListManager(uint256 slot) external whenNotPaused {
    _claimListManager(slot, msg.sender);
  }

  /**
   * @notice Allows the sender to transfer management of a list to a new address.
   * @param slot The list's unique identifier.
   * @param manager The address to be set as the new manager.
   */
  function claimListManagerForAddress(uint256 slot, address manager) external whenNotPaused {
    _claimListManager(slot, manager);
  }

  ///////////////////////////////////////////////////////////////////////////
  // List Manager - Read
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Retrieves the address of the manager for a specified list slot.
   * @param slot The list's unique identifier.
   * @return The address of the manager.
   */
  function getListManager(uint256 slot) external view returns (address) {
    bytes memory existing = values[slot]['manager'];
    return existing.length != 20 ? address(0) : bytesToAddress(existing);
  }

  ///////////////////////////////////////////////////////////////////////////
  // List Manager - Write
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Allows the current manager to transfer management of a list to a new address.
   * @param slot The list's unique identifier.
   * @param manager The address to be set as the new manager.
   * @dev Only the current manager can transfer their management role.
   */
  function setListManager(uint256 slot, address manager) external whenNotPaused onlyListManager(slot) {
    _setMetadataValue(slot, 'manager', abi.encodePacked(manager));
  }

  ///////////////////////////////////////////////////////////////////////////
  // List User - Read
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Retrieves the address of the list user for a specified list
   *         slot.
   * @param slot The list's unique identifier.
   * @return The address of the list user.
   */
  function getListUser(uint256 slot) external view returns (address) {
    bytes memory existing = values[slot]['user'];
    return existing.length != 20 ? address(0) : bytesToAddress(existing);
  }

  ///////////////////////////////////////////////////////////////////////////
  // List Manager - Write
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Allows the current manager to change the list user to a new
   *         address.
   * @param slot The list's unique identifier.
   * @param user The address to be set as the new list user.
   * @dev Only the current manager can change the list user.
   */
  function setListUser(uint256 slot, address user) external whenNotPaused onlyListManager(slot) {
    _setMetadataValue(slot, 'user', abi.encodePacked(user));
  }
}

/**
 * @title EFPListRecords
 * @notice Manages a dynamic list of records associated with EFP List NFTs.
 *         Provides functionalities for list managers to apply operations to their lists.
 */
abstract contract ListRecordsV2 is IEFPListRecords, ListMetadata {
  ///////////////////////////////////////////////////////////////////////////
  // Data Structures
  ///////////////////////////////////////////////////////////////////////////

  /// @notice Stores a sequence of operations for each list identified by its slot.
  /// @dev Each list can have multiple operations performed over time.
  mapping(uint256 => bytes[]) public listOps;

  ///////////////////////////////////////////////////////////////////////////
  // List Operation Functions -  Read
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Retrieves the number of operations performed on a list.
   * @param slot The list's unique identifier.
   * @return The number of operations performed on the list.
   */
  function getListOpCount(uint256 slot) external view returns (uint256) {
    return listOps[slot].length;
  }

  /**
   * @notice Retrieves the operation at a specified index for a list.
   * @param slot The list's unique identifier.
   * @param index The index of the operation to be retrieved.
   * @return The operation at the specified index.
   */
  function getListOp(uint256 slot, uint256 index) external view returns (bytes memory) {
    return listOps[slot][index];
  }

  /**
   * @notice Retrieves a range of operations for a list.
   * @param slot The list's unique identifier.
   * @param start The starting index of the range.
   * @param end The ending index of the range.
   * @return The operations in the specified range.
   */
  function getListOpsInRange(uint256 slot, uint256 start, uint256 end) external view returns (bytes[] memory) {
    if (start > end) {
      revert('Invalid range');
    }

    bytes[] memory ops = new bytes[](end - start);
    for (uint256 i = start; i < end;) {
      ops[i - start] = listOps[slot][i];

      unchecked {
        ++i;
      }
    }
    return ops;
  }

  /**
   * @notice Retrieves all operations for a list.
   * @param slot The list's unique identifier.
   * @return The operations performed on the list.
   */
  function getAllListOps(uint256 slot) external view returns (bytes[] memory) {
    return listOps[slot];
  }

  ///////////////////////////////////////////////////////////////////////////
  // List Operation Functions - Write
  ///////////////////////////////////////////////////////////////////////////

  /**
   * @notice Applies a single operation to the list.
   * @param slot The list's unique identifier.
   * @param op The operation to be applied.
   */
  function _applyListOp(uint256 slot, bytes calldata op) internal {
    listOps[slot].push(op);
    emit ListOp(slot, op);
  }

  /**
   * @notice Public wrapper for `_applyOp`, enabling list managers to apply a single operation.
   * @param slot The list's unique identifier.
   * @param op The operation to be applied.
   */
  function applyListOp(uint256 slot, bytes calldata op) external whenNotPaused onlyListManager(slot) {
    _applyListOp(slot, op);
  }

  /**
   * @notice Allows list managers to apply multiple operations in a single transaction.
   * @param slot The list's unique identifier.
   * @param ops An array of operations to be applied.
   */
  function _applyListOps(uint256 slot, bytes[] calldata ops) internal {
    uint256 len = ops.length;
    for (uint256 i = 0; i < len;) {
      _applyListOp(slot, ops[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Allows list managers to apply multiple operations in a single transaction.
   * @param slot The list's unique identifier.
   * @param ops An array of operations to be applied.
   */
  function applyListOps(uint256 slot, bytes[] calldata ops) external whenNotPaused onlyListManager(slot) {
    _applyListOps(slot, ops);
  }

  /**
   * @notice Allows list managers to set metadata values and apply list ops
   *        in a single transaction.
   * @param slot The list's unique identifier.
   * @param records An array of key-value pairs to set.
   * @param ops An array of operations to be applied.
   */
  function setMetadataValuesAndApplyListOps(uint256 slot, KeyValue[] calldata records, bytes[] calldata ops)
    external
    whenNotPaused
    onlyListManager(slot)
  {
    _setMetadataValues(slot, records);
    _applyListOps(slot, ops);
  }
}

contract EFPListRecordsV2 is IEFPListRecords, ListRecordsV2, ENSReverseClaimer {}

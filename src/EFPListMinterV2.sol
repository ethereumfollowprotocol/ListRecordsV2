// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Ownable} from 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import {Pausable} from 'lib/openzeppelin-contracts/contracts/utils/Pausable.sol';
import {IEFPAccountMetadata} from './interfaces/IEFPAccountMetadata.sol';
import {IEFPListRegistry} from './interfaces/IEFPListRegistry.sol';
import {IEFPListRecords} from './interfaces/IEFPListRecords.sol';
import {ENSReverseClaimer} from './lib/ENSReverseClaimer.sol';

interface IEFPListRegistryERC721 is IEFPListRegistry {
  function ownerOf(uint256 tokenId) external view returns (address);

  function totalSupply() external view returns (uint256);
}

/**
 * @title EFPListMetadata

 * @author throw; (0xthrpw.eth)
 * @custom:contributor Cory Gabrielsen (cory.eth)
 * @custom:benediction DEVS BENEDICAT ET PROTEGAT CONTRACTVS MEAM
 *
 * @notice This contract mints and assigns primary lists to users, and sets
 * EFP List metadata.
 */
contract EFPListMinterV2 is ENSReverseClaimer, Pausable {
  IEFPListRegistryERC721 public immutable registry;
  IEFPAccountMetadata public immutable accountMetadata;
  IEFPListRecords public listRecordsL1;

  event Minted(string method, address indexed to, bytes listStorageLocation);

  constructor(address _registryAddress, address _accountMetadataAddress, address _listRecordsL1) {
    registry = IEFPListRegistryERC721(_registryAddress);
    accountMetadata = IEFPAccountMetadata(_accountMetadataAddress);
    listRecordsL1 = IEFPListRecords(_listRecordsL1);
  }

  /////////////////////////////////////////////////////////////////////////////
  // Admin
  /////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Set the EFP List Records contract address.
   * @param _listRecordsL1 The address of the EFP List Registry contract.
   */
  function setListRecordsL1(address _listRecordsL1) public onlyOwner {
    listRecordsL1 = IEFPListRecords(_listRecordsL1);
  }

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
  // minting
  /////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Decode a list storage location 
   * @param listStorageLocation The storage location of the list.
   * @return chain The chain ID of the list.
   * @return slot The slot of the list.
   * @return contractAddress The contract address of the list.
   */
  function decodeLSL(bytes calldata listStorageLocation) public pure returns (uint256, uint256, address) {
    address contractAddress = _bytesToAddress(listStorageLocation, 34);
    uint256 chain = _bytesToUint(listStorageLocation, 2);
    uint256 slot = _bytesToUint(listStorageLocation, 54);
    return (chain, slot, contractAddress);
  }

  /**
   * @dev Encode a list storage location. Note this has a fixed version and type.
   * @param chain The chain ID of the list.
   * @param slot The slot of the list.
   * @param contractAddress The contract address of the list.
   * @return The encoded list storage location.
   */
  function encodeLSL(uint256 chain, uint256 slot, address contractAddress) public pure returns (bytes memory) {
    return abi.encodePacked(bytes1(0x01), bytes1(0x01), bytes32(chain), contractAddress, bytes32(slot));
  }

  /**
   * @dev Validate and decode a list storage location 
   * @param listStorageLocation The storage location of the list.
   * @return chain The chain ID of the list.
   * @return slot The slot of the list.
   * @return contractAddress The contract address of the list.
   */
  function validateAndDecodeLSL(bytes calldata listStorageLocation) internal pure returns (uint256, uint256, address) {
    // the list storage location is
    // - version (1 byte)
    // - list storage location type (1 byte)
    // - chain id (32 bytes)
    // - contract address (20 bytes)
    // - slot (32 bytes)
    require(listStorageLocation.length == 1 + 1 + 32 + 20 + 32, 'EFPListMinter: invalid list storage location');
    require(listStorageLocation[0] == 0x01, 'EFPListMinter: invalid list storage location version');
    require(listStorageLocation[1] == 0x01, 'EFPListMinter: invalid list storage location type');
    (uint256 chain, uint256 slot, address contractAddress) = decodeLSL(listStorageLocation);
    return (chain, slot, contractAddress);
  }

  /**
   * @dev Mint a primary list.
   * @param listStorageLocation The storage location of the list.
   */
  function easyMint(bytes calldata listStorageLocation) public payable whenNotPaused {
    // validate the list storage location
    (uint256 chain, uint256 slot, address recordsContract) = validateAndDecodeLSL(listStorageLocation);

    uint256 tokenId = registry.totalSupply();
    uint256 currentChain = block.chainid;
    registry.mintTo{value: msg.value}(msg.sender, listStorageLocation);
    _setDefaultListForAccount(msg.sender, tokenId);
    if (recordsContract == address(listRecordsL1) && currentChain == chain) {
      listRecordsL1.claimListManagerForAddress(slot, msg.sender);
    }
    emit Minted('easyMint', msg.sender, listStorageLocation);
  }

  /**
   * @dev Mint a primary list to a specific address.
   * @param to The address to mint the list to.
   * @param listStorageLocation The storage location of the list.
   */
  function easyMintTo(address to, bytes calldata listStorageLocation) public payable whenNotPaused {
    // validate the list storage location
    (uint256 chain, uint256 slot, address recordsContract) = validateAndDecodeLSL(listStorageLocation);

    uint256 tokenId = registry.totalSupply();
    uint256 currentChain = block.chainid;
    registry.mintTo{value: msg.value}(to, listStorageLocation);
    _setDefaultListForAccount(msg.sender, tokenId);
    if (recordsContract == address(listRecordsL1) && currentChain == chain) {
      listRecordsL1.claimListManagerForAddress(slot, msg.sender);
    }
    emit Minted('easyMintTo', to, listStorageLocation);
  }

  /**
   * @dev Mint a primary list without metadata.
   * @param listStorageLocation The storage location of the list.
   */
  function mintPrimaryListNoMeta(bytes calldata listStorageLocation) public payable whenNotPaused {
    // validate the list storage location
    validateAndDecodeLSL(listStorageLocation);
    uint256 tokenId = registry.totalSupply();
    _setDefaultListForAccount(msg.sender, tokenId);
    registry.mintTo{value: msg.value}(msg.sender, listStorageLocation);
    emit Minted('mintPrimaryListNoMeta', msg.sender, listStorageLocation);
  }

  /**
   * @dev Mint a primary list without metadata to a specific address.
   * @param listStorageLocation The storage location of the list.
   */
  function mintNoMeta(bytes calldata listStorageLocation) public payable whenNotPaused {
    // validate the list storage location
    validateAndDecodeLSL(listStorageLocation);

    registry.mintTo{value: msg.value}(msg.sender, listStorageLocation);
    emit Minted('mintNoMeta', msg.sender, listStorageLocation);
  }

  /**
   * @dev Mint a primary list without metadata to a specific address.
   * @param to The address to mint the list to.
   * @param listStorageLocation The storage location of the list.
   */
  function mintToNoMeta(address to, bytes calldata listStorageLocation) public payable whenNotPaused {
    // validate the list storage location
    validateAndDecodeLSL(listStorageLocation);

    registry.mintTo{value: msg.value}(to, listStorageLocation);
    emit Minted('mintToNoMeta', to, listStorageLocation);
  }

  /**
   * @dev Set the default list for an account.
   * @param to The address to set the default list for.
   * @param tokenId The token ID of the list.
   */
  function _setDefaultListForAccount(address to, uint256 tokenId) internal {
    accountMetadata.setValueForAddress(to, 'primary-list', abi.encodePacked(tokenId));
  }

  // Generalized function to convert bytes to uint256 with a given offset
  function _bytesToUint(bytes memory data, uint256 offset) internal pure returns (uint256) {
    require(data.length >= offset + 32, 'Data too short');
    uint256 value;
    assembly {
      value := mload(add(data, add(32, offset)))
    }
    return value;
  }

  // Helper function to convert bytes to address with a given offset
  function _bytesToAddress(bytes memory data, uint256 offset) internal pure returns (address addr) {
    require(data.length >= offset + 20, 'Data too short');
    assembly {
      // Extract 20 bytes from the specified offset
      addr := mload(add(add(data, 20), offset))
      // clear the 12 least significant bits of the address
      addr := and(addr, 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    }
    return addr;
  }
}

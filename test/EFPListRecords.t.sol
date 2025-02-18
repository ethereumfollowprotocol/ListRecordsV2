// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';
import {EFPAccountMetadata} from '../EFPAccountMetadata/src/EFPAccountMetadata.sol';
import {EFPListRegistry} from '../EFPList/src/EFPListRegistry.sol';
import {EFPListRecordsV2} from '../src/EFPListRecordsV2.sol';
import {EFPListMinterV2} from '../src/EFPListMinterV2.sol';
import {IEFPListMetadata} from '../src/interfaces/IEFPListRecords.sol';

contract EFPListRecordsTest is Test {
  EFPAccountMetadata public accountMetadata;
  EFPListRegistry public registry;
  EFPListRecordsV2 public listRecords;
  EFPListMinterV2 public minter;
  address public accountMetadataAddress = address(0x5289fE5daBC021D02FDDf23d4a4DF96F4E0F17EF);
  address public registryAddress = address(0x0E688f5DCa4a0a4729946ACbC44C792341714e08);
  address public deployer = address(0x860bFe7019d6264A991277937ea6002714C3c508);
  uint8 constant LIST_OP_VERSION = 1;
  uint8 constant LIST_OP_TYPE_ADD_RECORD = 1;
  uint8 constant LIST_OP_TYPE_REMOVE_RECORD = 2;
  uint8 constant LIST_OP_TYPE_ADD_TAG = 3;
  uint8 constant LIST_OP_TYPE_REMOVE_TAG = 4;
  uint8 constant LIST_RECORD_VERSION = 1;
  uint8 constant LIST_RECORD_TYPE_RAW_ADDRESS = 1;
  address ADDRESS_1 = 0x0000000000000000000000000000000000AbC123;
  address ADDRESS_2 = 0x0000000000000000000000000000000000DeF456;
  address ADDRESS_3 = 0x0000000000000000000000000000000000789AbC;
  uint256 constant NONCE = 0;
  bytes4 constant Error_EnforcedPause = bytes4(keccak256('EnforcedPause()'));
  bytes4 constant Error_NotListManagerSelector = bytes4(keccak256('NotListManager(address)'));
  bytes constant Error_NotListManager = abi.encodeWithSelector(Error_NotListManagerSelector, address(1));
  bytes4 constant Error_InvalidSlotSelector = bytes4(keccak256('InvalidSlot(uint256,address)'));
  bytes4 constant Error_SlotAlreadyClaimedSelector = bytes4(keccak256('SlotAlreadyClaimed(uint256,address)'));
//   bytes constant Error_InvalidSlot = abi.encodeWithSelector(Error_InvalidSlotSelector, 2222, address(1));
  uint8 constant VERSION = 1;
  uint8 constant LIST_LOCATION_TYPE = 1;

  // ERC721Receiver
  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return bytes4(keccak256('onERC721Received(address,address,uint256,bytes)'));
  }


  function setUp() public {
    //get contract instances
    accountMetadata = EFPAccountMetadata(accountMetadataAddress);
    registry = EFPListRegistry(registryAddress);

    //create new list records and list minter
    listRecords = new EFPListRecordsV2();
    minter = new EFPListMinterV2(address(registry), address(accountMetadata), address(listRecords));
    
    //impersonate multisig (contract owner) and add minter as proxy in account metadata
    vm.prank(deployer);
    accountMetadata.addProxy(address(minter));
  }

  function getSlot(address addr, uint96 nonce) public pure returns (uint256) {
    bytes memory slot = abi.encodePacked(addr, uint96(nonce));
    return uint256(bytes32(slot));
  }

  function _makeListStorageLocation(address records, uint256 slot) private view returns (bytes memory) {
    return abi.encodePacked(VERSION, LIST_LOCATION_TYPE, this._getChainId(), records, slot);
  }

  function _getChainId() external view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  // Helper function to compare bytes
  function _assertBytesEqual(bytes memory a, bytes memory b) internal pure {
    assert(a.length == b.length);
    for (uint256 i = 0; i < a.length; i++) {
      assert(a[i] == b[i]);
    }
  }

  function _encodeListOp(uint8 opType) internal view returns (bytes memory) {
    bytes memory result = abi.encodePacked(
      LIST_OP_VERSION, // Version for ListOp
      opType, // Operation type for ListOp (Add Record)
      LIST_RECORD_VERSION, // Version for ListRecord
      LIST_RECORD_TYPE_RAW_ADDRESS, // Record type for ListRecord (Raw Address)
      ADDRESS_1 // Raw address (20 bytes)
    );
    if (opType == LIST_OP_TYPE_ADD_TAG || opType == LIST_OP_TYPE_REMOVE_TAG) {
      result = abi.encodePacked(result, 'tag');
    }
    return result;
  }
  
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

  /////////////////////////////////////////////////////////////////////////////
  // pause
  /////////////////////////////////////////////////////////////////////////////

  function test_CanPause() public {
    assertEq(listRecords.paused(), false);
    listRecords.pause();
    assertEq(listRecords.paused(), true);
  }

  /////////////////////////////////////////////////////////////////////////////
  // unpause
  /////////////////////////////////////////////////////////////////////////////

  function test_CanUnpause() public {
    listRecords.pause();
    listRecords.unpause();
    assertEq(listRecords.paused(), false);
  }

  /////////////////////////////////////////////////////////////////////////////
  // claimListManager
  /////////////////////////////////////////////////////////////////////////////

  function test_CanClaimListManager() public {
    uint256 slot = getSlot(address(this), 999);
    listRecords.claimListManager(slot);
    assertEq(listRecords.getListManager(slot), address(this));
  }

  function test_RevertIf_ClaimListManagerWhenPaused() public {
    listRecords.pause();
    vm.expectRevert(Error_EnforcedPause);
    listRecords.claimListManager(NONCE);
  }

  /////////////////////////////////////////////////////////////////////////////
  // setListManager
  /////////////////////////////////////////////////////////////////////////////

  function test_CanSetListManager() public {
    uint256 badslot = getSlot(address(1), 2222);
    vm.expectRevert(abi.encodeWithSelector(Error_InvalidSlotSelector, badslot, address(1)));
    listRecords.setListManager(badslot, address(1));

    uint256 slot = getSlot(address(this), 2222);
    listRecords.claimListManager(slot);
    listRecords.setListManager(slot, address(1));
    assertEq(listRecords.getListManager(slot), address(1));

    vm.expectRevert(abi.encodeWithSelector(Error_SlotAlreadyClaimedSelector, slot, address(1)));
    listRecords.claimListManager(slot);
  }

  function test_RevertIf_SetListManagerWhenPaused() public {
    uint256 slot = getSlot(address(this), 22322);
    listRecords.claimListManager(slot);
    listRecords.pause();
    vm.expectRevert(Error_EnforcedPause);
    listRecords.setListManager(slot, address(1));
  }

  function test_RevertIf_SetListManagerFromNonManager() public {
    uint256 slot = getSlot(address(this), 22522);
    listRecords.claimListManager(slot);
    vm.prank(address(1));
    vm.expectRevert(Error_NotListManager);
    listRecords.setListManager(slot, address(1));
  }

  /////////////////////////////////////////////////////////////////////////////
  // setListUser
  /////////////////////////////////////////////////////////////////////////////

  function test_CanSetListUser() public {
    uint256 badslot = getSlot(address(1), 2222);
    vm.expectRevert(abi.encodeWithSelector(Error_InvalidSlotSelector, badslot, address(1)));
    listRecords.setListUser(badslot, address(1));

    uint256 slot = getSlot(address(this), 2222);
    listRecords.claimListManager(slot);
    listRecords.setListUser(slot, address(1));
    listRecords.setListManager(slot, address(1));
    assertEq(listRecords.getListUser(slot), address(1));
    
    vm.expectRevert(abi.encodeWithSelector(Error_SlotAlreadyClaimedSelector, slot, address(1)));
    listRecords.claimListManager(slot);
  }

  function test_RevertIf_SetListUserWhenPaused() public {
    uint256 slot = getSlot(address(this), 22322);
    listRecords.claimListManager(slot);
    listRecords.pause();
    vm.expectRevert(Error_EnforcedPause);
    listRecords.setListUser(slot, address(1));
  }

  function test_RevertIf_SetListUserFromNonManager() public {
    uint256 slot = getSlot(address(this), 22522);
    listRecords.claimListManager(slot);
    vm.prank(address(1));
    vm.expectRevert(Error_NotListManager);
    listRecords.setListUser(slot, address(1));
  }

  /////////////////////////////////////////////////////////////////////////////
  // applyListOp
  /////////////////////////////////////////////////////////////////////////////

  function _CanApplyListOp(uint8 opType) internal {
    uint256 slot = getSlot(address(this), 12345);
    assertEq(listRecords.getListOpCount(slot), 0);

    listRecords.claimListManager(slot);

    bytes memory listOp = _encodeListOp(opType);
    listRecords.applyListOp(slot, listOp);

    assertEq(listRecords.getListOpCount(slot), 1);
    _assertBytesEqual(listRecords.getListOp(slot, 0), listOp);
  }

  function test_CanApplyListOpToAddRecord() public {
    _CanApplyListOp(LIST_OP_TYPE_ADD_RECORD);
  }

  function test_CanApplyListOpToRemoveRecord() public {
    _CanApplyListOp(LIST_OP_TYPE_REMOVE_RECORD);
  }

  function test_CanApplyListOpToAddTag() public {
    _CanApplyListOp(LIST_OP_TYPE_ADD_TAG);
  }

  function test_CanApplyListOpToRemoveTag() public {
    _CanApplyListOp(LIST_OP_TYPE_REMOVE_TAG);
  }

  function test_RevertIf_ApplyListOpWhenPaused() public {
    listRecords.pause();
    vm.expectRevert(Error_EnforcedPause);
    listRecords.applyListOp(NONCE, _encodeListOp(LIST_OP_TYPE_ADD_RECORD));
  }

  /////////////////////////////////////////////////////////////////////////////
  // applyListOps
  /////////////////////////////////////////////////////////////////////////////

  function test_CanApplyListOpsSingular() public {
    uint256 slot = getSlot(address(this), 11111);
    assertEq(listRecords.getListOpCount(slot), 0);

    bytes[] memory listOps = new bytes[](1);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listRecords.applyListOps(slot, listOps);

    assertEq(listRecords.getListOpCount(slot), 1);
    _assertBytesEqual(listRecords.getListOp(slot, 0), listOps[0]);
  }

  function test_CanApplyListOpsMultiple() public {
    uint256 slot = getSlot(address(this), 98765);
    assertEq(listRecords.getListOpCount(slot), 0);

    bytes[] memory listOps = new bytes[](2);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listOps[1] = _encodeListOp(LIST_OP_TYPE_REMOVE_RECORD);
    listRecords.applyListOps(slot, listOps);

    assertEq(listRecords.getListOpCount(slot), 2);
    _assertBytesEqual(listRecords.getListOp(slot, 0), listOps[0]);
    _assertBytesEqual(listRecords.getListOp(slot, 1), listOps[1]);
  }

  function test_RevertIf_applyListOpsWhenPaused() public {
    listRecords.pause();
    vm.expectRevert(Error_EnforcedPause);
    bytes[] memory listOps = new bytes[](2);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listOps[1] = _encodeListOp(LIST_OP_TYPE_REMOVE_RECORD);
    uint256 slot = getSlot(address(this), 3456);
    listRecords.applyListOps(slot, listOps);
  }

  function test_RevertIf_applyListOpsFromNonManager() public {
    uint256 slot = getSlot(address(this), 3456);
    listRecords.claimListManager(slot);
    vm.prank(address(1));
    vm.expectRevert(Error_NotListManager);

    bytes[] memory listOps = new bytes[](2);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listOps[1] = _encodeListOp(LIST_OP_TYPE_REMOVE_RECORD);
    listRecords.applyListOps(slot, listOps);
  }

  function test_RevertIf_setMetaApplyListOpsFromNonManager() public {
    uint256 slot = getSlot(address(this), 3456);
    listRecords.claimListManager(slot);
    vm.prank(address(1));
    vm.expectRevert(Error_NotListManager);

    bytes[] memory listOps = new bytes[](2);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listOps[1] = _encodeListOp(LIST_OP_TYPE_REMOVE_RECORD);

    IEFPListMetadata.KeyValue[] memory meta = new IEFPListMetadata.KeyValue[](2);
    meta[0] = IEFPListMetadata.KeyValue('user', abi.encodePacked(address(3)));
    meta[1] = IEFPListMetadata.KeyValue('manager', abi.encodePacked(address(3)));

    listRecords.setMetadataValuesAndApplyListOps(slot, meta, listOps);
    assertEq(listRecords.getListOpCount(slot), 0);
    assertEq(listRecords.getListManager(slot), address(this));
  }

  function test_setMetaApplyListOpsFromNonManager() public {
    uint256 slot = getSlot(address(this), 3456);
    listRecords.claimListManager(slot);
 
    bytes[] memory listOps = new bytes[](2);
    listOps[0] = _encodeListOp(LIST_OP_TYPE_ADD_RECORD);
    listOps[1] = _encodeListOp(LIST_OP_TYPE_REMOVE_RECORD);

    IEFPListMetadata.KeyValue[] memory meta = new IEFPListMetadata.KeyValue[](2);
    meta[0] = IEFPListMetadata.KeyValue('user', abi.encodePacked(address(3)));
    meta[1] = IEFPListMetadata.KeyValue('manager', abi.encodePacked(address(3)));

    listRecords.setMetadataValuesAndApplyListOps(slot, meta, listOps);
    assertEq(listRecords.getListOpCount(slot), 2);
    assertEq(listRecords.getListManager(slot), address(3));

    bytes memory metaValue = listRecords.getMetadataValue(slot, 'user');
    assertEq(address(_bytesToAddress(metaValue, 0)), address(3));

    bytes[] memory fetchedListOps = listRecords.getAllListOps(slot);
    assertEq(fetchedListOps.length, 2);
    _assertBytesEqual(fetchedListOps[0], listOps[0]);
    _assertBytesEqual(fetchedListOps[1], listOps[1]);


    bytes[] memory rangeListOps = listRecords.getListOpsInRange(slot,1,2);
    assertEq(rangeListOps.length, 1);
    _assertBytesEqual(rangeListOps[0], listOps[1]);

    vm.expectRevert('Invalid range');
    bytes[] memory badRangeListOps = listRecords.getListOpsInRange(slot,6,5);
    assertEq(badRangeListOps.length, 0);
  }

  function test_setAndGetListMetadata() public {
    uint256 slot = getSlot(address(7), 3456);
    vm.prank(address(7));
    listRecords.claimListManager(slot);
    assertEq(listRecords.getListManager(slot), address(7));

    vm.prank(address(7));
    listRecords.setMetadataValue(slot, 'user', abi.encodePacked(address(7)));

    string[] memory keys = new string[](2);
    keys[0] = 'user';
    keys[1] = 'manager';

    bytes[] memory meta = listRecords.getMetadataValues(slot, keys);
    assertEq(meta.length, 2);
    assertEq(address(_bytesToAddress(meta[0], 0)), address(7));
    assertEq(address(_bytesToAddress(meta[1], 0)), address(7));
  }

  function test_setAndGetListMetadataBatch() public {
    uint256 slot = getSlot(address(9), 3456);
    vm.prank(address(9));
    listRecords.claimListManager(slot);
    assertEq(listRecords.getListManager(slot), address(9));

    IEFPListMetadata.KeyValue[] memory meta = new IEFPListMetadata.KeyValue[](2);
    meta[0] = IEFPListMetadata.KeyValue('user', abi.encodePacked(address(3)));
    meta[1] = IEFPListMetadata.KeyValue('manager', abi.encodePacked(address(3)));

    vm.prank(address(9));
    listRecords.setMetadataValues(slot, meta);
    assertEq(listRecords.getListManager(slot), address(3));

    string[] memory keys = new string[](2);
    keys[0] = 'user';
    keys[1] = 'manager';

    bytes[] memory newmeta = listRecords.getMetadataValues(slot, keys);
    assertEq(newmeta.length, 2);
    assertEq(address(_bytesToAddress(newmeta[0], 0)), address(3));
    assertEq(address(_bytesToAddress(newmeta[1], 0)), address(3));

    // bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
    // uint256 tokenId = registry.totalSupply();
    // vm.prank(address(3));
    // minter.easyMintTo(address(this), listStorageLocation);
    // assertEq(registry.ownerOf(tokenId), address(this));

  }
}

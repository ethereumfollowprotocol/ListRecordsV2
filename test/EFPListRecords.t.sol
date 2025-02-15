// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';
import {EFPListRecordsV2} from '../src/EFPListRecordsV2.sol';

contract EFPListRecordsTest is Test {
  EFPListRecordsV2 public listRecords;
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

  function setUp() public {
    listRecords = new EFPListRecordsV2();
  }

  function getSlot(address addr, uint96 nonce) public pure returns (uint256) {
    bytes memory slot = abi.encodePacked(addr, uint96(nonce));
    return uint256(bytes32(slot));
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
}

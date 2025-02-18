// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import 'forge-std/Test.sol';
import {VmSafe} from 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';
import {EFPAccountMetadata} from '../EFPAccountMetadata/src/EFPAccountMetadata.sol';
import {EFPListRegistry} from '../EFPList/src/EFPListRegistry.sol';
import {EFPListRecordsV2} from '../src/EFPListRecordsV2.sol';
import {EFPListMinterV2} from '../src/EFPListMinterV2.sol';
// import {IEFPListRegistry} from '../src/interfaces/IEFPListRegistry.sol';

contract EFPListMinterTest is Test {
    EFPAccountMetadata public accountMetadata;
    EFPListRegistry public registry;
    EFPListRecordsV2 public listRecords;
    EFPListMinterV2 public minter;
    address public accountMetadataAddress = address(0x5289fE5daBC021D02FDDf23d4a4DF96F4E0F17EF);
    address public registryAddress = address(0x0E688f5DCa4a0a4729946ACbC44C792341714e08);
    address public deployer = address(0x860bFe7019d6264A991277937ea6002714C3c508);
    bytes4 constant Error_EnforcedPause = bytes4(keccak256('EnforcedPause()'));
    bytes4 constant Error_NotListManagerSelector = bytes4(keccak256('NotListManager(address)'));
    bytes constant Error_NotListManager = abi.encodeWithSelector(Error_NotListManagerSelector, address(1));
    bytes4 constant Error_InvalidSlotSelector = bytes4(keccak256('InvalidSlot(uint256,address)'));
    bytes4 constant Error_SlotAlreadyClaimedSelector = bytes4(keccak256('SlotAlreadyClaimed(uint256,address)'));

    uint8 constant VERSION = 1;
    uint8 constant LIST_LOCATION_TYPE = 1;

    // ERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256('onERC721Received(address,address,uint256,bytes)'));
    }

    // helper functions 
    function _getSlot(address addr, uint96 nonce) public pure returns (uint256) {
        bytes memory slot = abi.encodePacked(addr, uint96(nonce));
        return uint256(bytes32(slot));
    }

    function _getChainId() external view returns (uint256) {
        uint256 id;
        assembly {
        id := chainid()
        }
        return id;
    }

    function _getLogs() public returns (VmSafe.Log[] memory) {
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        // console.logBytes(logs);
        for (uint256 i = 0; i < logs.length; i++) {
            for (uint256 j = 0; j < logs[i].topics.length; j++) {
                console.logString('topic');
                console.logBytes32(logs[i].topics[j]);
            }
            console.logString('data');
            console.logBytes(logs[i].data);
        }
        return logs;
    }

    function _makeListStorageLocation(address records, uint256 slot) private view returns (bytes memory) {
        return abi.encodePacked(VERSION, LIST_LOCATION_TYPE, this._getChainId(), records, slot);
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


    /////////////////////////////////////////////////////////////////////////////
    // tests
    /////////////////////////////////////////////////////////////////////////////

    function test_CanPause() public {
        assertEq(minter.paused(), false);
        minter.pause();
        assertEq(minter.paused(), true);
    }

    function test_CanUnpause() public {
        minter.pause();
        minter.unpause();
        assertEq(minter.paused(), false);
    }

    function test_EasyMintWithDefaultsNativeChain() public {
        //check proxy
        assertEq(accountMetadata.isProxy(address(minter)), true);

        //create slot
        uint256 slot = _getSlot(address(this), 1234);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);

        //get next token id
        uint256 tokenId = registry.totalSupply();
        
        //get events
        vm.recordLogs();

        //mint
        minter.easyMint(listStorageLocation);
        
        // _getLogs();

        assertEq(registry.ownerOf(tokenId), address(this));
        assertEq(accountMetadata.getValue(address(this), 'primary-list'), abi.encodePacked(tokenId));
        assertEq(registry.getListStorageLocation(tokenId), listStorageLocation);

        assertEq(listRecords.getListManager(slot), address(this));
        assertEq(listRecords.getListUser(slot), address(this));
        
   
    }

    // check multi location mint (non native chain list records)
    function test_EasyMintNonNativeChain() public {
        //alternate listRecords 
        EFPListRecordsV2 listRecordsNonNative = new EFPListRecordsV2();

        //create slot
        uint256 slot = _getSlot(address(this), 1234);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecordsNonNative), slot);

        uint256 tokenId = registry.totalSupply();
        
        //mint
        minter.mintPrimaryListNoMeta(listStorageLocation);

        assertEq(registry.ownerOf(tokenId), address(this));
        assertEq(accountMetadata.getValue(address(this), 'primary-list'), abi.encodePacked(tokenId));

        assertEq(registry.getListStorageLocation(tokenId), listStorageLocation);

        listRecordsNonNative.claimListManagerForAddress(slot, address(this));
        assertEq(listRecordsNonNative.getListManager(slot), address(this));
        assertEq(listRecordsNonNative.getListUser(slot), address(this));
    }
    // check mint with no meta
    function test_EasyMintNoMetaNonNativeChain() public {
        //alternate listRecords 
        EFPListRecordsV2 listRecordsNonNative = new EFPListRecordsV2();
        
        //create slot
        uint256 slot = _getSlot(address(this), 6789);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecordsNonNative), slot);

        //mint
        minter.mintNoMeta(listStorageLocation);

        //mint an additional list and set to the same list storage location
        minter.mintToNoMeta(address(132), listStorageLocation);
        
        //change the minter's default list records contract
        minter.setListRecordsL1(address(listRecordsNonNative));
        
        vm.prank(address(132));
        vm.expectRevert(abi.encodeWithSelector(Error_InvalidSlotSelector, slot, address(this)));
        listRecordsNonNative.claimListManager(slot);
        
        //create a new slot
        uint256 newslot = _getSlot(address(this), 34567);
        
        //create list storage location
        bytes memory newListStorageLocation = _makeListStorageLocation(address(listRecordsNonNative), newslot);
        
        minter.mintToNoMeta(address(132), newListStorageLocation);
        
        listRecordsNonNative.claimListManager(newslot);
    }

    function test_EasyMintTo() public {
        //create slot
        uint256 slot = _getSlot(address(this), 234);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);

        //mint
        minter.easyMintTo(address(45), listStorageLocation);

        listRecords.setListManager(slot, address(45));
    }

    function test_UpdateMetadataAfterClaimingSlot() public {
        //change the minter's default list records contract
        minter.setListRecordsL1(address(listRecords));
        
        //create slot
        uint256 slot = _getSlot(address(this), 234);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);

        uint256 tokenId = registry.totalSupply();
        
        //mint
        minter.easyMintTo(address(45), listStorageLocation);

        assertEq(registry.ownerOf(tokenId), address(45));
        assertEq(accountMetadata.getValue(address(this), 'primary-list'), abi.encodePacked(tokenId));
    }

    function test_ListStorageLocation_badLocationLength() public {
        bytes memory listStorageLocation = abi.encodePacked(VERSION, LIST_LOCATION_TYPE, this._getChainId(), address(listRecords));
        vm.expectRevert('EFPListMinter: invalid list storage location');
        minter.mintPrimaryListNoMeta(listStorageLocation);
    }

    function test_ListStorageLocation_badLocationVersion() public {
        bytes memory listStorageLocation = abi.encodePacked(uint8(2), LIST_LOCATION_TYPE, this._getChainId(), address(listRecords), uint256(1234));
        vm.expectRevert('EFPListMinter: invalid list storage location version');
        minter.mintPrimaryListNoMeta(listStorageLocation);
    }

    function test_ListStorageLocation_badLocationType() public {
        bytes memory listStorageLocation = abi.encodePacked(VERSION, uint8(2), this._getChainId(), address(listRecords), uint256(1234));
        vm.expectRevert('EFPListMinter: invalid list storage location type');
        minter.mintPrimaryListNoMeta(listStorageLocation);
    }
    function test_NativeChainDetection() public {
        uint256 nativeSlot = _getSlot(address(this), 5555);
        bytes memory listStorageLocation_native = abi.encodePacked(uint8(1), LIST_LOCATION_TYPE, this._getChainId(), address(listRecords), nativeSlot);
        minter.easyMint(listStorageLocation_native);
        vm.assertEq(listRecords.getListManager(nativeSlot), address(this));

        uint256 nonNativeSlot = _getSlot(address(this), 1234);
        bytes memory listStorageLocation_nonNative = abi.encodePacked(uint8(1), LIST_LOCATION_TYPE, uint256(1), address(listRecords), nonNativeSlot);
        minter.easyMint(listStorageLocation_nonNative);
        vm.assertEq(listRecords.getListManager(nonNativeSlot), address(0));
    }
    // change slot / reset list
    
}
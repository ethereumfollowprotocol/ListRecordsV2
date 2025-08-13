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
    
    /////////////////////////////////////////////////////////////////////////////
    // decodeLSL tests
    /////////////////////////////////////////////////////////////////////////////

    function test_DecodeLSL_ValidInput() public view {
        uint256 expectedChain = 8453;
        uint256 expectedSlot = _getSlot(address(this), 9999);
        address expectedContract = address(listRecords);
        
        bytes memory listStorageLocation = abi.encodePacked(
            VERSION, 
            LIST_LOCATION_TYPE, 
            expectedChain, 
            expectedContract, 
            expectedSlot
        );
        
        (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocation);
        
        assertEq(chain, expectedChain);
        assertEq(slot, expectedSlot);
        assertEq(contractAddress, expectedContract);
    }

    function test_DecodeLSL_DifferentChainIds() public view {
        uint256[] memory chainIds = new uint256[](4);
        chainIds[0] = 1; // Ethereum mainnet
        chainIds[1] = 8453; // Base
        chainIds[2] = 10; // Optimism
        chainIds[3] = 42161; // Arbitrum
        
        uint256 expectedSlot = _getSlot(address(this), 1111);
        address expectedContract = address(0x123);
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            bytes memory listStorageLocation = abi.encodePacked(
                VERSION, 
                LIST_LOCATION_TYPE, 
                chainIds[i], 
                expectedContract, 
                expectedSlot
            );
            
            (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocation);
            
            assertEq(chain, chainIds[i]);
            assertEq(slot, expectedSlot);
            assertEq(contractAddress, expectedContract);
        }
    }

    function test_DecodeLSL_DifferentContracts() public view {
        address[] memory contracts = new address[](3);
        contracts[0] = address(listRecords);
        contracts[1] = address(0x456);
        contracts[2] = address(0x789);
        
        uint256 expectedChain = this._getChainId();
        uint256 expectedSlot = _getSlot(address(this), 2222);
        
        for (uint256 i = 0; i < contracts.length; i++) {
            bytes memory listStorageLocation = abi.encodePacked(
                VERSION, 
                LIST_LOCATION_TYPE, 
                expectedChain, 
                contracts[i], 
                expectedSlot
            );
            
            (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocation);
            
            assertEq(chain, expectedChain);
            assertEq(slot, expectedSlot);
            assertEq(contractAddress, contracts[i]);
        }
    }

    function test_DecodeLSL_DifferentSlots() public view {
        uint256[] memory slots = new uint256[](3);
        slots[0] = _getSlot(address(this), 1);
        slots[1] = _getSlot(address(0x123), 9999);
        slots[2] = _getSlot(address(0x456), 0);
        
        uint256 expectedChain = this._getChainId();
        address expectedContract = address(listRecords);
        
        for (uint256 i = 0; i < slots.length; i++) {
            bytes memory listStorageLocation = abi.encodePacked(
                VERSION, 
                LIST_LOCATION_TYPE, 
                expectedChain, 
                expectedContract, 
                slots[i]
            );
            
            (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocation);
            
            assertEq(chain, expectedChain);
            assertEq(slot, slots[i]);
            assertEq(contractAddress, expectedContract);
        }
    }

    function test_DecodeLSL_EdgeCases() public view {
        // Test with address(0)
        bytes memory listStorageLocationZeroAddress = abi.encodePacked(
            VERSION, 
            LIST_LOCATION_TYPE, 
            uint256(1), 
            address(0), 
            uint256(0)
        );
        
        (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocationZeroAddress);
        
        assertEq(chain, 1);
        assertEq(slot, 0);
        assertEq(contractAddress, address(0));
        
        // Test with maximum values
        bytes memory listStorageLocationMax = abi.encodePacked(
            VERSION, 
            LIST_LOCATION_TYPE, 
            type(uint256).max, 
            address(type(uint160).max), 
            type(uint256).max
        );
        
        (uint256 chainMax, uint256 slotMax, address contractMax) = minter.decodeLSL(listStorageLocationMax);
        
        assertEq(chainMax, type(uint256).max);
        assertEq(slotMax, type(uint256).max);
        assertEq(contractMax, address(type(uint160).max));
    }

    function test_DecodeLSL_CurrentChainIntegration() public view {
        uint256 currentChain = this._getChainId();
        uint256 testSlot = _getSlot(address(this), 5555);
        
        bytes memory listStorageLocation = abi.encodePacked(
            VERSION, 
            LIST_LOCATION_TYPE, 
            currentChain, 
            address(listRecords), 
            testSlot
        );
        
        (uint256 chain, uint256 slot, address contractAddress) = minter.decodeLSL(listStorageLocation);
        
        assertEq(chain, currentChain);
        assertEq(slot, testSlot);
        assertEq(contractAddress, address(listRecords));
        
        // Verify this matches what we expect for native chain detection
        assertTrue(chain == currentChain);
        assertTrue(contractAddress == address(listRecords));
    }

    /////////////////////////////////////////////////////////////////////////////
    // encodeLSL tests
    /////////////////////////////////////////////////////////////////////////////

    function test_EncodeLSL_ValidInput() public view {
        uint256 testChain = 8453;
        uint256 testSlot = _getSlot(address(this), 9999);
        address testContract = address(listRecords);
        
        bytes memory encoded = minter.encodeLSL(testChain, testSlot, testContract);
        
        // Verify the encoded format matches expected structure
        bytes memory expected = abi.encodePacked(
            bytes1(0x01), // version
            bytes1(0x01), // type  
            bytes32(testChain),
            testContract,
            bytes32(testSlot)
        );
        
        assertEq(encoded, expected);
        
        // Verify we can decode what we encoded
        (uint256 decodedChain, uint256 decodedSlot, address decodedContract) = minter.decodeLSL(encoded);
        assertEq(decodedChain, testChain);
        assertEq(decodedSlot, testSlot);
        assertEq(decodedContract, testContract);
    }

    function test_EncodeLSL_RoundTrip() public view {
        // Test multiple round trips with different values
        uint256[] memory chains = new uint256[](3);
        chains[0] = 1; // Ethereum
        chains[1] = 8453; // Base
        chains[2] = 42161; // Arbitrum
        
        for (uint256 i = 0; i < chains.length; i++) {
            uint256 testSlot = _getSlot(address(this), uint96(i * 1000));
            address testContract = address(uint160(0x1000 + i));
            
            bytes memory encoded = minter.encodeLSL(chains[i], testSlot, testContract);
            (uint256 decodedChain, uint256 decodedSlot, address decodedContract) = minter.decodeLSL(encoded);
            
            assertEq(decodedChain, chains[i]);
            assertEq(decodedSlot, testSlot);
            assertEq(decodedContract, testContract);
        }
    }

    /////////////////////////////////////////////////////////////////////////////
    // Event emission tests
    /////////////////////////////////////////////////////////////////////////////

    function test_EasyMint_EmitsMintedEvent() public {
        uint256 slot = _getSlot(address(this), 1234);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMint', address(this), listStorageLocation);
        
        minter.easyMint(listStorageLocation);
    }

    function test_EasyMintTo_EmitsMintedEvent() public {
        uint256 slot = _getSlot(address(this), 5678);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        address recipient = address(0x456);
        
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMintTo', recipient, listStorageLocation);
        
        minter.easyMintTo(recipient, listStorageLocation);
    }

    function test_MintPrimaryListNoMeta_EmitsMintedEvent() public {
        uint256 slot = _getSlot(address(this), 9012);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintPrimaryListNoMeta', address(this), listStorageLocation);
        
        minter.mintPrimaryListNoMeta(listStorageLocation);
    }

    function test_MintNoMeta_EmitsMintedEvent() public {
        uint256 slot = _getSlot(address(this), 3456);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintNoMeta', address(this), listStorageLocation);
        
        minter.mintNoMeta(listStorageLocation);
    }

    function test_MintToNoMeta_EmitsMintedEvent() public {
        uint256 slot = _getSlot(address(this), 7890);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        address recipient = address(0x789);
        
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintToNoMeta', recipient, listStorageLocation);
        
        minter.mintToNoMeta(recipient, listStorageLocation);
    }

    function test_Events_WithDifferentListStorageLocations() public {
        // Test events with different chain IDs and contracts
        uint256 slot1 = _getSlot(address(this), 1111);
        uint256 slot2 = _getSlot(address(this), 2222);
        
        // Native chain location
        bytes memory nativeLocation = _makeListStorageLocation(address(listRecords), slot1);
        
        // Non-native chain location  
        bytes memory nonNativeLocation = abi.encodePacked(
            VERSION, 
            LIST_LOCATION_TYPE, 
            uint256(1), // Different chain
            address(listRecords), 
            slot2
        );
        
        // Test easyMint with native location
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMint', address(this), nativeLocation);
        minter.easyMint(nativeLocation);
        
        // Test easyMint with non-native location
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMint', address(this), nonNativeLocation);
        minter.easyMint(nonNativeLocation);
    }

    function test_Events_WithMultipleRecipients() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(0x111);
        recipients[1] = address(0x222);
        recipients[2] = address(0x333);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 slot = _getSlot(address(this), uint96(5000 + i));
            bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
            
            vm.expectEmit(true, false, false, true);
            emit EFPListMinterV2.Minted('easyMintTo', recipients[i], listStorageLocation);
            
            minter.easyMintTo(recipients[i], listStorageLocation);
        }
    }

    function test_Events_AllMintingMethods() public {
        // Test all minting methods emit the correct function names
        uint256 baseSlot = 10000;
        address recipient = address(0xabc);
        
        // Test easyMint
        uint256 slot1 = _getSlot(address(this), uint96(baseSlot + 1));
        bytes memory lsl1 = _makeListStorageLocation(address(listRecords), slot1);
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMint', address(this), lsl1);
        minter.easyMint(lsl1);
        
        // Test easyMintTo
        uint256 slot2 = _getSlot(address(this), uint96(baseSlot + 2));
        bytes memory lsl2 = _makeListStorageLocation(address(listRecords), slot2);
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('easyMintTo', recipient, lsl2);
        minter.easyMintTo(recipient, lsl2);
        
        // Test mintPrimaryListNoMeta
        uint256 slot3 = _getSlot(address(this), uint96(baseSlot + 3));
        bytes memory lsl3 = _makeListStorageLocation(address(listRecords), slot3);
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintPrimaryListNoMeta', address(this), lsl3);
        minter.mintPrimaryListNoMeta(lsl3);
        
        // Test mintNoMeta
        uint256 slot4 = _getSlot(address(this), uint96(baseSlot + 4));
        bytes memory lsl4 = _makeListStorageLocation(address(listRecords), slot4);
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintNoMeta', address(this), lsl4);
        minter.mintNoMeta(lsl4);
        
        // Test mintToNoMeta
        uint256 slot5 = _getSlot(address(this), uint96(baseSlot + 5));
        bytes memory lsl5 = _makeListStorageLocation(address(listRecords), slot5);
        vm.expectEmit(true, false, false, true);
        emit EFPListMinterV2.Minted('mintToNoMeta', recipient, lsl5);
        minter.mintToNoMeta(recipient, lsl5);
    }

    function test_Events_CorrectEventDataEncoding() public {
        uint256 slot = _getSlot(address(this), 4321);
        bytes memory listStorageLocation = _makeListStorageLocation(address(listRecords), slot);
        
        vm.recordLogs();
        minter.easyMint(listStorageLocation);
        
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        
        // Find the Minted event (should be the last one emitted by our contract)
        VmSafe.Log memory mintedLog;
        for (uint256 i = logs.length; i > 0; i--) {
            if (logs[i-1].emitter == address(minter)) {
                mintedLog = logs[i-1];
                break;
            }
        }
        
        // Verify event signature
        assertEq(mintedLog.topics[0], keccak256("Minted(string,address,bytes)"));
        
        // Verify indexed parameter (address)
        assertEq(mintedLog.topics[1], bytes32(uint256(uint160(address(this)))));
        
        // Verify non-indexed parameters (string method, bytes data)
        (string memory method, bytes memory decodedData) = abi.decode(mintedLog.data, (string, bytes));
        assertEq(method, 'easyMint');
        assertEq(decodedData, listStorageLocation);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {EFPAccountMetadata} from "../EFPAccountMetadata/src/EFPAccountMetadata.sol";
import {EFPListRegistry} from "../EFPList/src/EFPListRegistry.sol";
import {EFPListRecordsV2} from '../src/EFPListRecordsV2.sol';
import {EFPListMinterV2} from "../src/EFPListMinterV2.sol";
// import {IEFPListRegistry} from "../src/interfaces/IEFPListRegistry.sol";

contract EFPListMinterTest is Test {
    EFPAccountMetadata public accountMetadata;
    EFPListRegistry public registry;
    EFPListRecordsV2 public listRecords;
    EFPListMinterV2 public minter;
    address public accountMetadataAddress = address(0x5289fE5daBC021D02FDDf23d4a4DF96F4E0F17EF);
    address public registryAddress = address(0x0E688f5DCa4a0a4729946ACbC44C792341714e08);
    address public deployer = address(0x860bFe7019d6264A991277937ea6002714C3c508);
    
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

    function _makeListStorageLocation(uint256 slot) private view returns (bytes memory) {
        return abi.encodePacked(VERSION, LIST_LOCATION_TYPE, this._getChainId(), address(listRecords), slot);
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

    function test_EasyMintWithDefaultsNativeChain() public {
        //check proxy
        assertEq(accountMetadata.isProxy(address(minter)), true);

        //create slot
        uint256 slot = _getSlot(address(this), 1234);

        //create list storage location
        bytes memory listStorageLocation = _makeListStorageLocation(slot);

        //mint
        minter.easyMint(listStorageLocation);
    }

    // check multi location mint (non native chain list records)

    // check mint with no meta

    // update meta after claiming slot

    // check mint with no meta to address

    // change slot / reset list
    
}


// contract EFPListMinterTest is Test {
//     EFPAccountMetadata public accountMetadata;
//     EFPListMetadata public listMetadata;
//     EFPListRegistry public registry;
//     EFPListRecords public listRecords;
//     EFPListMinter public minter;

//     uint256 NONCE_L1 = 1234;
//     bytes1 LIST_LOCATION_VERSION = bytes1(0x01);
//     bytes1 LIST_LOCATION_TYPE_L1 = bytes1(0x01);
//     bytes1 LIST_LOCATION_TYPE_L2 = bytes1(0x02);

//     function setUp() public {
//         accountMetadata = new EFPAccountMetadata();
//         listMetadata = new EFPListMetadata();
//         registry = new EFPListRegistry();
//         listRecords = new EFPListRecords();
//         listMetadata.setEFPListRegistry(address(registry));
//         registry.setMintState(IEFPListRegistry.MintState.PublicMint);
//         registry.mint(new bytes(0));

//         minter =
//             new EFPListMinter(address(registry), address(accountMetadata), address(listMetadata), address(listRecords));
//         accountMetadata.addProxy(address(minter));
//         listMetadata.addProxy(address(minter));
//     }

//     function test_CanMintWithListLocationOnL1AndSetAsDefaultList() public {
//         uint256 tokenId = registry.totalSupply();
//         minter.mintWithListLocationOnL1AndSetAsDefaultList(NONCE_L1);

//         assertEq(registry.ownerOf(tokenId), address(this));
//         assertEq(accountMetadata.getValue(address(this), "primary-list"), abi.encodePacked(tokenId));
//         assertEq(
//             listMetadata.getValue(uint256(tokenId), "efp.list.location"),
//             abi.encodePacked(LIST_LOCATION_VERSION, LIST_LOCATION_TYPE_L1, address(listRecords), NONCE_L1)
//         );
//     }

//     function test_CanMintWithListLocationOnL2AndSetAsDefaultList() public {
//         uint256 chainId = 2222;
//         address addressL2 = address(0x4444444);
//         uint256 slotL2 = 3333;
//         uint256 tokenId = registry.totalSupply();
//         minter.mintWithListLocationOnL2AndSetAsDefaultList(chainId, addressL2, slotL2);

//         assertEq(registry.ownerOf(tokenId), address(this));
//         assertEq(accountMetadata.getValue(address(this), "primary-list"), abi.encodePacked(tokenId));
//         assertEq(
//             listMetadata.getValue(uint256(tokenId), "efp.list.location"),
//             abi.encodePacked(LIST_LOCATION_VERSION, LIST_LOCATION_TYPE_L2, chainId, addressL2, slotL2)
//         );
//     }
// }

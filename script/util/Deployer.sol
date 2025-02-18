// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import 'forge-std/console.sol';

import {Colors} from './Colors.sol';
import {ContractConfigs} from './ContractConfigs.sol';
import {Contracts} from './Contracts.sol';

import {EFPListRecordsV2} from '../../src/EFPListRecordsV2.sol';
import {EFPListMinterV2} from '../../src/EFPListMinterV2.sol';

import {IEFPListRecords} from '../../src/interfaces/IEFPListRecords.sol';



contract Deployer {
    /*
     * @notice Checks if the given address is a contract by checking the code size.
     * @param addr The address to check.
     * @return True if the address is a contract, false otherwise.
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
        size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @notice Deploys the EFP smart contracts.
     */
    function deployAll() public returns (Contracts memory) {
        console.log(Colors.BLUE, 'Deployer           :', msg.sender, Colors.ENDC);
        console.log();

        // EFPListRecords
        IEFPListRecords listRecordsV2;
        if (isContract(ContractConfigs.EFP_LIST_RECORDS)) {
            listRecordsV2 = EFPListRecordsV2(ContractConfigs.EFP_LIST_RECORDS);
            console.log(' EFPListRecordsV2     :', address(listRecordsV2));
        } else {
            listRecordsV2 = new EFPListRecordsV2();
            console.log(Colors.GREEN, 'EFPListRecordsV2     :', address(listRecordsV2), Colors.ENDC);
        }

        // EFPListMinter
        EFPListMinterV2 listMinterV2;
        if (isContract(ContractConfigs.EFP_LIST_MINTER)) {
            listMinterV2 = EFPListMinterV2(ContractConfigs.EFP_LIST_MINTER);
            console.log(' EFPListMinterV2      :', address(listMinterV2));
        } else {
        listMinterV2 = new EFPListMinterV2(
            address(ContractConfigs.EFP_LIST_REGISTRY),
            address(ContractConfigs.EFP_ACCOUNT_METADATA),
            address(listRecordsV2)
        );
        console.log(Colors.GREEN, 'EFPListMinterV2      :', address(listMinterV2), Colors.ENDC);
        }
        console.log();
        return
            Contracts({
                listRecordsV2: address(listRecordsV2),
                listMinterV2: address(listMinterV2)
            });
    }

    // function initContracts(Contracts memory contracts) public {

    // }

    // function loadAll() public view returns (Contracts memory) {

    // }
}
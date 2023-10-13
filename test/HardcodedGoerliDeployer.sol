pragma solidity ^0.8.13;

import "../src/Deployer.sol";

contract HardcodedGoerliDeployer {
    constructor() {
        new Deployer(
            TBARegistry(0x4584DbF0510E86Dcc2F36038C6473b1a0FC5Aef3),
            TokenGatedAccount(payable(0x67d12C4dB022c543cb7a678F882eDc935B898940)),
            IERC721(0xd0d0ec651a9FF604E9E44Ed02C5799d641024D6F),
            0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92,
            0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92,
            payable(0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92),
            "fakeAvatarURI",
            "fakeLAUR",
            "fakeSAUR"
        );
    }
}
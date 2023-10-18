pragma solidity ^0.8.13;

import "./Deployer.sol";

contract HardcodedGoerliDeployer {
    Deployer public deployer;
    constructor() {
        deployer = new Deployer(
            TBARegistry(0x4584DbF0510E86Dcc2F36038C6473b1a0FC5Aef3),
            TokenGatedAccount(payable(0x67d12C4dB022c543cb7a678F882eDc935B898940)),
            IERC721(0x61DC2889CAbD0f4569d2E5bBB688684Df8f5FAD8),
            0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92,
            0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92,
            payable(0xBB5eb03535FA2bCFe9FE3BBb0F9cC48385818d92),
            "fakeAvatarURI",
            "fakeLAUR",
            "fakeSAUR"
        );
    }
}
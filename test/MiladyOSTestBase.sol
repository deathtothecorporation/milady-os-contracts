/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";
import "./Harnesses.t.sol";


contract MiladyOSTestBase is Test {
    TBARegistry tbaRegistry;
    TokenGatedAccount tbaAccountImpl;
    Miladys miladysContract;
    MiladyAvatar avatarContract;
    LiquidAccessories liquidAccessoriesContract;
    SoulboundAccessoriesHarness soulboundAccessoriesContract;
    Rewards rewardsContract;
    TestUtils testUtils;
    
    function setUp() public {
        uint forkId = vm.createFork(vm.envString("RPC_MAINNET"), 18240000);
        vm.selectFork(forkId);
        deploy(NUM_MILADYS_MINTED, MILADY_AUTHORITY_ADDRESS);
    }

    // define functions to allow receiving ether and NFTs

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function stealMilady(uint id, address purse) public {
        address owner = miladysContract.ownerOf(id);
        vm.prank(owner);
        miladysContract.transferFrom(owner, purse, id);
    }

    function deploy(uint numMiladysToMint, address miladyAuthorityAddress)
        public
    {
        vm.deal(address(this), 1e18 * 1000); // send 1000 eth to this contract
        tbaRegistry = new TBARegistry();
        tbaAccountImpl = new TokenGatedAccount();
        testUtils = new TestUtils(tbaRegistry, tbaAccountImpl);

        miladysContract = Miladys(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        vm.prank(miladysContract.owner());
        miladysContract.flipSaleState();

        // steals miladys for msg.sender to test with
        for (uint i=0; i<numMiladysToMint; i++) {
            stealMilady(i, address(this));
        }
        
        HarnessDeployer d = new HarnessDeployer(
            tbaRegistry,
            tbaAccountImpl,
            1, // chain id of mainnet
            miladysContract,
            miladyAuthorityAddress,
            PROJECT_REVENUE_RECIPIENT,
            "",
            "",
            ""
        );

        avatarContract = d.avatarContract();
        liquidAccessoriesContract = d.liquidAccessoriesContract();
        soulboundAccessoriesContract = d.soulboundAccessoriesContract();
        rewardsContract = d.rewardsContract();

        for (uint i=0; i<numMiladysToMint; i++) {
            tbaRegistry.createAccount(
                address(tbaAccountImpl),
                1, 
                address(miladysContract),
                i,
                0,
                ""
            );

            tbaRegistry.createAccount(
                address(tbaAccountImpl),
                1, 
                address(avatarContract),
                i,
                0,
                ""
            );
        }
    }
}
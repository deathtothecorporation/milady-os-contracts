/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./TestSetup.sol";
import "./TestUtils.sol";
import "./TestConstants.sol";
import "./Harnesses.t.sol";


contract MiladyOSTestBase is Test {
    HarnessDeployer harnessDeployer;
    TGARegistry tgaRegistry;
    TokenGatedAccount tgaAccountImpl;
    Miladys miladysContract;
    MiladyAvatarHarness avatarContract;
    LiquidAccessoriesHarness liquidAccessoriesContract;
    SoulboundAccessoriesHarness soulboundAccessoriesContract;
    RewardsHarness rewardsContract;
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
        tgaRegistry = new TGARegistry();
        tgaAccountImpl = new TokenGatedAccount();
        testUtils = new TestUtils(tgaRegistry, tgaAccountImpl);

        miladysContract = Miladys(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        vm.prank(miladysContract.owner());
        miladysContract.flipSaleState();

        // steals miladys for msg.sender to test with
        for (uint i=0; i<numMiladysToMint; i++) {
            stealMilady(i, address(this));
        }
        
        HarnessDeployer harnessDeployer = new HarnessDeployer(
            tgaRegistry,
            tgaAccountImpl,
            miladysContract,
            miladyAuthorityAddress,
            PROJECT_REVENUE_RECIPIENT,
            "",
            "",
            ""
        );

        avatarContract = harnessDeployer.avatarContract();
        liquidAccessoriesContract = harnessDeployer.liquidAccessoriesContract();
        soulboundAccessoriesContract = harnessDeployer.soulboundAccessoriesContract();
        rewardsContract = harnessDeployer.rewardsContract();

        for (uint i=0; i<numMiladysToMint; i++) {
            tgaRegistry.createAccount(
                address(tgaAccountImpl),
                1, 
                address(miladysContract),
                i,
                0,
                ""
            );

            tgaRegistry.createAccount(
                address(tgaAccountImpl),
                1, 
                address(avatarContract),
                i,
                0,
                ""
            );
        }
    }

    function createAccessory(uint _accessoryId, uint _bondingCurveParameter)
        internal
    {
        (uint bondingCurveParameter,) = liquidAccessoriesContract.bondingCurves(_accessoryId);
        if (bondingCurveParameter == 0) {
            vm.prank(liquidAccessoriesContract.owner());
            liquidAccessoriesContract.defineBondingCurveParameter(_accessoryId, _bondingCurveParameter);
        }
    }

    function buyAccessory(uint _miladyId, uint _accessoryId) 
        internal 
    {
        uint[] memory liquidAccessoryIds = new uint[](1);
        liquidAccessoryIds[0] = _accessoryId;
        uint[] memory mintAmounts = new uint[](1);
        mintAmounts[0] = 1;

        vm.deal(address(this), 1e18 * 1000); // send 1000 eth to this contract
        address payable overpayRecipient = payable(address(0xb055e5b055e5b055e5));
        liquidAccessoriesContract.mintAccessories
            {value : 1 ether}
            (liquidAccessoryIds, 
            mintAmounts, 
            avatarContract.getAvatarTGA(_miladyId), 
            overpayRecipient);
    }

    function equipAccessory(uint _miladyId, uint _accessoryId)
        internal
    {
        uint[] memory accessoryIds = new uint[](1);
        accessoryIds[0] = _accessoryId;
        vm.prank(avatarContract.ownerOf(_miladyId));
        avatarContract.updateEquipSlotsByAccessoryIds(_miladyId, accessoryIds);
    }

    function createAndBuyAccessory(uint _miladyId, uint _accessoryId, uint _bondingCurveParameter)
        internal
    {
        createAccessory(_accessoryId, _bondingCurveParameter);
        buyAccessory(_miladyId, _accessoryId);
    }

    function createBuyAndEquipAccessory(uint _miladyId, uint _accessoryId, uint _bondingCurveParameter)
        internal
    {
        createAndBuyAccessory(_miladyId, _accessoryId, _bondingCurveParameter);
        equipAccessory(_miladyId, _accessoryId);
    }

    function buyAndEquipAccessory(uint _miladyId, uint _accessoryId)
        internal
    {
        buyAccessory(_miladyId, _accessoryId);
        equipAccessory(_miladyId, _accessoryId);
    }

    function clamp(uint x, uint min, uint max) internal pure returns(uint) {
        if (x < min) {
            return min;
        } else if (x > max) {
            return max;
        } else {
            return x;
        }
    }

    function random(uint seed) internal pure returns(uint)
    {
        return uint256(keccak256(abi.encodePacked(seed)));
    }

    function random(bytes memory seed) internal pure returns(uint)
    {
        return uint256(keccak256(seed));
    }

    function randomAddress(bytes memory seed) internal pure returns(address)
    {
        return address(uint160(uint256(keccak256(seed))));
    }

    function randomAddress(uint seed) internal pure returns(address)
    {
        return randomAddress(abi.encodePacked(seed));
    }
}
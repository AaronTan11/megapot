// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {USDm} from "../src/USDm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title USDmTest
 * @notice Unit tests for USDm mock stablecoin
 */
contract USDmTest is Test {
    USDm public token;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant INITIAL_MINT = 1_000_000 * 1e6; // 1M tokens

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.prank(owner);
        token = new USDm(owner);
    }

    // ============ Basic Token Properties ============

    function test_Name() public view {
        assertEq(token.name(), "USDm");
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), "USDm");
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 6);
    }

    function test_InitialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_OwnerIsSet() public view {
        assertEq(token.owner(), owner);
    }

    // ============ Minting ============

    function test_OwnerCanMint() public {
        uint256 amount = 1000 * 1e6;

        vm.prank(owner);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_MintToMultipleAddresses() public {
        uint256 aliceAmount = 500 * 1e6;
        uint256 bobAmount = 300 * 1e6;

        vm.startPrank(owner);
        token.mint(alice, aliceAmount);
        token.mint(bob, bobAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), aliceAmount);
        assertEq(token.balanceOf(bob), bobAmount);
        assertEq(token.totalSupply(), aliceAmount + bobAmount);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(bob, 1000 * 1e6);
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint256).max);

        vm.prank(owner);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
    }

    // ============ Burning ============

    function test_HolderCanBurn() public {
        uint256 mintAmount = 1000 * 1e6;
        uint256 burnAmount = 400 * 1e6;

        vm.prank(owner);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function test_BurnFrom() public {
        uint256 mintAmount = 1000 * 1e6;
        uint256 burnAmount = 400 * 1e6;

        vm.prank(owner);
        token.mint(alice, mintAmount);

        // Alice approves bob to burn
        vm.prank(alice);
        token.approve(bob, burnAmount);

        // Bob burns from Alice
        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), mintAmount - burnAmount);
    }

    // ============ Transfer ============

    function test_Transfer() public {
        uint256 amount = 1000 * 1e6;
        uint256 transferAmount = 300 * 1e6;

        vm.prank(owner);
        token.mint(alice, amount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), amount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function test_TransferFrom() public {
        uint256 amount = 1000 * 1e6;
        uint256 transferAmount = 300 * 1e6;

        vm.prank(owner);
        token.mint(alice, amount);

        // Alice approves bob
        vm.prank(alice);
        token.approve(bob, transferAmount);

        // Bob transfers from Alice to himself
        vm.prank(bob);
        token.transferFrom(alice, bob, transferAmount);

        assertEq(token.balanceOf(alice), amount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    // ============ Permit (EIP-2612) ============

    function test_Permit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address permitOwner = vm.addr(ownerPrivateKey);
        uint256 amount = 1000 * 1e6;

        // Mint tokens to permit owner
        vm.prank(owner);
        token.mint(permitOwner, amount);

        // Create permit signature
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(permitOwner);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypeHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        bytes32 structHash = keccak256(
            abi.encode(permitTypeHash, permitOwner, bob, amount, nonce, deadline)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // Execute permit
        token.permit(permitOwner, bob, amount, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, bob), amount);
    }

    // ============ Ownership ============

    function test_TransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(alice);

        assertEq(token.owner(), alice);

        // Alice can now mint
        vm.prank(alice);
        token.mint(bob, 1000 * 1e6);
        assertEq(token.balanceOf(bob), 1000 * 1e6);

        // Original owner cannot mint
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        token.mint(bob, 1000 * 1e6);
    }

    function test_RenounceOwnership() public {
        vm.prank(owner);
        token.renounceOwnership();

        assertEq(token.owner(), address(0));

        // No one can mint anymore
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        token.mint(alice, 1000 * 1e6);
    }
}


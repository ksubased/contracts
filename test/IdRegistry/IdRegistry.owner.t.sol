// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../TestConstants.sol";

import {IdRegistry} from "../../src/IdRegistry.sol";
import {IdRegistryTestSuite} from "./IdRegistryTestSuite.sol";

/* solhint-disable state-visibility */

contract IdRegistryOwnerTest is IdRegistryTestSuite {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ChangeTrustedCaller(address indexed trustedCaller);
    event DisableTrustedOnly();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                             TRUSTED CALLER
    //////////////////////////////////////////////////////////////*/

    function testFuzzChangeTrustedCaller(address alice) public {
        vm.assume(alice != FORWARDER && alice != address(0));
        assertEq(idRegistry.owner(), owner);

        vm.expectEmit(true, true, true, true);
        emit ChangeTrustedCaller(alice);
        idRegistry.changeTrustedCaller(alice);
        assertEq(idRegistry.getTrustedCaller(), alice);
    }

    function testFuzzCannotChangeTrustedCallerToZeroAddr() public {
        assertEq(idRegistry.owner(), owner);

        vm.expectRevert(IdRegistry.InvalidAddress.selector);
        idRegistry.changeTrustedCaller(address(0));

        assertEq(idRegistry.getTrustedCaller(), address(0));
    }

    function testFuzzCannotChangeTrustedCallerUnlessOwner(address alice, address bob) public {
        vm.assume(alice != FORWARDER && bob != address(0));
        vm.assume(idRegistry.owner() != alice);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        idRegistry.changeTrustedCaller(bob);
        assertEq(idRegistry.getTrustedCaller(), address(0));
    }

    function testFuzzDisableTrustedCaller() public {
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getTrustedOnly(), 1);

        vm.expectEmit(true, true, true, true);
        emit DisableTrustedOnly();
        idRegistry.disableTrustedOnly();
        assertEq(idRegistry.getTrustedOnly(), 0);
    }

    function testFuzzCannotDisableTrustedCallerUnlessOwner(address alice) public {
        vm.assume(alice != FORWARDER && alice != address(0));
        vm.assume(idRegistry.owner() != alice);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        idRegistry.disableTrustedOnly();
        assertEq(idRegistry.getTrustedOnly(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                           TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function testFuzzCannotTransferOwnership(address newOwner) public {
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));

        vm.expectRevert(IdRegistry.Unauthorized.selector);
        idRegistry.transferOwnership(newOwner);

        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                       REQUEST TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function testFuzzRequestTransferOwnership(address newOwner, address newOwner2) public {
        vm.assume(newOwner != address(0) && newOwner2 != address(0));
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));

        idRegistry.requestTransferOwnership(newOwner);
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), newOwner);

        idRegistry.requestTransferOwnership(newOwner2);
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), newOwner2);
    }

    function testFuzzCannotRequestTransferOwnershipToZeroAddr(address newOwner, address newOwner2) public {
        vm.assume(newOwner != address(0) && newOwner2 != address(0));
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));

        vm.expectRevert(IdRegistry.InvalidAddress.selector);
        idRegistry.requestTransferOwnership(address(0));

        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));
    }

    function testFuzzCannotRequestTransferOwnershipUnlessOwner(address alice, address newOwner) public {
        vm.assume(alice != FORWARDER && alice != owner && newOwner != address(0));
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        idRegistry.requestTransferOwnership(newOwner);

        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                       COMPLETE TRANSFER OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function testFuzzCompleteTransferOwnership(address newOwner) public {
        vm.assume(newOwner != FORWARDER && newOwner != owner && newOwner != address(0));
        vm.prank(owner);
        idRegistry.requestTransferOwnership(newOwner);

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(owner, newOwner);
        vm.prank(newOwner);
        idRegistry.completeTransferOwnership();

        assertEq(idRegistry.owner(), newOwner);
        assertEq(idRegistry.getPendingOwner(), address(0));
    }

    function testFuzzCannotCompleteTransferOwnershipUnlessPendingOwner(address alice, address newOwner) public {
        vm.assume(alice != FORWARDER && alice != owner && alice != address(0));
        vm.assume(newOwner != alice && newOwner != address(0));

        vm.prank(owner);
        idRegistry.requestTransferOwnership(newOwner);

        vm.prank(alice);
        vm.expectRevert(IdRegistry.Unauthorized.selector);
        idRegistry.completeTransferOwnership();

        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.getPendingOwner(), newOwner);
    }

    function testPauseRegistration() public {
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.paused(), false);

        _pauseRegistrations();
    }

    function testFuzzCannotPauseRegistrationUnlessOwner(address alice) public {
        vm.assume(alice != FORWARDER && alice != owner && alice != address(0));
        assertEq(idRegistry.owner(), owner);
        assertEq(idRegistry.paused(), false);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        idRegistry.pauseRegistration();

        assertEq(idRegistry.paused(), false);
    }

    function testUnpauseRegistration() public {
        _pauseRegistrations();

        vm.prank(owner);
        idRegistry.unpauseRegistration();

        assertEq(idRegistry.paused(), false);
    }

    function testFuzzCannotUnpauseUnlessOwner(address alice) public {
        vm.assume(alice != FORWARDER && alice != owner && alice != address(0));
        assertEq(idRegistry.owner(), owner);
        _pauseRegistrations();

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        idRegistry.unpauseRegistration();

        assertEq(idRegistry.paused(), true);
    }
}

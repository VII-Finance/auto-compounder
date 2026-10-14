// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Imported only so these contracts are compiled (with via_ir) for v4-periphery's Deploy helper, which loads
// them with vm.getCode. Tests compile without via_ir, so they cannot import these directly.
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PositionDescriptor} from "v4-periphery/src/PositionDescriptor.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

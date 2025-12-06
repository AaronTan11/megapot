// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title USDm
 * @notice Mock stablecoin simulating MegaETH's native stablecoin (developed with Ethena)
 * @dev For testnet/local development use only. On MegaETH mainnet, use the real USDm contract address.
 *
 * Features:
 * - ERC20 standard token
 * - Burnable: Token holders can burn their tokens
 * - Permit: Gasless approvals via EIP-2612 signatures
 * - Ownable: Owner can mint new tokens (for faucet/testing purposes)
 * - 6 decimals (same as USDC)
 */
contract USDm is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    constructor(address initialOwner)
        ERC20("USDm", "USDm")
        Ownable(initialOwner)
        ERC20Permit("USDm")
    {}

    /**
     * @notice Mint new tokens to a specified address
     * @dev Only callable by the owner (for faucet/testing purposes)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint (in smallest units, 6 decimals)
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Returns the number of decimals used for token amounts
     * @dev USDm uses 6 decimals, same as USDC
     * @return The number of decimals (6)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}


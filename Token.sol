// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title EziPay Coin Contract
 * @dev ERC-20 smart contract for the Ezipay ecosystem.
 * This contract is designed to provide secure, scalable, and efficient digital transactions within the Ezipay ecosystem.
 *
 * @notice EZP Token is developed for real-world applications in digital payments, gaming, rewards, and DeFi integrations.
 *
 * @author EZIPAY
 * @dev The contract allows the owner to mint and burn tokens, ensuring controlled supply adjustments.
 */
contract EZP is ERC20, Ownable2Step {
    /**
     * @dev Emitted when new tokens are minted.
     * @param ownerAddress Address of the contract owner executing the minting.
     * @param receiverAddress Address receiving the newly minted tokens.
     * @param amount The amount of tokens minted.
     */
    event MintToken(
        address indexed ownerAddress,
        address indexed receiverAddress,
        uint256 indexed amount
    );

    /**
     * @dev Emitted when tokens are burned.
     * @param ownerAddress Address of the contract owner executing the burn.
     * @param burnAddress Address from which tokens are burned.
     * @param amount The amount of tokens burned.
     */
    event BurnToken(
        address indexed ownerAddress,
        address indexed burnAddress,
        uint256 indexed amount
    );

    /**
     * @notice Contract constructor that initializes the EZP token with a fixed name and symbol.
     * The contract is also initialized as Ownable, granting ownership to the deployer.
     *
     * @dev The ERC-20 token follows a standard decimal count of 18.
     *      The constructor sets the metadata values for tracking the project owner and use case.
     */
    constructor() payable ERC20("EZP", "EZPT") Ownable(msg.sender) {}

    /**
     * @notice Mints new EZP tokens and assigns them to a specified address.
     * @dev Only the contract owner can call this function.
     *      Ensures that the minting amount is valid and that the receiver address is not a zero address.
     *
     * @param receiverAddress The address to receive the newly minted tokens.
     * @param amount The amount of tokens to be minted (denominated in the smallest unit of the token).
     *
     * Emits a {MintToken} event upon successful execution.
     */
    function mint(address receiverAddress, uint256 amount) public onlyOwner {
        require(amount > 0, "INVALID_AMOUNT");
        require(receiverAddress != address(0), "INVALID_ADDRESS");
        _mint(receiverAddress, amount);
        emit MintToken(msg.sender, receiverAddress, amount);
    }

    /**
     * @notice Burns EZP tokens from a specified address.
     * @dev Only the contract owner can call this function.
     *      Ensures that the burn amount is valid and that the burn address is not a zero address.
     *
     * @param burnAddress The address from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     *
     * Emits a {BurnToken} event upon successful execution.
     */
    function burnToken(address burnAddress, uint256 amount) public onlyOwner {
        require(amount != 0, "INVALID_AMOUNT");
        require(burnAddress != address(0), "INVALID_ADDRESS");
        _burn(burnAddress, amount);
        emit BurnToken(msg.sender, burnAddress, amount);
    }

    /**
     * @notice Returns the number of decimals used for the EZP token.
     * @dev Overridden from ERC20 standard to explicitly define decimal precision.
     *
     * @return uint8 - Decimal count (fixed at 18).
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}


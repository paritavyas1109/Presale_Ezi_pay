// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Ownable2Step (OpenZeppelin)
 * @notice Implements a two-step ownership transfer mechanism.
 * @dev Used to enhance security when transferring contract ownership, reducing risks of accidental loss of control.
 */
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ReentrancyGuard (OpenZeppelin)
 * @notice Prevents reentrant attacks in smart contract functions.
 * @dev Ensures that functions marked with `nonReentrant` cannot be called multiple times within the same execution flow.
 */
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SafeERC20 (OpenZeppelin)
 * @notice Provides safe wrapper functions for ERC20 operations, preventing unexpected failures.
 * @dev Protects against contracts that do not return a boolean success value on token transfers.
 */
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title EzipayPresale
 * @author EZIPAY
 * @notice A smart contract to manage the presale of Ezipay Coin (EZP).
 * @dev Implements ownership, security, and token sale logic using OpenZeppelin's battle-tested libraries.
 *
 * Features:
 * - Secure ownership management using `Ownable2Step`
 * - Protection against reentrancy attacks with `ReentrancyGuard`
 * - Safe ERC-20 token operations via `SafeERC20`
 * - Supports token purchases via USDT and Fiat transactions
 * - Structured tokenomics and phased sales approach
 */
contract EzipayPresale is Ownable2Step, ReentrancyGuard {
    /**
     * @title SafeERC20 Library Import
     * @notice Provides safe wrapper functions for ERC20 operations to prevent unexpected failures.
     * @dev Used to securely handle ERC20 token transfers and approvals.
     */
    using SafeERC20 for IERC20;

    /**
     * @notice Defines the decimal precision used for token calculations.
     * @dev Equivalent to 10^18 (used for token values following the ERC-20 standard).
     */
    uint256 constant DECIMAL_VALUE = 1e18;

    /**
     * @notice Stores the address of the USDT token contract used for presale transactions.
     * @dev This address is set during contract deployment and can be updated by the owner.
     */
    IERC20 private _usdtAddress;

    /**
     * @notice Holds the contract address of the Ezipay (EZP) token.
     * @dev Used to facilitate the transfer of tokens to buyers during the presale.
     */
    IERC20 private _EPTokenAddress;

    /**
     * @notice The wallet address where collected USDT from token sales is sent.
     * @dev Can be updated by the contract owner for flexibility.
     */
    address private _receiverAddress;

    /**
     * @notice Indicates whether the presale event is currently active or not.
     * @dev If `true`, users can purchase tokens; if `false`, purchases are restricted.
     */
    bool private presaleActive = false;

    /**
     * @notice The price of 1 Ezipay Coin (EZP) in USDT during the presale.
     * @dev Initially set to 0.005 USDT per token (expressed in smallest USDT units, i.e., 5 * 10^-3 USDT).
     */
    uint256 private _tokenPrice = 5000000000000000; // 0.005 USDT per token (5 * 10^-3 USDT)

    /**
     * @notice Stores a unique list of all investors who have purchased Ezipay Coin (EZP).
     * @dev This array holds the addresses of all buyers who participated in the presale.
     *      The list grows dynamically as new investors make purchases.
     *      Useful for analytics, airdrops, and tracking early adopters.
     */
    address[] private _allBuyersAddress;

    /**
     * @notice Special address authorized to handle off-chain fiat-based token transfers.
     * @dev This address is assigned by the contract owner and is responsible for managing
     *      purchases made using fiat currency. The contract ensures that only this address
     *      can invoke fiat-based token transfers.
     *
     * Security Measures:
     * - Can only be set or updated by the contract owner.
     * - Ensures proper tracking of fiat transactions to maintain transparency.
     */
    address private _fiatTransferAddress;
    /**
     * @title TokenDistributeInfo
     * @notice This struct defines the allocation breakdown for tokens during the presale.
     * @dev Used to store token distribution data across different phases.
     * @param name A descriptive name for the allocation category (e.g., "Public Sale", "Team", etc.).
     * @param totalPhaseToken The total number of tokens allocated to this category (in smallest token units).
     * @param percentage The percentage of total supply assigned to this allocation category.
     * @param totalSuppliedToken The actual number of tokens distributed from this allocation.
     */
    struct TokenDistributeInfo {
        string name;
        uint256 totalPhaseToken;
        uint256 percentage;
        uint256 totalSuppliedToken;
    }

    /**
     * @title BuyDetails
     * @notice This struct records transaction details whenever a user purchases tokens.
     * @dev Helps in tracking purchases for both USDT and Fiat-based transactions.
     * @param buyerAddress The wallet address of the buyer.
     * @param usdtAddress The USDT token contract address used for the transaction.
     * @param usdtValue The amount of USDT (or fiat equivalent) spent in the transaction.
     * @param tokenValue The number of Ezipay tokens (EZP) received by the buyer.
     * @param buyOptions A string indicating the purchase method ("USDT" or "Fiat").
     * @param currentTime The timestamp when the transaction occurred.
     * @param status A boolean indicating whether the purchase was successful (true) or failed (false).
     */
    struct BuyDetails {
        address buyerAddress;
        address usdtAddress;
        uint256 usdtValue;
        uint256 tokenValue;
        string buyOptions;
        uint256 currentTime;
        bool status;
    }

    /**
     * @notice Stores the allocation details of Ezipay Coin (EZP) during the ICO.
     * @dev Maps each phase (e.g., Public Sale, Presale, Airdrop) to its distribution information.
     *      This helps in tracking the supply allocation across different phases of the ICO.
     *
     * Key:
     * - `uint256` → Represents the index (0-4) for different token allocations.
     * - `TokenDistributeInfo` → Struct storing total token supply, allocation percentage, and issued supply.
     */
    mapping(uint256 index  => TokenDistributeInfo tokenDistributeInfo) private _tokenDistributeData;

    /**
     * @notice Tracks purchase details of individual investors participating in the ICO.
     * @dev This mapping associates each buyer's wallet address with an array of their past purchase records.
     *      The purchase records include token amount, transaction type (USDT/Fiat), timestamp, and status.
     *
     * Key:
     * - `address` → Investor's wallet address.
     * - `BuyDetails[]` → List of all transactions made by the investor.
     */
    mapping(address userAddress => BuyDetails[] listTransaction) private _userBuyDetails;

    /**
     * @notice Emitted when the USDT contract address is updated.
     * @dev This event ensures that changes to the USDT contract are transparent and traceable.
     * @param ownerAddress The address of the contract owner initiating the change.
     * @param usdtAddress The newly assigned USDT contract address.
     */
    event ChangeUSDTAddress(
        address indexed ownerAddress,
        address indexed usdtAddress
    );

    /**
     * @notice Emitted when the contract address of the Ezipay Token (EZP) is updated.
     * @dev This event is triggered whenever the token contract is changed by the owner.
     * @param ownerAddress The address of the contract owner initiating the change.
     * @param tokenAddress The newly assigned Ezipay Token contract address.
     */
    event ChangeTokenAddress(
        address indexed ownerAddress,
        address indexed tokenAddress
    );

    /**
     * @notice Emitted when the token price is updated during the presale.
     * @dev Allows tracking of price changes for transparency.
     * @param ownerAddress The address of the contract owner initiating the price update.
     * @param price The new token price in USDT (with decimals applied).
     */
    event ChangePrice(address indexed ownerAddress, uint256 indexed price);

    /**
     * @notice Emitted when the presale status is toggled (Started/Paused/Ended).
     * @dev This event helps track the activation or deactivation of the presale.
     * @param ownerAddress The address of the contract owner initiating the change.
     * @param status A boolean indicating the current status (true = active, false = inactive).
     */
    event PresaleStatus(address indexed ownerAddress, bool indexed status);

    /**
     * @notice Emitted when the contract owner recovers unsold tokens from the contract.
     * @dev Used for recovering unused or locked tokens after the presale ends.
     * @param ownerAddress The address of the contract owner initiating the recovery.
     * @param toAddress The address where the recovered tokens are sent.
     * @param amount The amount of tokens being recovered.
     */
    event RecoverToken(
        address indexed ownerAddress,
        address indexed toAddress,
        uint256 indexed amount
    );

    /**
     * @notice Emitted when the USDT receiver address is updated.
     * @dev This event ensures tracking of address changes for receiving USDT payments.
     * @param ownerAddress The address of the contract owner initiating the change.
     * @param receiverAddress The newly assigned USDT receiver address.
     */
    event ChangeReceiverAddress(
        address indexed ownerAddress,
        address indexed receiverAddress
    );

    /**
     * @notice Emitted when a user successfully purchases Ezipay tokens (EZP).
     * @dev This event records all purchases made during the presale (both USDT & Fiat).
     * @param buyer The address of the user purchasing the tokens.
     * @param usdtValue The amount of USDT spent in the purchase (or fiat equivalent).
     * @param buyOptions A string indicating the purchase method ("USDT" or "Fiat").
     * @param tokenValue The number of EZP tokens received by the buyer.
     * @param timestamp The timestamp when the purchase occurred.
     */
    event TokenPurchased(
        address indexed buyer,
        uint256 indexed usdtValue,
        string indexed buyOptions,
        uint256 tokenValue,
        uint256 timestamp
    );

    /**
     * @notice Emitted when the authorized fiat transfer address is updated.
     * @dev This ensures transparency in fiat-based token purchases.
     * @param owner The address of the contract owner updating the fiat transfer address.
     * @param newFiatTransferAddress The newly assigned fiat transfer handler address.
     */
    event FiatTransferAddressUpdated(
        address indexed owner,
        address indexed newFiatTransferAddress
    );

    /**
     * @notice Emitted when tokens are successfully transferred after a fiat payment.
     * @dev This event helps track off-chain purchases where users buy tokens with fiat currency.
     * @param receiver The address receiving the purchased tokens.
     * @param tokenAmount The number of EZP tokens received.
     * @param timestamp The timestamp when the transfer occurred.
     */
    event TokenTransferredForFiat(
        address indexed receiver,
        uint256 indexed tokenAmount,
        uint256 timestamp
    );

    /**
     * @notice Initializes the Ezipay ICO Smart Contract with required addresses and tokenomics distribution.
     * @dev This constructor sets up the core contract parameters, including token addresses, receiver addresses,
     *      fiat processing address, and the initial token distribution structure.
     *
     * @param usdtAddress The contract address of the USDT token used for transactions.
     * @param tokenAddress The contract address of the Ezipay Coin (EP Token).
     * @param receiverAddress The wallet address that will receive USDT payments.
     * @param fiatTransferAddress A special address authorized to handle off-chain fiat-based transactions.
     *
     * Contract Setup:
     * - Assigns the provided contract addresses for USDT, EP Token, and receiver.
     * - Defines the tokenomics allocation structure for various stakeholders.
     * - Stores the allocation details in a mapping for future reference.
     */
    constructor(
        address usdtAddress,
        address tokenAddress,
        address receiverAddress,
        address fiatTransferAddress
    ) payable Ownable(msg.sender) {
        _usdtAddress = IERC20(usdtAddress);
        _EPTokenAddress = IERC20(tokenAddress);
        _receiverAddress = receiverAddress;
        _fiatTransferAddress = fiatTransferAddress;

        // 🔹 Define the tokenomics distribution (Fixed Supply: 2B EZP Tokens)
        TokenDistributeInfo[5] memory arr = [
            TokenDistributeInfo(
                "Public Sale",
                1000000000 * DECIMAL_VALUE,
                50,
                0
            ), // 1B Tokens Allocated for Public Sale (50%)
            TokenDistributeInfo("Presale", 200000000 * DECIMAL_VALUE, 10, 0), // 200M Tokens Reserved for Presale (10%)
            TokenDistributeInfo(
                "Airdrop/Rewards",
                200000000 * DECIMAL_VALUE,
                10,
                0
            ), // 200M Tokens for Airdrop & Rewards (10%)
            TokenDistributeInfo("Liquidity", 400000000 * DECIMAL_VALUE, 20, 0), // 400M Tokens for Liquidity (20%)
            TokenDistributeInfo("Marketing", 200000000 * DECIMAL_VALUE, 10, 0) // 200M Tokens for Marketing & Promotions (10%)
        ];

        // 🔹 Store tokenomics data into the contract's mapping for accessibility
        for (uint256 i = 0; i < arr.length; ++i) {
            _tokenDistributeData[i] = arr[i];
        }
    }

    /**
     * @notice Updates the USDT token contract address for the presale.
     * @dev This function allows the contract owner to modify the USDT token address
     *      used for accepting payments during the presale.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The new USDT contract address must not be a zero address (`0x0`).
     * - The new USDT contract address must be different from the current address to prevent redundant updates.
     *
     * @param usdtAddress The new USDT token contract address.
     *
     * Emits:
     * - `ChangeUSDTAddress` event indicating the USDT contract address has been updated.
     */
    function changeUSDTAddress(address usdtAddress) public onlyOwner {
        require(usdtAddress != address(0), "INVALID_ADDRESS"); // Ensure the address is valid
        require(IERC20(_usdtAddress) != IERC20(usdtAddress), "SAME_ADDRESS"); // Prevent redundant changes

        // Update the stored USDT contract address
        _usdtAddress = IERC20(usdtAddress);

        // Emit event for tracking the address update
        emit ChangeUSDTAddress(msg.sender, usdtAddress);
    }

    /**
     * @notice Updates the Ezipay Coin (ICO token) contract address used in the presale.
     * @dev Allows the owner to modify the contract address of the token being sold in the presale.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The new token contract address must not be a zero address (`0x0`).
     * - The new token contract address must be different from the current address to prevent redundant updates.
     *
     * @param tokenAddress The new token contract address.
     *
     * Emits:
     * - `ChangeTokenAddress` event indicating the token contract address has been updated.
     */
    function changeTokenAddress(address tokenAddress) public onlyOwner {
        require(tokenAddress != address(0), "INVALID_ADDRESS"); // Ensure the address is valid
        require(
            IERC20(_EPTokenAddress) != IERC20(tokenAddress),
            "SAME_ADDRESS"
        ); // Prevent redundant changes

        // Update the stored token contract address
        _EPTokenAddress = IERC20(tokenAddress);

        // Emit event for tracking the address update
        emit ChangeTokenAddress(msg.sender, tokenAddress);
    }

    /**
     * @notice Updates the receiver address that collects USDT during the presale.
     * @dev This function allows the contract owner to modify the address where USDT payments
     *      will be received for the presale.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The new receiver address must not be a zero address (`0x0`).
     * - The new receiver address must be different from the current address.
     *
     * @param receiverAddress The new wallet address designated to receive USDT funds.
     *
     * Emits:
     * - `ChangeReceiverAddress` event indicating the receiver address has been updated.
     */
    function changeReceiverAddress(address receiverAddress) public onlyOwner {
        require(receiverAddress != address(0), "INVALID_ADDRESS"); // Prevent setting a zero address
        require(_receiverAddress != receiverAddress, "SAME_ADDRESS"); // Prevent redundant updates

        // Update the receiver address
        _receiverAddress = receiverAddress;

        // Emit event to log the address change
        emit ChangeReceiverAddress(msg.sender, receiverAddress);
    }

    /**
     * @notice Modifies the token price during the presale.
     * @dev Allows the owner to adjust the price of the token dynamically based on
     *      market conditions or presale phases.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The new price must not be zero to prevent division errors.
     * - The new price must be different from the current price to avoid redundant updates.
     *
     * @param price The new token price in USDT (scaled to token decimals).
     *
     * Emits:
     * - `ChangePrice` event indicating the token price has been modified.
     */
    function changeTokenPrice(uint256 price) public onlyOwner {
        require(price != 0, "INVALID_PRICE"); // Ensure the new price is valid
        require(_tokenPrice != price, "SAME_PRICE"); // Prevent unnecessary state changes

        // Update the token price
        _tokenPrice = price;

        // Emit event to log the price change
        emit ChangePrice(msg.sender, price);
    }

    /**
     * @notice Enables the presale, allowing users to participate in token purchases.
     * @dev This function activates the presale phase, allowing investors to buy tokens.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The presale must not already be active.
     *
     * Emits:
     * - `PresaleStatus` event indicating the presale has been started.
     */
    function startPresale() public onlyOwner {
        if (!presaleActive) {
            presaleActive = true;
        } else {
            revert("ALREADY_ACTIVE"); // Ensure presale isn't already running
        }

        // Emit event to notify that presale has been activated
        emit PresaleStatus(msg.sender, presaleActive);
    }

    /**
     * @notice Temporarily pauses the presale without fully terminating it.
     * @dev This function allows the owner to halt the presale while keeping
     *      the ability to resume it later.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The presale must currently be active.
     *
     * Emits:
     * - `PresaleStatus` event indicating the presale has been paused.
     */
    function pausePresale() public onlyOwner {
        require(presaleActive, "PRESALE_NOT_ACTIVE"); // Ensure presale is currently running

        // Disable presale without terminating it completely
        presaleActive = false;

        // Emit event to log the pause action
        emit PresaleStatus(msg.sender, presaleActive);
    }

    /**
     * @notice Permanently ends the presale, preventing further token purchases.
     * @dev This function deactivates the presale and ensures no further transactions
     *      can occur under this phase.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The presale must be currently active.
     *
     * Emits:
     * - `PresaleStatus` event indicating the presale has been terminated.
     */
    function endPresale() public onlyOwner {
        require(presaleActive, "PRESALE_NOT_INITIALIZED"); // Ensure presale has been started

        // Fully terminate the presale
        presaleActive = false;

        // Emit event to notify that presale has ended
        emit PresaleStatus(msg.sender, presaleActive);
    }

    /**
     * @notice Allows the contract owner to recover any tokens from the contract balance.
     * @dev This function is used to transfer a specified amount of Ezipay (EZP) tokens
     *      from the contract's balance back to the owner's designated wallet address.
     *
     * @param amt The amount of tokens to be recovered.
     * @param to The recipient address where the recovered tokens should be sent.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The `amt` must be greater than zero.
     * - The recipient address `to` must be a valid non-zero address.
     *
     * Emits:
     * - `RecoverToken` event upon successful token recovery.
     */
    function recoverTokens(uint256 amt, address to) public onlyOwner {
        require(amt != 0, "INVALID_AMOUNT"); // Ensure a valid non-zero token amount
        require(to != address(0), "INVALID_ADDRESS"); // Ensure a valid recipient address

        // Transfer the specified token amount to the designated recipient
        _EPTokenAddress.safeTransfer(to, amt);

        // Emit event to log the recovery transaction for transparency
        emit RecoverToken(msg.sender, to, amt);
    }

    /**
     * @notice Sets or updates the authorized address for handling fiat-based transactions.
     * @dev This function assigns a new fiat processing address, allowing it to facilitate
     *      token transfers in exchange for fiat payments.
     *
     * @param newFiatAddress The new wallet address authorized to handle fiat-based transactions.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     * - The `newFiatAddress` must be a valid non-zero address.
     *
     * Emits:
     * - `FiatTransferAddressUpdated` event upon successful update.
     */
    function setFiatTransferAddress(address newFiatAddress) public onlyOwner {
        require(newFiatAddress != address(0), "INVALID_ADDRESS"); // Ensure a valid address

        // Assign the new fiat transaction processor address
        _fiatTransferAddress = newFiatAddress;

        // Emit event to log the update of the fiat transfer authority
        emit FiatTransferAddressUpdated(msg.sender, newFiatAddress);
    }

    /**
     * @notice Removes the currently authorized fiat transaction processing address.
     * @dev This function resets the fiat transaction handler, disabling the ability
     *      to facilitate fiat-based token transfers until a new address is assigned.
     *
     * Requirements:
     * - The caller must be the contract owner (`onlyOwner`).
     *
     * Emits:
     * - `FiatTransferAddressUpdated` event upon successful removal.
     */
    function removeFiatTransferAddress() public onlyOwner {
        // Reset the fiat transaction processor to a zero address
        _fiatTransferAddress = address(0);

        // Emit event to log the removal of fiat transaction authority
        emit FiatTransferAddressUpdated(msg.sender, address(0));
    }

    /**
     * @notice Transfers Ezipay (EZP) tokens to a user after a fiat payment.
     * @dev This function allows a pre-authorized wallet (fiat processor) to allocate tokens
     *      after confirming an off-chain fiat transaction. It ensures security by preventing
     *      unauthorized access and verifying the contract's token balance before transfer.
     *
     * @param receiver The wallet address of the user receiving the tokens.
     * @param tokenAmount The number of tokens to be transferred.
     * @param usdValue The USD equivalent value of the fiat payment made.
     *
     * Requirements:
     * - Only the `_fiatTransferAddress` (pre-authorized) can call this function.
     * - The receiver address must be valid (not zero address).
     * - The token amount must be greater than zero.
     * - The presale must be active to execute the transfer.
     * - The contract must have a sufficient token balance to fulfill the transfer.
     *
     * Events:
     * - `TokenTransferredForFiat` is emitted after a successful token transfer.
     * - `TokenPurchased` is emitted to record the fiat-based purchase.
     *
     * Security:
     * - The `nonReentrant` modifier prevents re-entrancy attacks.
     */
    function transferTokensForFiat(
        address receiver,
        uint256 tokenAmount,
        uint256 usdValue
    ) public nonReentrant {
        // Ensure that only the authorized fiat processor can execute this transaction
        require(msg.sender == _fiatTransferAddress, "ACCESS_DENIED");

        // Validate that the receiver's wallet address is not a zero address
        require(receiver != address(0), "INVALID_RECEIVER");

        // Ensure the token amount being transferred is greater than zero
        require(tokenAmount > 0, "INVALID_AMOUNT");

        // Confirm that the presale is still active before allowing token transfers
        require(presaleActive, "PRESALE_IS_NOT_ACTIVE");

        // Check that the contract has enough token balance to fulfill the transfer
        require(
            _EPTokenAddress.balanceOf(address(this)) >= tokenAmount,
            "INSUFFICIENT_CONTRACT_BALANCE"
        );

        // Securely transfer the tokens from the contract to the receiver's wallet
        _EPTokenAddress.safeTransfer(receiver, tokenAmount);

        // Record the transaction details for the receiver in `_userBuyDetails` mapping
        _userBuyDetails[receiver].push(
            BuyDetails({
                buyerAddress: receiver,
                usdtAddress: address(_usdtAddress), // USDT contract address reference
                usdtValue: usdValue, // The fiat equivalent amount in USD
                tokenValue: tokenAmount, // Number of EZP tokens allocated
                buyOptions: "Fiat", // Specifies that the purchase was made via fiat payment
                currentTime: block.timestamp, // Timestamp of the transaction
                status: true // Marks the transaction as successful
            })
        );

        // If this is the user's first purchase, add them to the buyers' list
        if (_userBuyDetails[receiver].length == 1) {
            _allBuyersAddress.push(receiver);
        }

        // Emit event to log the fiat-based token transfer
        emit TokenTransferredForFiat(receiver, tokenAmount, block.timestamp);

        // Emit event to record the purchase in the blockchain
        emit TokenPurchased(
            receiver,
            usdValue,
            "Fiat",
            tokenAmount,
            block.timestamp
        );
    }

    /**
     * @notice Allows users to buy Ezipay tokens using USDT.
     * @dev This function transfers USDT from the user to the receiver and sends the equivalent amount of Ezipay tokens.
     * Uses fixed-point arithmetic to prevent rounding errors when calculating token allocation.
     * Emits a `TokenPurchased` event on successful execution.
     *
     * Requirements:
     * - Presale must be active.
     * - The caller must have approved USDT for spending by this contract.
     * - The contract must have a sufficient token balance.
     *
     * @param usdtToken The amount of USDT the user is spending.
     */
    function buyPresaleToken(uint256 usdtToken) public nonReentrant {
        require(usdtToken > 0, "INVALID_AMOUNT");
        require(presaleActive, "PRESALE_NOT_ACTIVE");

        // Ensure user has enough USDT balance
        require(
            _usdtAddress.balanceOf(msg.sender) >= usdtToken,
            "INSUFFICIENT_USDT_BALANCE"
        );

        // Ensure the contract has the necessary allowance to transfer USDT on behalf of the user
        require(
            _usdtAddress.allowance(msg.sender, address(this)) >= usdtToken,
            "USDT_ALLOWANCE_TOO_LOW"
        );

        // ✅ Secure Transfer: Moves USDT from the buyer to the receiver (project treasury)
        _usdtAddress.safeTransferFrom(msg.sender, _receiverAddress, usdtToken);

        /**
         * ✅ FIXED: Precision-Optimized Token Calculation
         * - To prevent rounding issues, multiply before division.
         * - Uses Solidity's fixed-point arithmetic: (amount * scalingFactor) / price.
         * - Ensures accurate conversion of USDT to Ezipay tokens.
         */
        uint256 tokenValue = (usdtToken * DECIMAL_VALUE) / _tokenPrice;

        // Ensure the contract has enough tokens for the sale
        require(
            _EPTokenAddress.balanceOf(address(this)) >= tokenValue,
            "INSUFFICIENT_CONTRACT_TOKEN_BALANCE"
        );

        // ✅ Secure Token Transfer: Sends calculated tokens to the buyer
        _EPTokenAddress.safeTransfer(msg.sender, tokenValue);

        // Store the transaction details in the buyer's record
        _userBuyDetails[msg.sender].push(
            BuyDetails({
                buyerAddress: msg.sender,
                usdtAddress: address(_usdtAddress),
                usdtValue: usdtToken,
                tokenValue: tokenValue,
                buyOptions: "USDT",
                currentTime: block.timestamp,
                status: true
            })
        );

        // If this is the buyer's first transaction, add them to the buyers list
        if (_userBuyDetails[msg.sender].length == 1) {
            _allBuyersAddress.push(msg.sender);
        }

        // ✅ Event Emission: Logs the purchase details on-chain
        emit TokenPurchased(
            msg.sender,
            usdtToken,
            "USDT",
            tokenValue,
            block.timestamp
        );
    }

    /**
     * @notice Retrieves the contract address of the USDT token.
     * @dev This function provides the USDT token's contract address used for payments.
     * @return address The USDT contract address.
     */
    function getUsdtAddress() public view returns (address) {
        return address(_usdtAddress);
    }

    /**
     * @notice Retrieves the contract address of the Ezipay Token (EPToken).
     * @dev This function returns the address of the native token being sold in the presale.
     * @return address The Ezipay token contract address.
     */
    function getTokenAddress() public view returns (address) {
        return address(_EPTokenAddress);
    }

    /**
     * @notice Retrieves the receiver address for the presale funds.
     * @dev This address is where all collected USDT payments will be transferred during the token sale.
     * @return address The receiver's wallet address.
     */
    function getReceiverAddress() public view returns (address) {
        return _receiverAddress;
    }

    /**
     * @notice Retrieves the current token price in USDT.
     * @dev The price is stored in the `_tokenPrice` state variable and represents how much USDT is required per token.
     * @return uint256 The current price per Ezipay token in USDT (with decimals).
     */
    function getTokenPrice() public view returns (uint256) {
        return _tokenPrice;
    }

    /**
     * @notice Checks if the presale is currently active.
     * @dev Returns a boolean indicating whether the presale is open for token purchases.
     * @return bool True if the presale is active, false otherwise.
     */
    function getPresaleStatus() public view returns (bool) {
        return presaleActive;
    }

    /**
     * @notice Retrieves a list of all addresses that have participated in the presale.
     * @dev This function returns an array containing the wallet addresses of all users who have purchased tokens.
     * @return address[] An array of buyer addresses.
     */
    function getUserList() public view returns (address[] memory) {
        return _allBuyersAddress;
    }

    /**
     * @notice Fetches the purchase details for a specific user.
     * @dev This function retrieves the history of all token purchases made by the given user.
     * @param userAddress The wallet address of the user whose purchase details are requested.
     * @return BuyDetails[] An array of purchase transactions made by the user.
     */
    function fetchUserBuyDetails(address userAddress)
        public
        view
        returns (BuyDetails[] memory)
    {
        return _userBuyDetails[userAddress];
    }

    /**
     * @notice Retrieves all purchase details for all buyers in the presale.
     * @dev This function consolidates all purchase transactions recorded in the contract.
     * It iterates through all buyers and compiles a comprehensive list of transactions.
     * @return BuyDetails[] An array containing details of all token purchases.
     */
    function getAllBuyDetails() public view returns (BuyDetails[] memory) {
        uint256 totalTransactions = 0;

        // Calculate the total number of transactions
        for (uint256 i = 0; i < _allBuyersAddress.length; i++) {
            totalTransactions += _userBuyDetails[_allBuyersAddress[i]].length;
        }

        // Initialize an array to store all transaction details
        BuyDetails[] memory allDetails = new BuyDetails[](totalTransactions);
        uint256 currentIndex = 0;

        // Populate the array with transaction data
        for (uint256 i = 0; i < _allBuyersAddress.length; i++) {
            address userAddress = _allBuyersAddress[i];
            BuyDetails[] memory userDetails = _userBuyDetails[userAddress];

            for (uint256 j = 0; j < userDetails.length; j++) {
                allDetails[currentIndex] = userDetails[j];
                currentIndex++;
            }
        }

        return allDetails;
    }

    /**
     * @notice Retrieves the token distribution (tokenomics) data.
     * @dev This function provides insight into the allocation of Ezipay Coin (EZP) during the presale.
     * @return TokenDistributeInfo[] An array containing token allocation details.
     */
    function getTokonomicsData()
        public
        view
        returns (TokenDistributeInfo[] memory)
    {
        TokenDistributeInfo[] memory items = new TokenDistributeInfo[](5);
        for (uint256 i = 0; i < 5; ++i) {
            items[i] = _tokenDistributeData[i];
        }
        return items;
    }

    /**
     * @notice Retrieves the wallet address designated for handling fiat-based token transactions.
     * @dev This function is restricted to the contract owner and is used to view the currently set fiat transfer address.
     * @return address The wallet address authorized for fiat-based transactions.
     */
    function getFiatTransferAddress()
        external
        view
        onlyOwner
        returns (address)
    {
        return _fiatTransferAddress;
    }
}


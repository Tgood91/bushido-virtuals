// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

// ============================================================
//  BUSHIDOBASED ($BBASED) — Zora Coins ERC20z
//
//  Mint mechanic : Burn 0x97ecf1c222259529f0e9b9ae38fa7bff0da1ed15
//                  to mint $BBASED
//  Burn rate     : 7,101 tokens = 1 BBASED (owner adjustable)
//  Max supply    : 71,011,017 BBASED
//  Decimals      : 18
//  Network       : Base Mainnet (Chain ID 8453)
//  ZoraFactory   : 0x777777751622c0d3258f214F9DF38E35BF45baF3
//
//  ─── REMIX DEPLOY STEPS ────────────────────────────────────
//  1. Open Coinbase Wallet app → Browser → remix.ethereum.org
//  2. Create new file → paste this entire contract
//  3. Compiler tab:
//       - Solidity version: 0.8.11
//       - Enable optimization: YES (200 runs)
//  4. Deploy tab:
//       - Environment: Injected Provider (Coinbase Wallet)
//       - Contract: BushidoBased
//  5. Constructor args:
//       - _payoutRecipient = your wallet address
//       - _metadataUri     = your IPFS metadata URI (ipfs://...)
//  6. Click Deploy → confirm in Coinbase Wallet
//  7. AFTER DEPLOY: call deployZoraCoin() with 0.001 ETH
//  8. Verify on Basescan with your API key
// ============================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ─── Zora Factory Interface ────────────────────────────────
interface IZoraFactory {
    function deploy(
        address payoutRecipient,
        address[] memory owners,
        string memory uri,
        string memory name,
        string memory symbol,
        address platformReferrer,
        address currency,
        int24 tickLower,
        uint256 orderSize
    ) external payable returns (address coin, uint256 amountUsed);
}

// ─── Burnable ERC20 Interface ──────────────────────────────
interface IBurnable {
    function burnFrom(address account, uint256 amount) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title BushidoBased
 * @dev ERC20z token minted by burning 0x97ecf1c222259529f0e9b9ae38fa7bff0da1ed15
 *      at a rate of 7,101 tokens per 1 BBASED.
 *      Integrates with ZoraFactory on Base Mainnet.
 *      Hard cap: 71,011,017 BBASED.
 */
contract BushidoBased is ERC20, Ownable {

    // ─── Constants ─────────────────────────────────────────
    uint256 public constant MAX_SUPPLY = 71_011_017 * 10 ** 18;

    // Mint token — burned on every BBASED mint
    address public constant MINT_TOKEN = 0x97ecf1c222259529f0e9b9ae38fa7bff0da1ed15;

    // ZoraFactory on Base Mainnet — canonical, do not change
    address public constant ZORA_FACTORY = 0x777777751622c0d3258f214F9DF38E35BF45baF3;

    // Required Uniswap V3 tickLower for ETH/WETH pairs on Zora
    int24 public constant TICK_LOWER = -199200;

    // ─── Config ────────────────────────────────────────────
    uint256 public mintTokenPerBbased = 7_101 * 10 ** 18; // 7,101 tokens = 1 BBASED
    address public payoutRecipient;
    string  public metadataUri;
    bool    public mintingEnabled  = true;
    bool    public zoraDeployed    = false;
    address public zoraCoinAddress;

    // ─── Events ────────────────────────────────────────────
    event Minted(address indexed user, uint256 bbasedAmount, uint256 mintTokenBurned);
    event MintRateUpdated(uint256 oldRate, uint256 newRate);
    event MintingToggled(bool enabled);
    event ZoraCoinDeployed(address indexed coinAddress);

    // ─── Constructor ───────────────────────────────────────
    /**
     * @param _payoutRecipient Your wallet — receives Zora creator rewards
     * @param _metadataUri     IPFS URI for coin metadata (ipfs://...)
     */
    constructor(
        address _payoutRecipient,
        string memory _metadataUri
    ) ERC20("BushidoBased", "BBASED") Ownable(msg.sender) {
        require(_payoutRecipient != address(0), "Invalid payout address");
        payoutRecipient = _payoutRecipient;
        metadataUri     = _metadataUri;
    }

    // ─── Zora: Deploy Coin ─────────────────────────────────
    /**
     * @dev Registers BBASED as an official Zora Coin via ZoraFactory.
     *      Call ONCE after deploying this contract.
     *      Send ETH for initial Uniswap V3 liquidity (min 0.001 ETH).
     *      In Remix: set Value field to 0.001 ether before clicking.
     */
    function deployZoraCoin() external payable onlyOwner {
        require(!zoraDeployed, "Zora coin already deployed");
        require(msg.value > 0,  "Send ETH for initial liquidity");

        address[] memory owners = new address[](1);
        owners[0] = msg.sender;

        (address coin, ) = IZoraFactory(ZORA_FACTORY).deploy{value: msg.value}(
            payoutRecipient,
            owners,
            metadataUri,
            "BushidoBased",
            "BBASED",
            address(0),   // No platform referrer — set your address to earn referral fees
            address(0),   // ETH/WETH pair
            TICK_LOWER,
            msg.value
        );

        zoraCoinAddress = coin;
        zoraDeployed    = true;

        emit ZoraCoinDeployed(coin);
    }

    // ─── Mint ──────────────────────────────────────────────
    /**
     * @dev Burns mint tokens from caller and mints BBASED.
     *
     *      USER MUST APPROVE FIRST:
     *      Call approve(bbasedAddress, amount) on the mint token contract
     *      before calling this function.
     *
     * @param _bbasedAmount Whole BBASED to mint (e.g. 5 = 5 BBASED)
     */
    function mint(uint256 _bbasedAmount) external {
        require(mintingEnabled,    "Minting is currently paused");
        require(_bbasedAmount > 0, "Amount must be > 0");

        uint256 bbasedWei  = _bbasedAmount * 10 ** 18;
        uint256 burnCost   = _bbasedAmount * mintTokenPerBbased;

        require(totalSupply() + bbasedWei <= MAX_SUPPLY, "Exceeds max supply");

        require(
            IBurnable(MINT_TOKEN).balanceOf(msg.sender) >= burnCost,
            "Insufficient token balance"
        );
        require(
            IBurnable(MINT_TOKEN).allowance(msg.sender, address(this)) >= burnCost,
            "Approve token spend first"
        );

        // Burn mint token from user
        IBurnable(MINT_TOKEN).burnFrom(msg.sender, burnCost);

        // Mint BBASED to user
        _mint(msg.sender, bbasedWei);

        emit Minted(msg.sender, bbasedWei, burnCost);
    }

    // ─── View Helpers ──────────────────────────────────────
    /**
     * @dev Preview burn cost for a given BBASED mint amount.
     * @param _bbasedAmount Whole BBASED tokens (e.g. 10)
     * @return Cost in mint token wei
     */
    function quoteBurnCost(uint256 _bbasedAmount) external view returns (uint256) {
        return _bbasedAmount * mintTokenPerBbased;
    }

    /**
     * @dev How many BBASED can still be minted.
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @dev Check if a user is ready to mint a given amount.
     *      Returns true only if balance, allowance, supply, and minting are all good.
     */
    function canMint(address _user, uint256 _bbasedAmount) external view returns (bool) {
        uint256 burnCost  = _bbasedAmount * mintTokenPerBbased;
        uint256 bbasedWei = _bbasedAmount * 10 ** 18;
        return (
            IBurnable(MINT_TOKEN).balanceOf(_user)                >= burnCost  &&
            IBurnable(MINT_TOKEN).allowance(_user, address(this)) >= burnCost  &&
            totalSupply() + bbasedWei                             <= MAX_SUPPLY &&
            mintingEnabled
        );
    }

    // ─── Owner Functions ───────────────────────────────────
    /**
     * @dev Adjust the burn rate.
     *      Pass full wei amount e.g. 5000 tokens = 5000 * 10**18
     */
    function setMintRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0, "Rate must be > 0");
        emit MintRateUpdated(mintTokenPerBbased, _newRate);
        mintTokenPerBbased = _newRate;
    }

    /**
     * @dev Pause or unpause minting.
     */
    function toggleMinting() external onlyOwner {
        mintingEnabled = !mintingEnabled;
        emit MintingToggled(mintingEnabled);
    }

    /**
     * @dev Update Zora metadata URI.
     */
    function setMetadataUri(string calldata _newUri) external onlyOwner {
        metadataUri = _newUri;
    }

    /**
     * @dev Update Zora creator reward recipient.
     */
    function setPayoutRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid address");
        payoutRecipient = _newRecipient;
    }

    /**
     * @dev Owner direct mint for treasury, airdrops, team allocation.
     *      Respects MAX_SUPPLY hard cap.
     */
    function ownerMint(address _to, uint256 _amount) external onlyOwner {
        require(totalSupply() + _amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(_to, _amount);
    }

    /**
     * @dev Recover any ETH accidentally sent to this contract.
     */
    function rescueEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

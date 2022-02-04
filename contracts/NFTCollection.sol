// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NFTCollection is ERC721, AccessControl, Initializable {
    using Address for address payable;
    using Strings for uint256;

    struct ContractConfig {
        string name;
        string symbol;
        address owner;
        uint256 maxSupply;
        uint256 mintPrice;
        uint256 tokensPerMint;
        address treasuryAddress;
        uint256 publicMintStart;
        string baseURI;
        string prerevealTokenURI;
        uint256 presaleMintStart;
        bytes32 presaleMerkleRoot;
    }

    /*************
     * Constants *
     *************/

    /// Contract version
    /// @dev Hard-coded into the contract, semver-style uint X_YY_ZZ
    uint256 public constant version = 1_00_00;

    /// Admin role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /********************
     * Public variables *
     ********************/

    /// The maximum number of tokens that can ever exist
    /// @dev Set at initialization, immutable
    uint256 public maxSupply;

    /// Minting price per token
    /// @dev Set at initialization, immutable
    uint256 public mintPrice;

    /// The number of tokens the user can buy per transaction
    /// @dev Set at initialization, immutable
    uint256 public tokensPerMint;

    /// Treasury address for withdrawing minting fees after sale is finished
    /// @dev Set at initialization, immutable
    address payable public treasuryAddress;

    /// Starting timestamp for public minting
    /// @dev Set at initialization, updatable
    uint256 public publicMintStart;

    /// Starting timestamp for whitelisted minting
    /// @dev Set at initialization, updatable
    uint256 public presaleMintStart;

    /// Root of the Merkle tree of whitelisted addresses
    /// @dev Set at initialization, updatable
    bytes32 public presaleMerkleRoot;

    /// Base URI for constructing token metadata URIs
    /// @dev Set at initialization, updatable
    string public baseURI;

    /// Flag for disabling baseURI changes
    /// @dev Can only be flipped from false -> true
    bool public metadataFrozen;

    /// Pre-reveal token URI for placholder metadata
    /// @dev Set at initialization, updatable
    string public prerevealTokenURI;

    /// Contract owner address
    /// @dev Required for easy integration with OpenSea
    address public owner;

    /// The number of currently minted tokens
    /// @dev Managed by the contract
    uint256 public totalSupply;

    constructor() ERC721("", "") {
        _preventInitialization = true;
    }

    function initialize(ContractConfig calldata config) public initializer {
        require(!_preventInitialization, "Cannot be initialized");
        require(config.maxSupply > 0, "Maximum supply must be non-zero");
        require(config.tokensPerMint > 0, "Tokens per mint must be non-zero");
        require(
            config.treasuryAddress != address(0),
            "Treasury address cannot be the null address"
        );
        require(
            config.publicMintStart > block.timestamp,
            "Public mint start should be in the future"
        );
        require(
            config.presaleMintStart > block.timestamp,
            "Presale mint start should be in the future"
        );

        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, config.owner);
        _grantRole(DEFAULT_ADMIN_ROLE, config.owner);

        _name = config.name;
        _symbol = config.symbol;

        owner = config.owner;
        baseURI = config.baseURI;
        mintPrice = config.mintPrice;
        maxSupply = config.maxSupply;
        tokensPerMint = config.tokensPerMint;
        treasuryAddress = payable(config.treasuryAddress);
        prerevealTokenURI = config.prerevealTokenURI;
        publicMintStart = config.publicMintStart;
        presaleMintStart = config.presaleMintStart;
    }

    /****************
     * User actions *
     ****************/

    /// Mint tokens
    function mint(uint256 amount) external payable {
        require(mintingActive(), "Minting has not started yet");

        _mintTokens(msg.sender, amount);
    }

    /// Mint tokens if the wallet has been whitelisted
    function presaleMint(uint256 amount, bytes32[] calldata proof)
        external
        payable
    {
        require(presaleActive(), "Presale has not started yet");
        require(
            isWhitelisted(msg.sender, proof),
            "Not whitelisted for presale"
        );

        _presaleMinted[msg.sender] = true;
        _mintTokens(msg.sender, amount);
    }

    /******************
     * View functions *
     ******************/

    /// Check if public minting is active
    function mintingActive() public view returns (bool) {
        return block.timestamp >= publicMintStart;
    }

    /// Check if presale minting is active
    function presaleActive() public view returns (bool) {
        return block.timestamp >= presaleMintStart;
    }

    /// Check if the wallet is whitelisted for the presale
    function isWhitelisted(address wallet, bytes32[] calldata proof)
        public
        view
        returns (bool)
    {
        require(!_presaleMinted[wallet], "Already minted");

        bytes32 leaf = keccak256(abi.encodePacked(wallet));

        return MerkleProof.verify(proof, presaleMerkleRoot, leaf);
    }

    /*****************
     * Owner actions *
     *****************/

    function transferOwnership(address to)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(to != owner, "Already the owner");
        _grantRole(DEFAULT_ADMIN_ROLE, to);
        _revokeRole(DEFAULT_ADMIN_ROLE, owner);
        owner = to;
    }

    /*****************
     * Admin actions *
     *****************/

    /// Withdraw minting fees to the treasury address
    /// @dev Callable by admin roles only
    function withdrawFees() external onlyRole(ADMIN_ROLE) {
        treasuryAddress.sendValue(address(this).balance);
    }

    /// Set the timestamp where public minting will open
    /// @dev Callable by admin roles only
    function setPublicMintStart(uint256 timestamp)
        external
        onlyRole(ADMIN_ROLE)
    {
        publicMintStart = timestamp;
    }

    /// Update the pre-reveal metadata URI
    /// @dev Callable by admin roles only
    function setPrerevealTokenURI(string calldata uri)
        external
        onlyRole(ADMIN_ROLE)
    {
        prerevealTokenURI = uri;
    }

    /// Update the metadata base URI
    /// @dev Callable by admin roles only
    function setBaseURI(string calldata uri) external onlyRole(ADMIN_ROLE) {
        baseURI = uri;
    }

    /// Freeze the metadata base URI
    /// @dev Callable once by admin roles only
    function setMetadataFrozen(bool newValue) external onlyRole(ADMIN_ROLE) {
        require(newValue, "Metadata cannot be unfrozen");
        metadataFrozen = newValue;
    }

    /// Set the timestamp where presale minting will open
    /// @dev Callable by admin roles only
    function setPresaleMintStart(uint256 timestamp)
        external
        onlyRole(ADMIN_ROLE)
    {
        presaleMintStart = timestamp;
    }

    /// Set the Merkle tree root for the presale whitelist
    /// @dev Callable by admin roles only
    function setPresaleMerkleRoot(bytes32 newRoot)
        external
        onlyRole(ADMIN_ROLE)
    {
        presaleMerkleRoot = newRoot;
    }

    /*************
     * Internals *
     *************/

    /// Flag for disabling initalization for template contracts
    bool internal _preventInitialization;

    /// Mapping for tracking presale mint status
    mapping(address => bool) internal _presaleMinted;

    string internal _symbol;
    string internal _name;

    /// @dev Internal function for performing token mints
    function _mintTokens(address to, uint256 amount) internal {
        require(amount <= tokensPerMint, "Amount too large");
        require(msg.value >= amount * mintPrice, "Payment too small");

        uint256 newSupply = totalSupply + amount;
        require(newSupply <= maxSupply, "Maximum supply reached");

        // Update totalSupply only once with the total minted amount
        totalSupply = newSupply;
        // Mint the required amount of tokens,
        // starting with the highest token ID
        for (uint256 i = 1; i <= amount; i++) {
            _safeMint(to, totalSupply - i);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Token does not exist");

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : prerevealTokenURI;
    }

    /// @dev Need to name() to support setting it in the initializer instead of constructor
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @dev Need to symbol() to support setting it in the initializer instead of constructor
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}

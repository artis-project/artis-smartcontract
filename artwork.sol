// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract Artwork is ERC721 {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    using strings for *;

    address public SC_ADMIN;

    Counters.Counter private _tokenIdCounter;

    struct ArtworkData {
        uint256 id;
        address carrier;
        address logger;
        address recipient;
        string status;
        bool temperature_violation;
        bool humidity_violation;
    }

    mapping(uint256 => ArtworkData) artworks;

    enum Violation {
        temperature_violation,
        humidity_violation
    }

    event ViolationEvent(
        uint256 indexed tokenId,
        Violation violationType,
        bool isViolation
    );

    constructor() ERC721("Artwork", "ARTIS") {
        SC_ADMIN = msg.sender;
    }

    function safeMint(address to) public onlyAdmin returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        ArtworkData memory newArtwork = ArtworkData({
            id: tokenId,
            carrier: address(0),
            logger: address(0),
            recipient: address(0),
            status: "MINTED",
            temperature_violation: false,
            humidity_violation: false
        });
        artworks[tokenId] = newArtwork;
        return tokenId;
    }

    // setters

    function setViolation(
        Violation violationType,
        uint256 tokenId,
        address sender
    )
        public
        onlyLogger(sender, tokenId)
        onlyAdmin
        returns (
            uint256,
            address,
            address,
            address,
            string memory,
            bool,
            bool
        )
    {
        if (violationType == Violation.temperature_violation) {
            artworks[tokenId].temperature_violation = true;
        } else if (violationType == Violation.humidity_violation) {
            artworks[tokenId].humidity_violation = true;
        } else {
            require(false, "invalid violationType");
        }
        emit ViolationEvent(tokenId, violationType, true);
        return getArtworkData(tokenId, sender);
    }

    function setCarrier(
        address carrier,
        uint256 tokenId,
        address sender
    )
        public
        onlyOwner(sender, tokenId)
        onlyAdmin
        returns (
            uint256,
            address,
            address,
            address,
            string memory,
            bool,
            bool
        )
    {
        artworks[tokenId].carrier = carrier;
        return getArtworkData(tokenId, sender);
    }

    function setRecipient(
        address recipient,
        uint256 tokenId,
        address sender
    )
        public
        onlyOwner(sender, tokenId)
        onlyAdmin
        returns (
            uint256,
            address,
            address,
            address,
            string memory,
            bool,
            bool
        )
    {
        artworks[tokenId].recipient = recipient;
        return getArtworkData(tokenId, sender);
    }

    function setLogger(
        address logger,
        uint256 tokenId,
        address sender
    )
        public
        onlyOwner(sender, tokenId)
        onlyAdmin
        returns (
            uint256,
            address,
            address,
            address,
            string memory,
            bool,
            bool
        )
    {
        artworks[tokenId].logger = logger;
        return getArtworkData(tokenId, sender);
    }

    function setStatus(
        string memory status,
        uint256 tokenId,
        address sender
    )
        public
        onlyOwner(sender, tokenId)
        onlyAdmin
        returns (
            uint256,
            address,
            address,
            address,
            string memory,
            bool,
            bool
        )
    {
        artworks[tokenId].status = status;
        return getArtworkData(tokenId, sender);
    }

    function changeSmartContractAdmin(address newSC_Admin) public onlyAdmin {
        SC_ADMIN = newSC_Admin;
    }

    // getters

    function getArtworkData(uint256 tokenId, address sender)
        public
        view
        onlyAdmin
        read(sender, tokenId)
        returns (
            uint256 id,
            address carrier,
            address logger,
            address recipient,
            string memory status,
            bool temperature_violation,
            bool humidity_violation
        )
    {
        require(_exists(tokenId), "token does not exist");

        id = artworks[tokenId].id;
        carrier = artworks[tokenId].carrier;
        logger = artworks[tokenId].logger;
        recipient = artworks[tokenId].recipient;
        status = artworks[tokenId].status;
        humidity_violation = artworks[tokenId].humidity_violation;
        temperature_violation = artworks[tokenId].temperature_violation;
    }

    /// proofs that signature of type did:ethr:<address> is controlled by <address>
    /// alternatively just use signed <address> to safe gas to slice string
    function verifySignature(string calldata DID, bytes calldata signature)
        public
        view
        onlyAdmin
        returns (bool)
    {
        string memory didAddress = _extractAddressFromDID(DID);
        bytes32 signedMessageHash = keccak256(abi.encode(DID));
        address recoveredAddress = signedMessageHash.recover(signature);

        return
            _isStringEqual(Strings.toHexString(recoveredAddress), didAddress);
    }

    /// used to get addresses of different roles of an artwork (alongside ERC721 ownerOf)
    function carrierOf(uint256 tokenId)
        public
        view
        onlyAdmin
        returns (address)
    {
        require(_exists(tokenId), "Token does not exist");
        address carrier = artworks[tokenId].carrier;
        require(carrier != address(0), "no carrier defined");
        return artworks[tokenId].carrier;
    }

    function loggerOf(uint256 tokenId) public view onlyAdmin returns (address) {
        require(_exists(tokenId), "Token does not exist");
        address logger = artworks[tokenId].logger;
        require(logger != address(0), "no logger defined");
        return artworks[tokenId].logger;
    }

    function recipientOf(uint256 tokenId)
        public
        view
        onlyAdmin
        returns (address)
    {
        require(_exists(tokenId), "Token does not exist");
        address recipient = artworks[tokenId].recipient;
        require(recipient != address(0), "no recipient defined");
        return artworks[tokenId].recipient;
    }

    function isAuthorizedRead(address sender, uint256 tokenId)
        public
        view
        onlyAdmin
        returns (bool)
    {
        return
            ownerOf(tokenId) == sender ||
            carrierOf(tokenId) == sender ||
            recipientOf(tokenId) == sender;
    }

    // overrides

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    

    // modifiers
    modifier onlyAdmin() {
        require(msg.sender == SC_ADMIN, "only accessible by SC_admin wallet");
        _;
    }

    modifier onlyOwner(address sender, uint256 tokenId) {
        require(ownerOf(tokenId) == sender, "sender is not authorized");
        _;
    }

    modifier onlyLogger(address sender, uint256 tokenId) {
        require(loggerOf(tokenId) == sender, "sender is not authorized");
        _;
    }

    modifier read(address sender, uint256 tokenId) {
        require(isAuthorizedRead(sender, tokenId), "sender is not authorized");
        _;
    }

    // internal helper functions
    
    function _extractAddressFromDID(string memory did)
        internal
        pure
        returns (string memory)
    {
        string memory prefix = "did:ethr:";
        strings.slice memory s = did.toSlice();
        strings.slice memory prefixSlice = prefix.toSlice();
        strings.slice memory addressSlice = s.rsplit(prefixSlice);
        return _toLower(addressSlice.toString());
    }

    function _isStringEqual(string memory str1, string memory str2)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(str1)) == keccak256(abi.encode(str2));
    }

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./strings.sol";

contract Artwork is ERC721 {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    using strings for *;

    address public smartcontractAdmin;

    Counters.Counter private _tokenIdCounter;

    struct ArtworkData {
        uint256 id;
        address carrier;
        address logger;
        address recipient;
        string status;
        uint256 violationTimestamp;
    }

    mapping(uint256 => ArtworkData) internal artworks;

    enum Violation {
        temperatureViolation,
        humidityViolation
    }

    event ViolationEvent(
        uint256 indexed tokenId,
        Violation violationType,
        bool isViolation
    );

    event Minted(uint256 indexed tokenId, address owner);
    event Updated(uint256 indexed tokenId, ArtworkData newData);

    constructor() ERC721("Artwork", "ARTIS") {
        smartcontractAdmin = msg.sender;
    }

    function safeMint(address to) public onlyAdmin {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        ArtworkData memory newArtwork = ArtworkData({
            id: tokenId,
            carrier: address(0),
            logger: address(0),
            recipient: address(0),
            status: "MINTED",
            violationTimestamp: 0
        });
        artworks[tokenId] = newArtwork;
        emit Minted(tokenId, to);
    }

    // setters
    function changeSmartContractAdmin(
        address newsmartcontractAdmin
    ) public onlyAdmin {
        smartcontractAdmin = newsmartcontractAdmin;
    }

    // because the artwork data always needs to have all properties populated
    // the Address(1) is used to mark no change, Address(0) is reserved for not set
    function updateArtworkData(
        ArtworkData memory data,
        address sender
    ) public onlyAdmin exists(data.id) write(sender, data) {
        if (data.violationTimestamp != 0) {
            artworks[data.id].violationTimestamp = data.violationTimestamp;
        }
        if ((bytes(data.status).length != 0)) {
            artworks[data.id].status = data.status;
        }
        if (data.carrier != address(1)) {
            artworks[data.id].carrier = data.carrier;
        }
        if (data.recipient != address(1)) {
            artworks[data.id].recipient = data.recipient;
        }
        if (data.logger != address(1)) {
            artworks[data.id].logger = data.logger;
        }
        emit Updated(data.id, artworks[data.id]);
    }

    // getter
    function getArtworkData(
        uint256 tokenId,
        address sender
    )
        public
        view
        onlyAdmin
        exists(tokenId)
        read(sender, tokenId)
        returns (
            uint256 id,
            address owner,
            address carrier,
            address logger,
            address recipient,
            string memory status,
            uint256 violationTimestamp
        )
    {
        id = artworks[tokenId].id;
        owner = ownerOf(tokenId);
        carrier = artworks[tokenId].carrier;
        logger = artworks[tokenId].logger;
        recipient = artworks[tokenId].recipient;
        status = artworks[tokenId].status;
        violationTimestamp = artworks[tokenId].violationTimestamp;
    }

    /// proofs that signature of type did:ethr:<address> is controlled by <address>
    /// alternatively just use signed <address> to safe gas to slice string
    function verifySignature(
        string calldata did,
        bytes calldata signature
    ) public view onlyAdmin returns (address) {
        string memory didAddress = _extractAddressFromdid(did);
        bytes32 signedMessageHash = keccak256(abi.encode(did));
        address recoveredAddress = signedMessageHash.recover(signature);
        require(
            _isStringEqual(Strings.toHexString(recoveredAddress), didAddress),
            "did and recovered address do not match"
        );
        return recoveredAddress;
    }

    /// used to get addresses of different roles of an artwork (alongside ERC721 ownerOf)
    function carrierOf(
        uint256 tokenId
    ) public view onlyAdmin exists(tokenId) returns (address) {
        return artworks[tokenId].carrier;
    }

    function loggerOf(
        uint256 tokenId
    ) public view onlyAdmin exists(tokenId) returns (address) {
        return artworks[tokenId].logger;
    }

    function recipientOf(
        uint256 tokenId
    ) public view onlyAdmin exists(tokenId) returns (address) {
        return artworks[tokenId].recipient;
    }

    function isAuthorizedRead(
        address sender,
        uint256 tokenId
    ) public view onlyAdmin returns (bool) {
        return
            ownerOf(tokenId) == sender ||
            carrierOf(tokenId) == sender ||
            recipientOf(tokenId) == sender;
    }

    // overrides

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // modifiers

    modifier exists(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == smartcontractAdmin,
            "only accessible by smartcontractAdmin wallet"
        );
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

    modifier write(address sender, ArtworkData memory data) {
        if (data.violationTimestamp != 0) {
            require(
                sender == loggerOf(data.id),
                "only logger is allowed to access this field"
            );
        } else {
            require(sender == ownerOf(data.id));
        }
        _;
    }

    // internal helper functions

    function _extractAddressFromdid(
        string memory did
    ) internal pure returns (string memory) {
        string memory prefix = "did:ethr:";
        strings.slice memory s = did.toSlice();
        strings.slice memory prefixSlice = prefix.toSlice();
        strings.slice memory addressSlice = s.rsplit(prefixSlice);
        return _toLower(addressSlice.toString());
    }

    function _isStringEqual(
        string memory str1,
        string memory str2
    ) internal pure returns (bool) {
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

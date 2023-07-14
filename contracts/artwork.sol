// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Artwork is ERC721 {
    using Counters for Counters.Counter;
    using Strings for string;

    address public smartcontractAdmin;

    Counters.Counter public totalSupply;

    struct ArtworkData {
        uint256 id;
        string objectId;
        address carrier;
        address logger;
        address recipient;
        Status status;
        uint256 violationTimestamp;
    }

    struct StatusApprovals {
        bool carrier;
        bool owner;
        bool recipient;
    }

    struct Status {
        string currentStatus;
        string requestedStatus;
    }

    struct balance {
        uint256[] carrier;
        uint256[] recipient;
        uint256[] owner;
        uint256[] logger;
    }

    enum StatusValue {
        IN_TRANSIT,
        TO_BE_DELIVERED,
        DELIVERED,
        NONE
    }

    mapping(uint256 => ArtworkData) internal artworks;

    mapping(uint256 => mapping(StatusValue => StatusApprovals))
        internal approvals;

    event Updated(
        uint256 indexed tokenId,
        ArtworkData newData,
        address owner,
        StatusApprovals approvals
    );

    event StatusApproved(
        uint256 indexed tokenId,
        StatusApprovals approvals,
        address approver
    );

    event ApprovalMissing(
        uint256 indexed tokenId,
        string requestedStatus,
        address missingApproval
    );

    constructor() ERC721("Artwork", "ARTIS") {
        smartcontractAdmin = msg.sender;
    }

    function safeMint(address to, ArtworkData memory data) public onlyAdmin {
        // start ids at 1
        totalSupply.increment();
        uint256 tokenId = totalSupply.current();
        _safeMint(to, tokenId);
        ArtworkData memory newArtwork = ArtworkData({
            id: tokenId,
            objectId: data.objectId,
            carrier: data.carrier,
            logger: data.logger,
            recipient: data.recipient,
            violationTimestamp: 0,
            status: Status({
                currentStatus: getStatusString(StatusValue.TO_BE_DELIVERED),
                requestedStatus: getStatusString(StatusValue.NONE)
            })
        });
        artworks[tokenId] = newArtwork;
    }

    // setters
    function changeSmartContractAdmin(address newsmartcontractAdmin)
        public
        onlyAdmin
    {
        smartcontractAdmin = newsmartcontractAdmin;
    }

    // because the artwork data always needs to have all properties populated
    // the Address(1) is used to mark no change, Address(0) is reserved for not set
    function updateArtworkData(ArtworkData memory data, address sender)
        public
        onlyAdmin
        exists(data.id)
        write(sender, data)
    {
        if (data.violationTimestamp != 0) {
            artworks[data.id].violationTimestamp = data.violationTimestamp;
        }
        if (bytes(data.status.requestedStatus).length != 0) {
            if (
                getStatusEnum(artworks[data.id].status.requestedStatus) !=
                getStatusEnum(data.status.requestedStatus)
            ) {
                resetApprovals(data.id);
                // set new requestedStatus after resetting all approvals
                artworks[data.id].status.requestedStatus = data
                    .status
                    .requestedStatus;
            }
            updateStatus(
                data.id,
                sender,
                getStatusEnum(artworks[data.id].status.currentStatus),
                getStatusEnum(data.status.requestedStatus)
            );
        }
        if ((bytes(data.objectId).length != 0)) {
            artworks[data.id].objectId = data.objectId;
        }
        if (data.carrier != address(1)) {
            artworks[data.id].carrier = data.carrier;
        }
        if (data.recipient != address(1)) {
            artworks[data.id].recipient = data.recipient;
        }
        if (data.logger != address(1)) {
            require(
                !(artworks[data.id].status.currentStatus.equal("IN_TRANSIT")),
                "logger cannot be updated in transit 403"
            );
            artworks[data.id].logger = data.logger;
        }
        emit Updated(
            data.id,
            artworks[data.id],
            ownerOf(data.id),
            approvals[data.id][
                getStatusEnum(artworks[data.id].status.requestedStatus)
            ]
        );
    }

    // getter
    function getArtworkData(uint256 tokenId, address sender)
        public
        view
        onlyAdmin
        exists(tokenId)
        read(sender, tokenId)
        returns (
            uint256 id,
            string memory objectId,
            address owner,
            address carrier,
            address logger,
            address recipient,
            string memory currentStatus,
            string memory requestedStatus,
            bool carrierApproval,
            bool ownerApproval,
            bool recipientApproval,
            uint256 violationTimestamp
        )
    {
        StatusValue status = getStatusEnum(
            artworks[tokenId].status.requestedStatus
        );

        id = artworks[tokenId].id;
        objectId = artworks[tokenId].objectId;
        owner = ownerOf(tokenId);
        carrier = artworks[tokenId].carrier;
        logger = artworks[tokenId].logger;
        recipient = artworks[tokenId].recipient;
        currentStatus = artworks[tokenId].status.currentStatus;
        requestedStatus = artworks[tokenId].status.requestedStatus;
        carrierApproval = approvals[tokenId][status].carrier;
        ownerApproval = approvals[tokenId][status].owner;
        recipientApproval = approvals[tokenId][status].recipient;
        violationTimestamp = artworks[tokenId].violationTimestamp;
    }

    function getArtworkIdsByAddress(address _address)
        public
        view
        onlyAdmin
        returns (
            uint256[] memory owner,
            uint256[] memory recipient,
            uint256[] memory carrier,
            uint256[] memory logger
        )
    {
        uint256 currentSupply = totalSupply.current();
        owner = new uint256[](currentSupply);
        recipient = new uint256[](currentSupply);
        carrier = new uint256[](currentSupply);
        logger = new uint256[](currentSupply);
        uint256 index = 0;

        for (uint256 i = 1; i <= currentSupply; i++) {
            ArtworkData storage artwork = artworks[i];

            if (ownerOf(i) == _address) {
                owner[index] = artwork.id;
                index++;
            }
            if (recipientOf(i) == _address) {
                recipient[index] = artwork.id;
                index++;
            }
            if (carrierOf(i) == _address) {
                carrier[index] = artwork.id;
                index++;
            }
            if (loggerOf(i) == _address) {
                logger[index] = artwork.id;
                index++;
            }
        }
    }

    function getPendingApprovals(uint256 tokenId, StatusValue status)
        internal
        view
        onlyAdmin
        returns (
            bool carrier,
            bool recipient,
            bool owner
        )
    {
        carrier = approvals[tokenId][status].carrier;
        recipient = approvals[tokenId][status].recipient;
        owner = approvals[tokenId][status].owner;
    }

    // helper functions

    // functions for multi-party status change approval
    function checkSenderApproval(
        uint256 tokenId,
        address sender,
        StatusValue status
    ) internal view read(sender, tokenId) onlyAdmin returns (bool) {
        if (sender == ownerOf(tokenId)) {
            return approvals[tokenId][status].owner;
        } else if (sender == carrierOf(tokenId)) {
            return approvals[tokenId][status].carrier;
        } else if (sender == recipientOf(tokenId)) {
            return approvals[tokenId][status].recipient;
        } else {
            return false;
        }
    }

    function setSenderApproval(
        uint256 tokenId,
        address sender,
        StatusValue status,
        bool approval
    ) internal read(sender, tokenId) onlyAdmin {
        if (sender == ownerOf(tokenId)) {
            approvals[tokenId][status].owner = approval;
        } else if (sender == carrierOf(tokenId)) {
            approvals[tokenId][status].carrier = approval;
        } else if (sender == recipientOf(tokenId)) {
            approvals[tokenId][status].recipient = approval;
        }
    }

    function setCurrentStatus(uint256 tokenId, StatusValue requestedStatus)
        internal
        onlyAdmin
    {
        artworks[tokenId].status.currentStatus = getStatusString(
            requestedStatus
        );
        artworks[tokenId].status.requestedStatus = getStatusString(
            StatusValue.NONE
        );
        resetApprovals(tokenId);
    }

    function resetApprovals(uint256 tokenId) internal onlyAdmin {
        delete approvals[tokenId][StatusValue.TO_BE_DELIVERED];
        delete approvals[tokenId][StatusValue.DELIVERED];
        delete approvals[tokenId][StatusValue.IN_TRANSIT];
        delete approvals[tokenId][StatusValue.NONE];
    }

    function updateStatus(
        uint256 tokenId,
        address sender,
        StatusValue currentStatus,
        StatusValue requestedStatus
    ) internal onlyAdmin {
        setSenderApproval(tokenId, sender, requestedStatus, true);
        // case to change from TO_BE_DELIVERED to IN_TRANSIT -> carrier and owner have to agree
        if (
            currentStatus == StatusValue.TO_BE_DELIVERED &&
            requestedStatus == StatusValue.IN_TRANSIT
        ) {
            if (
                approvals[tokenId][requestedStatus].carrier &&
                approvals[tokenId][requestedStatus].owner
            ) {
                //status change is valid
                setCurrentStatus(tokenId, requestedStatus);
                emit StatusApproved(
                    tokenId,
                    approvals[tokenId][requestedStatus],
                    sender
                );
            } else {
                // emit event with missing approval
                address otherParty;
                if (!approvals[tokenId][requestedStatus].carrier) {
                    otherParty = carrierOf(tokenId);
                } else {
                    otherParty = ownerOf(tokenId);
                }
                emit ApprovalMissing(
                    tokenId,
                    getStatusString(requestedStatus),
                    otherParty
                );
            }
        }
        // case to change from IN_TRANSIT to DELIVERED -> carrier and recipient have to agree
        else if (
            currentStatus == StatusValue.IN_TRANSIT &&
            requestedStatus == StatusValue.DELIVERED
        ) {
            if (
                approvals[tokenId][requestedStatus].carrier &&
                approvals[tokenId][requestedStatus].recipient
            ) {
                //status change is valid
                setCurrentStatus(tokenId, requestedStatus);
                emit StatusApproved(
                    tokenId,
                    approvals[tokenId][requestedStatus],
                    sender
                );
            } else {
                // emit event with missing approval
                address otherParty;
                if (!approvals[tokenId][requestedStatus].carrier) {
                    otherParty = carrierOf(tokenId);
                } else {
                    otherParty = recipientOf(tokenId);
                }
                emit ApprovalMissing(
                    tokenId,
                    getStatusString(requestedStatus),
                    otherParty
                );
            }
        }
        // case to change from DELIVERED to TO_BE_DELIVERED -> owner decides soley
        else if (
            currentStatus == StatusValue.DELIVERED &&
            requestedStatus == StatusValue.TO_BE_DELIVERED
        ) {
            require(
                sender == ownerOf(tokenId),
                "only the owner is allowed to change the status from DELIVERED to TO_BE_DELIVERED 403"
            );
            setCurrentStatus(tokenId, requestedStatus);
            emit StatusApproved(
                tokenId,
                approvals[tokenId][requestedStatus],
                sender
            );
        } else {
            revert(
                "Status update is not allowed in respect to currentStatus 403"
            );
        }
    }

    // used to get addresses of different roles of an artwork (alongside ERC721 ownerOf)
    function carrierOf(uint256 tokenId)
        public
        view
        onlyAdmin
        exists(tokenId)
        returns (address)
    {
        return artworks[tokenId].carrier;
    }

    function loggerOf(uint256 tokenId)
        public
        view
        onlyAdmin
        exists(tokenId)
        returns (address)
    {
        return artworks[tokenId].logger;
    }

    function recipientOf(uint256 tokenId)
        public
        view
        onlyAdmin
        exists(tokenId)
        returns (address)
    {
        return artworks[tokenId].recipient;
    }

    function isAuthorizedRead(address sender, uint256 tokenId)
        internal
        view
        onlyAdmin
        returns (bool)
    {
        return
            ownerOf(tokenId) == sender ||
            carrierOf(tokenId) == sender ||
            recipientOf(tokenId) == sender;
    }

    function getStatusString(StatusValue value)
        internal
        view
        onlyAdmin
        returns (string memory)
    {
        if (uint256(value) == uint256(StatusValue.IN_TRANSIT)) {
            return "IN_TRANSIT";
        } else if (uint256(value) == uint256(StatusValue.TO_BE_DELIVERED)) {
            return "TO_BE_DELIVERED";
        } else if (uint256(value) == uint256(StatusValue.DELIVERED)) {
            return "DELIVERED";
        } else {
            return "NONE";
        }
    }

    function getStatusEnum(string memory value)
        internal
        view
        onlyAdmin
        returns (StatusValue)
    {
        if (value.equal("IN_TRANSIT")) {
            return StatusValue.IN_TRANSIT;
        } else if (value.equal("TO_BE_DELIVERED")) {
            return StatusValue.TO_BE_DELIVERED;
        } else if (value.equal("DELIVERED")) {
            return StatusValue.DELIVERED;
        } else if (value.equal("NONE")) {
            return StatusValue.NONE;
        } else {
            revert("Provided status is not valid 400");
        }
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

    modifier exists(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist 404");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == smartcontractAdmin,
            "only accessible by smartcontractAdmin wallet 403"
        );
        _;
    }

    modifier onlyOwner(address sender, uint256 tokenId) {
        require(ownerOf(tokenId) == sender, "sender is not authorized 403");
        _;
    }

    modifier onlyLogger(address sender, uint256 tokenId) {
        require(loggerOf(tokenId) == sender, "sender is not authorized 403");
        _;
    }

    modifier read(address sender, uint256 tokenId) {
        require(
            isAuthorizedRead(sender, tokenId),
            "sender is not authorized 403"
        );
        _;
    }

    modifier write(address sender, ArtworkData memory data) {
        if (data.violationTimestamp != 0) {
            require(
                sender == loggerOf(data.id),
                "only logger is allowed to add a violationTimestamp 403"
            );
        }
        require(
            bytes(data.status.currentStatus).length == 0,
            "currentStatus is updated automatically 403"
        );
        if (sender != ownerOf(data.id)) {
            require(
                bytes(data.objectId).length == 0 &&
                    data.carrier == address(1) &&
                    data.recipient == address(1) &&
                    data.logger == address(1),
                "only owner has write permissions 403"
            );
        }
        _;
    }
}

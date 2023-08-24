// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NameRegistry is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public nextTokenId = 1; // ID for the next token to be minted
    uint256 public baseRegistrationPrice = 0.01 ether - 0.0002 ether; // Base registration price for a name
    uint256 public registrationDuration = 365 days; // Default registration duration
    string private tld = ".mode"; // The top-level domain

    mapping(string => uint256) public namePrices; // Mapping of names to their custom registration prices
    mapping(string => bool) public nameExists; // Mapping to track whether a name is registered
    mapping(uint256 => string) public tokenIdToName; // Mapping of token IDs to names
    mapping(string => uint256) public nameToTokenId; // Mapping of names to their token IDs
    mapping(uint256 => uint256) public tokenIdToCreationTimestamp; // Mapping of token IDs to creation timestamps
    mapping(uint256 => string) private tokenURIs; // Mapping of token IDs to their metadata URIs
    mapping(string => uint256) public nameExpiry; // Mapping of names to their expiry timestamps

    event RegistrationPriceChanged(uint256 newPrice);
    event TransferPriceChanged(uint256 newPrice);
    event NameRegistered(address indexed owner, string name, uint256 expiryTimestamp);
    event NameTransferred(address indexed from, address indexed to, string name);
    event NameRenewed(address indexed owner, string name, uint256 newExpiryTimestamp);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    // Update the base registration price (onlyOwner function)
    function setBaseRegistrationPrice(uint256 price) external onlyOwner {
        baseRegistrationPrice = price;
        emit RegistrationPriceChanged(price);
    }

    // Set a custom registration price for a specific name (onlyOwner function)
    function setRegistrationPrice(string memory name, uint256 price) external onlyOwner {
        namePrices[name] = price;
    }

    // Set the registration duration for names (onlyOwner function)
    function setRegistrationDuration(uint256 duration) external onlyOwner {
        registrationDuration = duration;
    }

    // Get the registration price for a name
    function getRegistrationPrice(string memory name) public view returns (uint256) {
        uint256 nameLength = bytes(name).length;

        require(nameLength > 2, "Name must have more than 2 characters");

        uint256 price = baseRegistrationPrice;

        if (nameLength == 3) {
            price = price.mul(2); // Double the price for 3 characters
        } else if (nameLength > 3) {
            price = price.mul(3).div(2); // 1.5x the price for more than 3 characters
        }

        for (uint256 i = 0; i < nameLength; i++) {
            if (_isDigit(bytes(name)[i])) {
                price = price.div(2); // Reduce price by 2x if numerical digit found
            }
        }

        return price;
    }

    // Internal function to check if a character is a digit
    function _isDigit(bytes1 _char) internal pure returns (bool) {
        return (_char >= bytes1("0") && _char <= bytes1("9"));
    }

    // Internal function to check if an address is already registered
    function _isAddressRegistered(address addr) internal view returns (bool) {
        for (uint256 tokenId = 1; tokenId < nextTokenId; tokenId++) {
            if (_exists(tokenId) && ownerOf(tokenId) == addr) {
                return true;
            }
        }
        return false;
    }

    // External function to check if an address is registered
    function Registered(address addr) external view returns (bool) {
        return _isAddressRegistered(addr);
    }

    // Register a name with a metadata URI (payable function)
    function registerName(string memory name, string memory metadataURI) external payable {
        require(nameExists[name] == false, "Name is already registered");
        require(!_isAddressRegistered(msg.sender), "Address is already registered with a name");

        uint256 currentPrice = getRegistrationPrice(name);
        require(msg.value >= currentPrice, "Insufficient funds sent");

        // Mint a new NFT with the nextTokenId
        _mint(msg.sender, nextTokenId);
        nameToTokenId[name] = nextTokenId;
        nameExists[name] = true;
        tokenIdToName[nextTokenId] = name;
        tokenIdToCreationTimestamp[nextTokenId] = block.timestamp;
        tokenURIs[nextTokenId] = metadataURI;
        nameExpiry[name] = block.timestamp + registrationDuration;
        emit NameRegistered(msg.sender, name, nameExpiry[name]);

        // Increment the nextTokenId after minting
        nextTokenId++;

        uint256 excessAmount = msg.value.sub(currentPrice);
        if (excessAmount > 0) {
            payable(msg.sender).transfer(excessAmount);
        }
    }

    // Set the metadata URI for a token (onlyOwner function)
    function setTokenURI(uint256 tokenId, string memory metadataURI) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        tokenURIs[tokenId] = metadataURI;
    }

    // Get the metadata URI for a token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return tokenURIs[tokenId];
    }

    // Transfer a registered name to another address
    function transferName(address to, uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can transfer");

        string memory fullName = tokenIdToName[tokenId];
        _transfer(msg.sender, to, tokenId);

        emit NameTransferred(msg.sender, to, fullName);
    }

    // Extend the registration duration of a name (payable function)
    function extendDuration(string memory name, uint256 numYears) external payable {
        require(nameExists[name], "Name is not registered");
        require(ownerOf(tokenIdOf(name)) == msg.sender, "Only the owner can extend duration");
        require(numYears > 0, "Extension duration must be greater than 0");

        uint256 extensionPrice = getExtensionPrice(name, numYears);
        require(msg.value >= extensionPrice, "Insufficient funds sent");

        nameExpiry[name] += numYears * 365 days;

        uint256 excessAmount = msg.value.sub(extensionPrice);
        if (excessAmount > 0) {
            payable(msg.sender).transfer(excessAmount);
        }

        emit NameRenewed(msg.sender, name, nameExpiry[name]);
    }

    // Get the extension price for extending the registration of a name
    function getExtensionPrice(string memory name, uint256 numYears) public view returns (uint256) {
        require(nameExists[name], "Name is not registered");

        uint256 currentExpiry = nameExpiry[name];
        uint256 extensionExpiry = currentExpiry + numYears * 365 days;

        uint256 extensionPrice = getRegistrationPrice(name);

        return extensionPrice;
    }

    // Resolve a name to an address
    function resolveName(string memory nameWithTld) external view returns (address) {
        require(bytes(nameWithTld).length > bytes(tld).length, "Invalid name format");

        string memory name = substring(nameWithTld, 0, bytes(nameWithTld).length - bytes(tld).length);
        uint256 tokenId = tokenIdOf(name);

        if (tokenId != 0) {
            return ownerOf(tokenId);
        }

        return address(0);
    }

    // Extract a substring from a string
    function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        require(startIndex <= endIndex && endIndex <= strBytes.length, "Invalid substring range");

        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    // Get the token ID associated with a name
    function tokenIdOf(string memory name) public view returns (uint256) {
        return nameToTokenId[name];
    }

    // Get name details by owner's address
    function getNameByAddress(address addr) external view returns (
        string memory nameValue,
        uint256 creationTimestamp,
        uint256 registrationPrice,
        uint256 expiryTimestamp,
        string memory tokenURIValue
    ) {
        for (uint256 tokenId = 1; tokenId < nextTokenId; tokenId++) {
            if (_exists(tokenId) && ownerOf(tokenId) == addr) {
                string memory fullName = tokenIdToName[tokenId];
                return (
                    fullName,
                    tokenIdToCreationTimestamp[tokenId],
                    getRegistrationPrice(fullName),
                    nameExpiry[fullName],
                    tokenURIs[tokenId]
                );
            }
        }
        return ("", 0, 0, 0, "");
    }

    // Resolve an address to a registered name
    function reverseResolver(address addr) external view returns (string memory) {
        for (uint256 tokenId = 1; tokenId < nextTokenId; tokenId++) {
            if (_exists(tokenId) && ownerOf(tokenId) == addr) {
                string memory nameWithoutTLD = tokenIdToName[tokenId];
                return string(abi.encodePacked(nameWithoutTLD, tld));
            }
        }
        return "";
    }

    // Get detailed information about a registered name
    function getNameDetails(string memory name) external view returns (
        address ownerAddress,
        uint256 creationTimestamp,
        uint256 registrationPrice,
        uint256 expiryTimestamp,
        string memory tokenURIValue
    ) {
        uint256 tokenId = tokenIdOf(name);

        require(nameExists[name], "Name is not registered");

        return (
            ownerOf(tokenId),
            tokenIdToCreationTimestamp[tokenId],
            getRegistrationPrice(name),
            nameExpiry[name],
            tokenURIs[tokenId]
        );
    }

    function getAllRegisteredAddresses() external view returns (address[] memory) {
    address[] memory registeredAddresses = new address[](nextTokenId - 1); // Exclude the default token ID of 0

    for (uint256 tokenId = 1; tokenId < nextTokenId; tokenId++) {
        if (_exists(tokenId)) {
            registeredAddresses[tokenId - 1] = ownerOf(tokenId);
        }
    }

    return registeredAddresses;
}

    // Withdraw contract balance (onlyOwner function)
    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        payable(owner()).transfer(contractBalance);
    }
}

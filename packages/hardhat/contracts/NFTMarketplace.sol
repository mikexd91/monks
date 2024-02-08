// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is Ownable {
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) private listings;

    uint256 private feePercentage;

    event ListingCreated(uint256 indexed tokenId, uint256 price);
    event ListingPriceUpdated(uint256 indexed tokenId, uint256 price);
    event ListingRemoved(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, address buyer, uint256 price);

    constructor() {
        feePercentage = 1; // default fee percentage is 1%
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 100, "Fee percentage must be less than or equal to 100");
        feePercentage = _feePercentage;
    }

    function createListing(uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "Price must be greater than zero");
        require(listings[_tokenId].active == false, "Listing already exists for this token");

        IERC721 nftContract = IERC721(msg.sender);
        require(nftContract.ownerOf(_tokenId) == msg.sender, "You do not own this token");

        listings[_tokenId] = Listing({
            seller: msg.sender,
            tokenId: _tokenId,
            price: _price,
            active: true
        });

        emit ListingCreated(_tokenId, _price);
    }

    function updateListingPrice(uint256 _tokenId, uint256 _price) external {
        require(listings[_tokenId].active == true, "Listing does not exist for this token");
        require(listings[_tokenId].seller == msg.sender, "You are not the seller");

        listings[_tokenId].price = _price;

        emit ListingPriceUpdated(_tokenId, _price);
    }

    function removeListing(uint256 _tokenId) external {
        require(listings[_tokenId].active == true, "Listing does not exist for this token");
        require(listings[_tokenId].seller == msg.sender, "You are not the seller");

        delete listings[_tokenId];

        emit ListingRemoved(_tokenId);
    }

    function buyNFT(uint256 _tokenId) external payable {
        require(listings[_tokenId].active == true, "Listing does not exist for this token");
        require(msg.value >= listings[_tokenId].price, "Insufficient payment");

        Listing memory listing = listings[_tokenId];
        address seller = listing.seller;
        uint256 price = listing.price;
        
        listings[_tokenId].active = false;
        delete listings[_tokenId];

        IERC721 nftContract = IERC721(address(this));
        nftContract.safeTransferFrom(seller, msg.sender, _tokenId);

        uint256 feeAmount = (price * feePercentage) / 100;
        uint256 sellerAmount = price - feeAmount;

        (bool success, ) = seller.call{value: sellerAmount}("");
        require(success, "Failed to send payment to seller");

        emit NFTSold(_tokenId, msg.sender, price);
    }

    function getListing(uint256 _tokenId) external view returns (Listing memory) {
        return listings[_tokenId];
    }

    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }
}
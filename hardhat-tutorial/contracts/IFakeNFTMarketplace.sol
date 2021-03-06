//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFakeNFTMarketplace {
    ///@dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    ///@return Return the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    ///@dev available() returns whether or not the given 
    ///@param _tokenId - the fake tokenID to check if it has already been purchased
    ///@return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    ///@dev purchase() purchases an NFT from the FakeNFTMarketplace
    ///@param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}


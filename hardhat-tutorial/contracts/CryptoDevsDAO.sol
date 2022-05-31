//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IFakeNFTMarketplace.sol";
import "./ICryptoDevNFT.sol";

contract CryptoDevsDAO is Ownable{

    struct Proposal {
        // nftTokenId - the tokenID of the NFT to purchase from the FakeMarketplace if the proposal passes
        uint256 nftTokenId;
        // deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded
        uint256 deadline;
        //yayVotes - number of yay votes for this proposal
        uint256 yayVotes;
        // nayVotes - number of nay votes for this propsal
        uint256 nayVotes;
        // executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
        bool executed;
        // voters - a mapping of CryptoDevsNFT tokenIds to booleans including whether that NFT has already been used to cast a vote or not
        mapping(uint256 => bool) voters;
    }

    //Create a mapping of ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    //Number of proposal that have been created
    uint256 public numProposals;

    enum Vote {
        YAY, //YAY = 0
        NAY //NAY = 1
    }

    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevNFT cryptoDevsNFT;

    //Create a payable constructor which initializes the contract
    //with instances for FakeNFTMarketplace and CryptoDevsNFT
    //The payable allows this constructor to accept an ETH deposite when it is being deployed
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevNFT(_cryptoDevsNFT);
    }

    // Create a modifier which only allows a function to be
    // called by someone who owns at least 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposal's deadline has not be exceeded yet
    modifier activeProposalOnly(uint256 proposalIndex){
        require(proposals[proposalIndex].deadline > block.timestamp, "DEADLINE_EXCEEDED" );
        _;
    } 

    // Create a modifier which only allows a function to be
    // called if the given proposal's deadline HAS been exceeded
    // and if the proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex){
        require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
        require(proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED");
        _;
    }

    /// @dev createProposal allows a CryptoDevsNFT holder to create a new proposal in the DAO
    /// @param _nftTokenId - the tokenID of the NFT to be purchased from FakeMarketplace if this proposal process
    /// @return Returns the proposal index of the newly created proposal
    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256){
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        //Set the proposal's voting deadline to be (current time + 5 minutes)
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        return numProposals - 1;
    }

    /// @dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
    /// @param proposalIndex - the index of the proposal to vote on in the proposals array
    /// @param vote - the type of vote they want to cast
    function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex){
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        // Calculate how many NFTs are owned by the voter
        // that haven't already been used for voting on this proposal
        for(uint256 i = 0; i < voterNFTBalance; i++){
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if(proposal.voters[tokenId] == false){
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }

        require(numVotes > 0, "ALREADY_VOTED");

        if(vote == Vote.YAY){
            proposal.yayVotes += 1;
        }else{
            proposal.nayVotes += 1;
        }
    }

    /// @dev executeProposal allows any CryptoDevsNFT holder to execute proposal after its deadline has exceeded
    /// @param proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex){
        Proposal storage proposal = proposals[proposalIndex];

        if(proposal.yayVotes > proposal.nayVotes){
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }

        proposal.executed = true;
    }

    ///@dev withdrawEther allows the contract owner (deployer) to withdraw the Eth from the contract
    function withdrawEther() external onlyOwner{
        payable(owner()).transfer(address(this).balance);   
    }

    receive() external payable{}

    fallback() external payable{}
}
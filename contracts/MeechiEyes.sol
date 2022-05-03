//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";


contract MeechiEyes is ERC721, Ownable, ReentrancyGuard {
     using Counters for Counters.Counter;
     using Strings for uint256;

    Counters.Counter private tokenCounter;

    uint256 constant WL_MINT_PRICE = 0.02 ether;
    uint256 constant MINT_PRICE = 0.05 ether;

    bool public isPublicMintEnabled;
    bool public revealed;
    bool private PAUSE = true;

    uint256 constant MAX_SUPPLY = 5555;
    uint256 constant MAX_PER_WALLET = 5;
    mapping (address => uint256) public walletMints;
    bytes32 public merkleRoot;
    
    string internal baseURI;
    string internal baseURI_EXT;
    string public notRevealedUri;
  

    constructor() ERC721("MeechiEyes", "MECH") {
        
    }
  


    /**
    *@dev set isPublicMintEnabled to true or false
     */
    function setIsPublicMintEnabled(bool _isPublicMintEnabled) external onlyOwner {
        isPublicMintEnabled = _isPublicMintEnabled;
    }
    /**
    *@dev function to set MerkleRoot
     */
     function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
         merkleRoot = _merkleRoot;
     }


    /**
     *@dev functions for baseURI, baseURI_EXT, tokenURI, notRevealedUri and reveal.
     */
      function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
     function setBaseURI(string memory _baseuri) external onlyOwner {
        baseURI = _baseuri;
    }

     function _setBaseURI_EXT(string memory _extension) external onlyOwner {
        baseURI_EXT = _extension;
    }
    
    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function tokenURI(uint256 _tokenID) public view override returns (string memory) {
        require(_exists(_tokenID),"Nonexistent token");
         if(revealed == false) return notRevealedUri;

              string memory _baseURIChecker = _baseURI();
        return bytes(_baseURIChecker).length > 0 ? string( abi.encodePacked(baseURI, "/", _tokenID.toString(), ".", baseURI_EXT) ) : "";
    }
  

///@dev Functions to PAUSE contract and Reveal Collection's metadata

     function reveal() external onlyOwner {
        revealed = true;
    }
    function setPause(bool _pause) external onlyOwner {
        PAUSE = _pause;
    }


///@dev ============ PUBLIC FUNCTIONS FOR MINTING ============

    function publicMint(uint256 numberOfTokens)
        external
        payable
        saleIsOpen
        onlyEOA
        nonReentrant
        publicMintActive
        enoughMeechiesRemaining(numberOfTokens)
        maxMeechiesPerWallet(numberOfTokens)
        isCorrectPayment(MINT_PRICE, numberOfTokens)
        
    {
        uint256 numAlreadyMinted = walletMints[msg.sender];
        walletMints[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mint(msg.sender, nextTokenId());

        }
    }

    function mintforWhitelistedUsers(uint256 numberOfTokens, bytes32[] calldata _merkleProof)
        external
        payable
        saleIsOpen
        onlyEOA
        nonReentrant
        isInMeechieList(_merkleProof)
        enoughMeechiesRemaining(numberOfTokens)
        maxMeechiesPerWallet(numberOfTokens)
        isCorrectPayment(WL_MINT_PRICE, numberOfTokens)    
    {
        uint256 numAlreadyMinted = walletMints[msg.sender];
        walletMints[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mint(msg.sender, nextTokenId());
        }
    }

    //Set Some Meechies aside for admins and for marketing purposes and also to mint off remaining tokens if any to Treasury Wallet
    function AdminMintMecchie(uint256 numberOfTokens, address to)
     external
     onlyOwner
     enoughMeechiesRemaining(numberOfTokens)
      {
          for (uint256 i = 0; i < numberOfTokens; i++) {
            _mint(to, nextTokenId());
        }
    }



  ///@dev ============ SUPPORTING FUNCTIONS ============

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }
    function getLastTokenId() external view onlyOwner returns (uint256) {
        return tokenCounter.current();
    }


 /**
 *@dev Withdrawal Functions
  */
     function withdraw() external {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed");
     }

     function withdrawERC20Tokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    function withdrawERC721Tokens(IERC721 token, uint256 tokenId) public onlyOwner {
        token.safeTransferFrom(address(this), msg.sender, tokenId);
    }

      /**
        *@dev Acess Control Modifiers
         */
         modifier saleIsOpen {
        require(!PAUSE, "Sales not open");
        _;
    }
       modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }
       modifier publicMintActive() {
        require(isPublicMintEnabled, "Public sale is not open");
        _;
    }
    modifier onlyEOA() {
     require(tx.origin == msg.sender, "No contracts!");
     _;
    }

    modifier maxMeechiesPerWallet(uint256 numberOfTokens) {
        require(numberOfTokens <= MAX_PER_WALLET,"Max of 5 Meechie's per Wallet");
        require(
            walletMints[msg.sender] + numberOfTokens <= MAX_PER_WALLET,
            "Max Meechies to mint is five"
        );
        _;
    }
    modifier isInMeechieList(bytes32[] calldata _merkleProof) {
    require(
            MerkleProof.verify(
             _merkleProof,
             merkleRoot,
             keccak256(abi.encodePacked(msg.sender))
             ),
            "Lol, Not in MeechieList"
        );
        _;
    }
    modifier enoughMeechiesRemaining(uint256 numberOfTokens) {
        require(tokenCounter.current() + numberOfTokens <= MAX_SUPPLY, "Not enough Meechies remaining to mint");
        _;
    }
}
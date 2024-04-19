// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;
import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ChampzPurchase is OwnableUpgradeable {
    struct BundlePurchase {
        uint256 bundleId;
        uint256 sporeAmount;
    }

    using ECDSA for bytes32;
    address public _signer;
    address payable public paymentReceiver;
    string private _baseTokenURI;
    uint256 public MAX_SUPPLY;
    uint256 public MAX_PER_TX;
    uint public priceInPaymentToken;

    uint256 public sporePrice;

    mapping(uint256 => bool) public keyUsed;
    mapping(uint256 => bool) public lockedChamp;
    mapping(uint256 => uint256) public gameToTokenId;
    mapping(uint256 => bool) public claimedBundle;
    mapping(uint256 => uint256) public tokenToGameId;

    IERC20 public paymentToken;

    event TokenLocked(
        uint256 indexed tokenId,
        address indexed approvedContract
    );

    event TokenUnlocked(
        uint256 indexed tokenId,
        address indexed approvedContract
    );

    event TokenClaimed(
        address indexed from,
        uint256[] char_ids,
        uint256 indexed fromToken,
        uint256 indexed toToken
    );

    event PriceUpdated(uint256 newPrice);

    event SporeBundlesPurchased(
        address indexed from,
        uint256[] indexed bundleIds,
        uint256 indexed sporePrice,
        uint256 indexed sporeAmount
    );

    function initialize(
        uint256 initialSporePrice
    ) public initializerERC721A initializer {
        __ERC721A_init("Champz", "CHAMPZ");
        __Ownable_init(msg.sender);
        _signer = 0xc45079F030B88C9242624166EdcEb5B6852A377f;
        paymentReceiver = payable(0xA66EBD831df2Ebf5310DaEc4e7D885df8398b696);
        MAX_SUPPLY = 9000;
        MAX_PER_TX = 10;
        priceInPaymentToken = 30000000e18;

        sporePrice = initialSporePrice;
    }

    function updateSporePrice(uint256 newPrice) public onlyOwner {
        require(newPrice > 0, "Spore price must be greater than 0");
        sporePrice = newPrice;
        emit PriceUpdated(newPrice);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /*-----------------[MINT]---------------------------------------------------------*/
    function mint(uint256 quantity) internal {
        require(_totalMinted() + quantity <= MAX_SUPPLY, "exceed MAX_SUPPLY");
        _safeMint(msg.sender, quantity);
    }

    // Helper function to calculate total cost
    function calculateTotalCost(
        BundlePurchase[] calldata purchases
    ) public view returns (uint256) {
        uint256 totalCost = 0;
        for (uint256 i = 0; i < purchases.length; i++) {
            totalCost += purchases[i].sporeAmount * sporePrice;
        }
        return totalCost;
    }

    /*-----------------[PURCHASE]--------------------------------------------------------*/
    function purchase(
        uint256 _timestamp,
        bytes calldata _signature,
        BundlePurchase[] calldata purchases
    ) public {
        uint256 totalCost = calculateTotalCost(purchases);
        require(msg.value >= totalCost, "Not enough ETH sent");

        verifyChampzList(champz);

        for (uint i = 0; i < purchases.length; i++) {
            encodedPurchases = abi.encodePacked(
                encodedPurchases,
                purchases[i].bundleId,
                purchases[i].sporeAmount
            );
        }

        bytes32 purchasesHash = keccak256(encodedPurchases);

        verifyKeySignature(_timestamp, purchasesHash, _signature);

        paymentReceiver.transfer(totalCost);

        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        for (uint i = 0; i < purchases.length; i++) {
            claimedBundle[purchases[i].bundleId] = true;
        }

        // emit SporeBundlesPurchased(msg.sender, )
    }

    /*-----------------[MARKETPLACE FUNCTIONS]--------------------------------------------------------*/
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        require(!lockedChamp[tokenId], "Champ is locked");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public payable virtual override {
        require(!lockedChamp[tokenId], "Champ is locked");
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    /*-----------------[PLAYER FUNCTIONS]--------------------------------------------------------*/
    function lockChamp(uint256 _tokenId) public {
        require(
            ownerOf(_tokenId) == msg.sender || msg.sender == owner(),
            "Not the owner"
        );
        require(!isLocked(_tokenId), "Token already locked");
        lockedChamp[_tokenId] = true;
        emit TokenLocked(_tokenId, address(this));
    }

    function lockChampMultiple(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            lockChamp(tokenIds[i]);
        }
    }

    function unlockChamp(uint256 _tokenId) public {
        require(
            ownerOf(_tokenId) == msg.sender || msg.sender == owner(),
            "Not the owner"
        );
        require(isLocked(_tokenId), "Token not locked");
        lockedChamp[_tokenId] = false;
        emit TokenUnlocked(_tokenId, address(this));
    }

    function unlockChampMultiple(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            unlockChamp(tokenIds[i]);
        }
    }

    /*-----------------[OWNER FUNCTIONS]--------------------------------------------------------*/
    function setBaseURI(string calldata _uri) external onlyOwner {
        _baseTokenURI = _uri;
    }

    function updateSignerAddress(address _address) external onlyOwner {
        _signer = _address;
    }

    function setPaymentToken(IERC20 _paymentToken) external onlyOwner {
        paymentToken = _paymentToken;
    }

    function setPrice(uint _priceInPaymentToken) external onlyOwner {
        priceInPaymentToken = _priceInPaymentToken;
    }

    function setPaymentReceiver(address payable _address) external onlyOwner {
        paymentReceiver = _address;
    }

    function setGameIdTokenIdLink(
        uint256[] calldata _game_ids,
        uint256[] calldata _token_ids
    ) external onlyOwner {
        require(
            _game_ids.length == _token_ids.length,
            "Array lengths do not match"
        );

        for (uint256 i = 0; i < _game_ids.length; i++) {
            gameToTokenId[_game_ids[i]] = _token_ids[i];
            tokenToGameId[_token_ids[i]] = _game_ids[i];
        }
    }

    /*-----------------[HELPER]-----------------------------------------------------------------*/
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function signer() external view returns (address) {
        return _signer;
    }

    function isLocked(uint256 _tokenId) public view returns (bool) {
        return lockedChamp[_tokenId];
    }

    function getGameToTokenId(uint256 _game_id) public view returns (uint256) {
        return gameToTokenId[_game_id];
    }

    function getTokenToGameId(uint256 _token_id) public view returns (uint256) {
        return tokenToGameId[_token_id];
    }

    function getLockedToken() public view returns (uint256[] memory) {
        uint256 _totalSupply = totalSupply();
        uint256[] memory lockedKeys = new uint256[](_totalSupply);
        uint256 count = 0;

        for (uint256 i = 1; i <= _totalSupply; i++) {
            if (lockedChamp[i]) {
                lockedKeys[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = lockedKeys[i];
        }

        return result;
    }

    function verifyKeySignature(
        uint256 _timestamp,
        bytes32 _champz,
        bytes calldata _signature
    ) private view {
        require(msg.sender == tx.origin, "Only Shrooman beings!");
        require(
            keccak256(
                abi.encodePacked(
                    "Claim",
                    msg.sender,
                    "Timestamp",
                    _timestamp,
                    "Champz",
                    _champz
                )
            ).toEthSignedMessageHash().recover(_signature) == _signer,
            "Invalid signature"
        );
    }

    function verifyChampzList(uint256[] calldata champz) internal view {
        require(champz.length <= MAX_PER_TX, "exceed MAX_PER_TX");
        for (uint256 i = 0; i < champz.length; i++) {
            require(!claimedBundle[champz[i]], "Champ has been claimed");
        }
    }
}

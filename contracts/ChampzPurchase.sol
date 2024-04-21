// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ChampzPurchase is OwnableUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public _signer;
    address payable public paymentReceiver;

    uint256 public MAX_PER_TX;

    uint256 public sporePrice;

    mapping(uint256 => bool) public claimedBundle;

    event PriceUpdated(uint256 newPrice);

    event SporeBundlesPurchased(
        address indexed from,
        uint256[] bundleIds,
        uint256[] sporeAmounts,
        uint256 indexed sporePrice
    );

    function initialize(uint256 initialSporePrice) public initializer {
        __Ownable_init(msg.sender);
        _signer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        paymentReceiver = payable(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        MAX_PER_TX = 10;

        sporePrice = initialSporePrice;
    }

    function updateSporePrice(uint256 newPrice) public onlyOwner {
        require(newPrice > 0, "Spore price must be greater than 0");
        sporePrice = newPrice;
        emit PriceUpdated(newPrice);
    }

    // Helper function to calculate total cost
    function calculateTotalCost(
        uint256[] calldata sporeAmounts
    ) public view returns (uint256) {
        uint256 totalCost = 0;
        for (uint256 i = 0; i < sporeAmounts.length; i++) {
            totalCost += sporeAmounts[i] * sporePrice;
        }
        return totalCost;
    }

    /*-----------------[PURCHASE]--------------------------------------------------------*/
    function purchase(
        uint256 _timestamp,
        bytes calldata _signature,
        uint256[] calldata bundleIds,
        uint256[] calldata sporeAmounts
    ) public payable {
        require(
            sporeAmounts.length == bundleIds.length,
            "Count of Bundles doesn't match with count of their amounts"
        );
        uint256 totalCost = calculateTotalCost(sporeAmounts);
        require(msg.value >= totalCost, "Not enough ETH sent");

        verifyBundleList(bundleIds);

        bytes32 purchasesHash = keccak256(
            abi.encodePacked(bundleIds, sporeAmounts)
        );

        verifyKeySignature(_timestamp, purchasesHash, _signature);

        paymentReceiver.transfer(totalCost);

        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        for (uint i = 0; i < bundleIds.length; i++) {
            claimedBundle[bundleIds[i]] = true;
        }

        emit SporeBundlesPurchased(
            msg.sender,
            bundleIds,
            sporeAmounts,
            sporePrice
        );
    }

    /*-----------------[OWNER FUNCTIONS]--------------------------------------------------------*/

    function updateSignerAddress(address _address) external onlyOwner {
        _signer = _address;
    }

    function setPaymentReceiver(address payable _address) external onlyOwner {
        paymentReceiver = _address;
    }

    /*-----------------[HELPER]-----------------------------------------------------------------*/

    function signer() external view returns (address) {
        return _signer;
    }

    function verifyKeySignature(
        uint256 _timestamp,
        bytes32 _champz,
        bytes calldata _signature
    ) private view {
        require(msg.sender == tx.origin, "Only Shrooman beings!");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "Purchase",
                msg.sender,
                "Timestamp",
                _timestamp,
                "Champz",
                _champz
            )
        );

        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        require(
            ethSignedMessageHash.recover(_signature) == _signer,
            "Invalid signature"
        );
    }

    function verifyBundleList(uint256[] calldata bundleIds) internal view {
        require(bundleIds.length <= MAX_PER_TX, "exceed MAX_PER_TX");
        for (uint256 i = 0; i < bundleIds.length; i++) {
            require(!claimedBundle[bundleIds[i]], "Bundle has been claimed");
        }
    }
}

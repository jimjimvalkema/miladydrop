// SPDX-License-Identifier: TBD
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMiladyDrop} from "./interfaces/IMiladyDrop.sol";

error AlreadyClaimed();
error InvalidProof();

contract MiladyDrop is IMiladyDrop {
    using SafeERC20 for IERC20;

    address public requiredNFTAddress;
    address public airdropTokenAddress;

    uint256 airdropAmount;
    mapping(uint256 => bool) public claimedIds; //TODO tight packing and getter

    //bytes32 public immutable override merkleRoot;
    bytes32 public immutable merkleRoot;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;
    


    constructor(address _requiredNFTAddress, address _airdropTokenAddress, uint256 _amount, bytes32 _merkleRoot) {
        airdropAmount = _amount;
        merkleRoot = _merkleRoot;

        //store addresses for easier acces
        requiredNFTAddress = _requiredNFTAddress;
        airdropTokenAddress = _airdropTokenAddress;
        }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    //TODO remove and make claim function that claim multiple merkle proofs
    function claim(uint256[] memory _ids) public {
        uint256 currentId;
        for (uint i=0; i < _ids.length; i++) {
            currentId = _ids[i];
            require(IERC721(requiredNFTAddress).ownerOf(currentId) == msg.sender, "you dont own one or more of these nfts"); //msg.esender bad?
            require(claimedIds[currentId] == false, "one or more of these ids is already claimed");
            claimedIds[currentId] = true;
            IERC20(airdropTokenAddress).transfer(address(msg.sender), airdropAmount);
        }
    }

    function claim(uint256 index, uint256 id, uint256 amount, bytes32[] calldata merkleProof)
        public
        virtual
        override
    {
        if (isClaimed(index)) revert AlreadyClaimed();
        require(IERC721(requiredNFTAddress).ownerOf(id) == msg.sender, "you dont own one or more of these nfts"); //msg.esender bad?

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, id, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

        // Mark it claimed and send the token.
        _setClaimed(index);
        //IERC20(airdropTokenAddress).safeTransfer(account, amount);
        IERC20(airdropTokenAddress).transfer(address(msg.sender), amount);

        emit Claimed(index, id, amount);
    }
}
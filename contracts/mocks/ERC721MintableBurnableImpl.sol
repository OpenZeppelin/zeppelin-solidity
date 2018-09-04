pragma solidity ^0.4.24;

import "../token/ERC721/ERC721.sol";
import "../token/ERC721/ERC721Mintable.sol";
import "../token/ERC721/ERC721Burnable.sol";


/**
 * @title ERC721MintableBurnableImpl
 */
contract ERC721MintableBurnableImpl is ERC721, ERC721Mintable, ERC721Burnable {
  constructor(address[] _minters)
    ERC721Mintable(_minters)
    ERC721("Test", "TEST")
    public
  {
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import './IEtherealBase.sol';


/**
 * @dev {ERC721} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - token ID and URI autogeneration
 *  - includes extra properties to store important metadata
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract EtherealCharacter is Context, AccessControl, ERC721Burnable, ERC721Pausable, IEtherealBase {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdTracker;
    using SafeMath for uint256;

   
    /**
    * @dev Character extra metadata tables
    */
    mapping(uint256 => CharacterBaseMetadata) public characterBaseMetadata;
    mapping(uint256 => CharacterPhysicalMetadata) public characterPhysicalMetadata;
    mapping(uint256 => CharacterAttributesMetadata) public characterAttributesMetadata;
    mapping(bytes32 => bool) public characterNameExists;
    
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event NewBaseURI(string _baseURI);

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        _setBaseURI(baseURI);
    }

    
    /**
     * @dev External function to set the base URI for all token IDs. 
     */
    function setBaseURI(string memory _baseURI) external {
      require(
        hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
        "EtherealCharacter: must have admin role to setBaseURI"
      );
      _setBaseURI(_baseURI);
      emit NewBaseURI(_baseURI);
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
      address to,
      CharacterBaseMetadata memory extraBaseMetaData,
      CharacterPhysicalMetadata memory extraPhysicalMetaData,
      CharacterAttributesMetadata memory extraAbilitiesMetaData
    )
        public
        returns (uint256)
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "EtherealCharacter: must have minter role to mint");
        require(
          keccak256(abi.encode(extraBaseMetaData.name)) != keccak256(abi.encode("")) &&
          keccak256(abi.encode(extraBaseMetaData.name)) != keccak256(abi.encode(0x00)),
          "EtherealCharacter: character name should not be empty"
        );
        require(
          !characterNameExists[extraBaseMetaData.name],
          "EtherealCharacter: name already taken by another user :) Choose another one!"
        );

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        uint256 currentTokenId = _tokenIdTracker.current();
        _safeMint(to, currentTokenId);
        _tokenIdTracker.increment();
        characterNameExists[extraBaseMetaData.name] = true;
        characterBaseMetadata[currentTokenId] = extraBaseMetaData;
        characterPhysicalMetadata[currentTokenId] = extraPhysicalMetaData;
        characterAttributesMetadata[currentTokenId] = extraAbilitiesMetaData;
        return currentTokenId;
    }

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
        bytes32 tmpChrName = characterBaseMetadata[tokenId].name;
        delete characterNameExists[tmpChrName];
        delete characterBaseMetadata[tokenId];
        delete characterAttributesMetadata[tokenId];
        delete characterPhysicalMetadata[tokenId];
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC721Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
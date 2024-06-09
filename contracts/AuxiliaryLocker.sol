// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
import './interfaces/IVotingEscrow.sol';
import './interfaces/IPermissionsRegistry.sol';
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract AuxiliaryLocker is OwnableUpgradeable, ReentrancyGuardUpgradeable {

  struct LockData {
    uint256 value;
    uint256 lockDuration;
    uint256 lastLockedAt;
  }

  address public _ve;                                         // the ve token that governs these contracts
  address public permissionRegistry;                          // registry to check accesses

  mapping(uint256 => LockData) tokenLocks;

  uint256[] tokenLockIds;

  constructor(address __ve) {
    permissionRegistry = msg.sender;
    _ve = __ve;
  }

  /* -----------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
                                  MODIFIERS
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  ----------------------------------------------------------------------------- */

  modifier Admin() {
      require(IPermissionsRegistry(permissionRegistry).hasRole("VOTER_ADMIN",msg.sender), 'VOTER_ADMIN');
      _;
  }


  /* -----------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
                                  Admin
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  ----------------------------------------------------------------------------- */

  function renewLocks(uint256[] memory tokens) external Admin {
    require(tokens.length <= tokenLockIds.length);
    for(uint256 i = 0; i < tokens.length; i++) {
      IVotingEscrow(_ve).create_lock_for(tokenLocks[tokens[i]].value, tokenLocks[tokens[i]].lockDuration, IVotingEscrow(_ve).ownerOf(tokens[i]));
    }
  }

  function changeAdmin(address _newPermissionRegistry) external Admin {
    permissionRegistry = _newPermissionRegistry;
  }

  function changeVestingContract(address __ve) external Admin {
    _ve = __ve;
  }

  /* -----------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
                                  USER INTERACTION
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  ----------------------------------------------------------------------------- */

  function addScheduledLock(uint256 _tokenId, uint256 _value, uint256 _lock_duration) external nonReentrant {
    //the contract must have approval to lock again the token in the name of 
    require(IVotingEscrow(_ve).isApprovedOrOwner(address(this), _tokenId), "!ao");
    //the request maker must be owner of the token
    require(IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "!ao");
    //if the token already has a scheduled lock do not approve a new one
    require(_hasLock(_tokenId) == false);
    tokenLockIds.push(_tokenId);
    tokenLocks[_tokenId].lastLockedAt = block.timestamp;
    tokenLocks[_tokenId].lockDuration = _lock_duration;
    tokenLocks[_tokenId].value = _value;
    //not sure about this, maybe it's better to create 1 more transaction
    IVotingEscrow(_ve).create_lock_for(tokenLocks[_tokenId].value, tokenLocks[_tokenId].lockDuration, msg.sender);
  }

  function removeScheduledLock(uint256 _tokenId) external nonReentrant {
    require(IVotingEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "!ao");
    require(_hasLock(_tokenId));

    uint256 index = 0;
    for(uint256 i = 0; i < tokenLockIds.length; i++) {
      if(tokenLockIds[i] == _tokenId){
          index = i;
      }
    }
    uint256 aux = tokenLockIds[tokenLockIds.length-1];
    tokenLockIds[tokenLockIds.length-1] = tokenLockIds[index];
    tokenLockIds[index] = aux;
    tokenLockIds.pop();
    delete tokenLocks[_tokenId];
  }

  function _hasLock(uint256 tokenId) internal view returns(bool) {
    for (uint256 i = 0; i < tokenLockIds.length; i++) {
      if(tokenLockIds[i] == tokenId) {
        return true;
      }
    }
    return false;
  }

  /* -----------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
                                  VIEW FUNCTIONS
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  ----------------------------------------------------------------------------- */

  function getLocksCount() external view returns(uint256) {
    return tokenLockIds.length;
  }

  function tokenHasLock(uint256 _tokenId) external view returns(bool) {
    return _hasLock(_tokenId);
  }

  function tokenLockData(uint256 _tokenId) external view returns(LockData memory) {
    return tokenLocks[_tokenId];
  }

  function getTokensToRelock() external view returns(uint256[] memory) {
    uint256 arrLengthToInit = 0;
    for (uint256 i = 0; i < tokenLockIds.length; i++) {
      if(tokenLocks[tokenLockIds[i]].lastLockedAt + tokenLocks[tokenLockIds[i]].lockDuration > block.timestamp) {
        arrLengthToInit++;
      }
    }
    uint256[] memory tokensToReturn = new uint256[](arrLengthToInit);
    uint256 currentIndex = 0;

    for (uint256 i = 0; i < tokenLockIds.length; i++) {
      if(tokenLocks[tokenLockIds[i]].lastLockedAt + tokenLocks[tokenLockIds[i]].lockDuration > block.timestamp) {
        tokensToReturn[currentIndex] = i;
        currentIndex++;
      }
    }
    return tokensToReturn;
  }

}
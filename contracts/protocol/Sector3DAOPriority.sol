// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IPriority.sol";
import "./Structs.sol";

contract Sector3DAOPriority is IPriority {
  using SafeERC20 for IERC20;

  address public immutable dao;
  string public title;
  IERC20 public immutable rewardToken;
  uint256 public immutable startTime;
  uint16 public immutable epochDuration;
  uint256 public immutable epochBudget;
  IERC721 public immutable gatingNFT;
  Contribution[] contributions;
  mapping(uint16 => mapping(address => bool)) claims;
  uint256 public claimsBalance;

  event ContributionAdded(Contribution contribution);
  event RewardClaimed(uint16 epochNumber, address contributor, uint256 amount);

  error EpochNotYetEnded();
  error EpochNotYetFunded();
  error NoRewardForEpoch();
  error RewardAlreadyClaimed();
  error NoGatingNFTOwnership();

  constructor(address dao_, string memory title_, address rewardToken_, uint16 epochDurationInDays, uint256 epochBudget_, address gatingNFT_) {
    dao = dao_;
    title = title_;
    rewardToken = IERC20(rewardToken_);
    startTime = block.timestamp;
    epochDuration = epochDurationInDays;
    epochBudget = epochBudget_;
    gatingNFT = IERC721(gatingNFT_);
  }

  /**
   * @notice Calculates the current epoch number based on the priority's start time and epoch duration.
   * @return [1,2,3,...]
   */
  function getEpochNumber() public view returns (uint16) {
    uint256 timePassedSinceStart = block.timestamp - startTime;
    uint256 epochDurationInSeconds = epochDuration * 1 days;
    return uint16(timePassedSinceStart / epochDurationInSeconds) + 1;
  }

  /**
   * @notice Adds a contribution to the current epoch.
   */
  function addContribution(string memory description, string memory proofURL, uint8 hoursSpent, uint8 alignmentPercentage) public {
    if (address(gatingNFT) != address(0x0)) {
      if (gatingNFT.balanceOf(msg.sender) == 0) {
        revert NoGatingNFTOwnership();
      }
    }
    Contribution memory contribution = Contribution({
      timestamp: block.timestamp,
      epochNumber: getEpochNumber(),
      contributor: msg.sender,
      description: description,
      proofURL: proofURL,
      hoursSpent: hoursSpent,
      alignmentPercentage: alignmentPercentage
    });
    contributions.push(contribution);
    emit ContributionAdded(contribution);
  }

  function getContributions() public view returns (Contribution[] memory) {
    return contributions;
  }

  function getEpochContributions(uint16 epochNumber) public view returns (Contribution[] memory) {
    uint16 count = 0;
    for (uint16 i = 0; i < contributions.length; i++) {
      if (contributions[i].epochNumber == epochNumber) {
        count++;
      }
    }
    Contribution[] memory epochContributions = new Contribution[](count);
    count = 0;
    for (uint16 i = 0; i < contributions.length; i++) {
      if (contributions[i].epochNumber == epochNumber) {
        epochContributions[count] = contributions[i];
        count++;
      }
    }
    return epochContributions;
  }

  /**
   * @notice Claims a contributor's reward for contributions made in a given epoch.
   * @dev Claims can only be made for an epoch that has ended.
   */
  function claimReward(uint16 epochNumber) public {
    if (epochNumber >= getEpochNumber()) {
      revert EpochNotYetEnded();
    }
    uint256 epochReward = getEpochReward(epochNumber, msg.sender);
    if (epochReward == 0) {
      revert NoRewardForEpoch();
    }
    bool epochFunded = isEpochFunded(epochNumber);
    if (!epochFunded) {
      revert EpochNotYetFunded();
    }
    bool rewardClaimed = isRewardClaimed(epochNumber, msg.sender);
    if (rewardClaimed) {
      revert RewardAlreadyClaimed();
    }
    rewardToken.transfer(msg.sender, epochReward);
    claims[epochNumber][msg.sender] = true;
    claimsBalance += epochReward;
    emit RewardClaimed(epochNumber, msg.sender, epochReward);
  }

  /**
   * @notice Calculates a contributor's token allocation of the budget for a given epoch.
   */
  function getEpochReward(uint16 epochNumber, address contributor) public view returns (uint256) {
    uint8 allocationPercentage = getAllocationPercentage(epochNumber, contributor);
    return epochBudget * allocationPercentage / 100;
  }

  /**
   * @notice Checks if a contributor's reward has been claimed for a given epoch.
   */
  function isRewardClaimed(uint16 epochNumber, address contributor) public view returns (bool) {
    return claims[epochNumber][contributor];
  }

  /**
   * @notice Calculates a contributor's percentage allocation of the budget for a given epoch.
   */
  function getAllocationPercentage(uint16 epochNumber, address contributor) public view returns (uint8) {
    uint16 hoursSpentContributor = 0;
    uint16 hoursSpentAllContributors = 0;
    for (uint16 i = 0; i < contributions.length; i++) {
      Contribution memory contribution = contributions[i];
      if (contribution.epochNumber == epochNumber) {
        if (contribution.contributor == contributor) {
          hoursSpentContributor += contribution.hoursSpent;
        }
        hoursSpentAllContributors += contribution.hoursSpent;
      }
    }
    if (hoursSpentAllContributors == 0) {
      return 0;
    } else {
      return uint8(hoursSpentContributor * 100 / hoursSpentAllContributors);
    }
  }

  /**
   * @notice Checks if the smart contract has received enough funding to cover claims for a past epoch.
   * @dev Epochs without contributions are excluded from funding.
   */
  function isEpochFunded(uint16 epochNumber) public view returns (bool) {
    if (epochNumber >= getEpochNumber()) {
      revert EpochNotYetEnded();
    }
    if (getEpochContributions(epochNumber).length == 0) {
      return false;
    }
    uint16 numberOfEpochsWithContributions = 0;
    for (uint16 i = 0; i <= epochNumber; i++) {
      if (getEpochContributions(i).length > 0) {
        numberOfEpochsWithContributions++;
      }
    }
    if (numberOfEpochsWithContributions == 0) {
      return false;
    } else {
      uint256 totalBudget = epochBudget * numberOfEpochsWithContributions;
      uint256 totalFundingReceived = rewardToken.balanceOf(address(this)) + claimsBalance;
      return totalFundingReceived >= totalBudget;
    }
  }
}

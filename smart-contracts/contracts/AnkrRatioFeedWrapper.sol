// SPDX-License-Identifier: GNU General Public License v3.0 (GNU GPLv3)
pragma solidity ^0.8.0;

import {IInternetBondRatioFeed} from "./interfaces/oracle/IInternetBondRatioFeed.sol";
import {AggregatorV2V3Interface} from "./interfaces/oracle/AggregatorV2V3Interface.sol";

/**
 * @title A port of the ChainlinkAggregatorV3 interface that supports Pyth price feeds
 * @notice This does not store any roundId information on-chain. Please review the code before using this implementation.
 * Users should deploy an instance of this contract to wrap every price feed id that they need to use.
 */
contract AnkrRatioFeedWrapper is AggregatorV2V3Interface {
    IInternetBondRatioFeed public ankrRatioFeed;
    address public ankrFlow;

    constructor(address _ankrRatioFeed, address _ankrFlow) {
        ankrRatioFeed = IInternetBondRatioFeed(_ankrRatioFeed);
        ankrFlow = _ankrFlow;
    }

    function decimals() public view virtual returns (uint8) {
        return uint8(18);
    }

    function description() public pure returns (string memory) {
        return
            "A simple wrapper of AnkrRatioFeed SC to support Chainlink's aggregator interface.";
    }

    function version() public pure returns (uint256) {
        return 1;
    }

    function latestAnswer() public view virtual returns (int256) {
        int256 answer = int256(ankrRatioFeed.getRatioFor(ankrFlow));
        return answer;
    }

    function latestTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function latestRound() public view returns (uint256) {
        return latestTimestamp();
    }

    function getAnswer(uint256) public view returns (int256) {
        return latestAnswer();
    }

    function getTimestamp(uint256) external view returns (uint256) {
        return latestTimestamp();
    }

    function getRoundData(
        uint80 _roundId
    ) external view returns (uint80, int256, uint256, uint256, uint80) {
        int256 answer = int256(ankrRatioFeed.getRatioFor(ankrFlow));
        return (
            _roundId,
            answer,
            latestTimestamp(),
            latestTimestamp(),
            _roundId
        );
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        int256 answer = int256(ankrRatioFeed.getRatioFor(ankrFlow));
        return (
            uint80(latestTimestamp()),
            answer,
            latestTimestamp(),
            latestTimestamp(),
            uint80(latestTimestamp())
        );
    }
}

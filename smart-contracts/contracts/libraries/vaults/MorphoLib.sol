// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IMoreMarkets, Id} from "../../interfaces/IMoreMarkets.sol";
import {MorphoStorageLib} from "./MorphoStorageLib.sol";

/// @title MorphoLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Helper library to access Morpho storage variables.
/// @dev Warning: Supply and borrow getters may return outdated values that do not include accrued interest.
library MorphoLib {
    function supplyShares(
        IMoreMarkets moreMarkets,
        Id id,
        address user
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.positionSupplySharesAndBorrowSharesSlot(id, user)
        );
        return uint128(uint256(moreMarkets.extSloads(slot)[0]));
    }

    function borrowShares(
        IMoreMarkets moreMarkets,
        Id id,
        address user
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.positionSupplySharesAndBorrowSharesSlot(id, user)
        );
        return uint256(moreMarkets.extSloads(slot)[0] >> 128);
    }

    function collateral(
        IMoreMarkets moreMarkets,
        Id id,
        address user
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.positionCollateralAndLastMultiplierSlot(id, user)
        );
        return uint128(uint256(moreMarkets.extSloads(slot)[0]));
    }

    function lastMultiplier(
        IMoreMarkets moreMarkets,
        Id id,
        address user
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.positionCollateralAndLastMultiplierSlot(id, user)
        );
        return uint256(moreMarkets.extSloads(slot)[0] >> 128);
    }

    function totalSupplyAssets(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id)
        );
        return uint128(uint256(moreMarkets.extSloads(slot)[0]));
    }

    function totalSupplyShares(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id)
        );
        return uint256(moreMarkets.extSloads(slot)[0] >> 128);
    }

    function totalBorrowAssets(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id)
        );
        return uint128(uint256(moreMarkets.extSloads(slot)[0]));
    }

    function totalBorrowShares(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id)
        );
        return uint256(moreMarkets.extSloads(slot)[0] >> 128);
    }

    function lastUpdate(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketLastUpdateAndFeeSlot(id)
        );
        return uint128(uint256(moreMarkets.extSloads(slot)[0]));
    }

    function fee(
        IMoreMarkets moreMarkets,
        Id id
    ) internal view returns (uint256) {
        bytes32[] memory slot = _array(
            MorphoStorageLib.marketLastUpdateAndFeeSlot(id)
        );
        return uint256(moreMarkets.extSloads(slot)[0] >> 128);
    }

    function _array(bytes32 x) private pure returns (bytes32[] memory) {
        bytes32[] memory res = new bytes32[](1);
        res[0] = x;
        return res;
    }
}

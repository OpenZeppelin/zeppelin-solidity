pragma solidity ^0.5.0;

/**
 * @title Strings
 * @dev String operations.
 * via https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol MIT licence
 */
library Strings {
    /**
     * @dev Concatenates two strings.
     */
    function concatenate(string memory a, string memory b) public pure returns (string memory) {
        bytes memory bytesA = bytes(a);
        bytes memory bytesB = bytes(b);
        string memory concatenatedAB = new string(bytesA.length + bytesB.length);
        bytes memory bytesAB = bytes(concatenatedAB);
        uint concatendatedIndex = 0;
        uint index = 0;
        for (index = 0; index < bytesA.length; index++) {
            bytesAB[concatendatedIndex++] = bytesA[index];
        }
        for (index = 0; index < bytesB.length; index++) {
            bytesAB[concatendatedIndex++] = bytesB[index];
        }

        return string(bytesAB);
    }

    /**
     * @dev Converts a uint to a string.
     */
    function uintToString(uint256 value) public pure returns (string memory uintAsString) {
        uint tempValue = value;

        if (tempValue == 0) {
            return "0";
        }
        uint j = tempValue;
        uint length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory byteString = new bytes(length);
        uint index = length - 1;
        while (tempValue != 0) {
            byteString[index--] = byte(uint8(48 + tempValue % 10));
            tempValue /= 10;
        }
        return string(byteString);
    }
}

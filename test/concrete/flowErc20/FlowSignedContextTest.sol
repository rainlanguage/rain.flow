// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";

contract FlowSignedContextTest is FlowERC20Test {
    function testFlowERC20ValidateMultipleSignedContexts(
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        absTestFlowValidateMultipleSignedContexts(context0, context1, fuzzedKeyAlice, fuzzedKeyBob);
    }

    /// Should validate a signed context
    function testFlowERC20ValidateSignedContexts(
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        absTestFlowERC20ValidateSignedContexts(context0, fuzzedKeyAlice, fuzzedKeyBob);
    }
}

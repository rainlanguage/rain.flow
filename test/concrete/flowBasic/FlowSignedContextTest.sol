// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {AbstractFlowSignedContextTest} from "test/abstract/flow/AbstractFlowSignedContextTest.sol";

contract FlowSignedContextTest is AbstractFlowSignedContextTest {
    function testFlowBasicValidateMultipleSignedContexts(
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        absTestFlowValidateMultipleSignedContexts(context0, context1, fuzzedKeyAlice, fuzzedKeyBob);
    }

    /// Should validate a signed context
    function testFlowBasicValidateSignedContexts(
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        absTestFlowERC20ValidateSignedContexts(context0, fuzzedKeyAlice, fuzzedKeyBob);
    }
}

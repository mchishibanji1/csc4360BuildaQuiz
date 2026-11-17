/// T09: let the transaction COMMIT, then hide its acknowledgement.
const bool kInjectLostAck = false;

/// T12: simulate backend failures without spending money.
enum InjectCloudFault { none, unavailable, resourceExhausted }

const InjectCloudFault kInjectCloudFault = InjectCloudFault.none;

/// T03: simulate malformed API responses.
enum InjectTriviaFault { none, badJson, nonZeroCode, nineResults }

const InjectTriviaFault kInjectTriviaFault = InjectTriviaFault.none;

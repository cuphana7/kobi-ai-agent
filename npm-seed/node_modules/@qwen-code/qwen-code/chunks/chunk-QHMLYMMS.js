// Force strict mode and setup for ESM
"use strict";
import {
  init_esbuild_shims
} from "./chunk-5O2XNYP6.js";
import {
  __name
} from "./chunk-J2S4EL5Y.js";

// packages/core/src/core/stream-transport-retry.ts
init_esbuild_shims();
var RETRYABLE_STREAM_TRANSPORT_CODES = /* @__PURE__ */ new Set([
  "ECONNRESET",
  "ETIMEDOUT",
  "UND_ERR_BODY_TIMEOUT",
  "UND_ERR_CONNECT_TIMEOUT",
  "UND_ERR_HEADERS_TIMEOUT",
  "UND_ERR_SOCKET"
]);
function isRetryableStreamTransportError(classification) {
  return classification.kind === "transport" && classification.transportCode !== void 0 && RETRYABLE_STREAM_TRANSPORT_CODES.has(classification.transportCode);
}
__name(isRetryableStreamTransportError, "isRetryableStreamTransportError");

export {
  isRetryableStreamTransportError
};
/**
 * @license
 * Copyright 2026 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

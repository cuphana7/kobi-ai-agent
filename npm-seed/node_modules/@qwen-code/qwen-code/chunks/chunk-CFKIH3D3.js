// Force strict mode and setup for ESM
"use strict";
import {
  init_esbuild_shims
} from "./chunk-5O2XNYP6.js";
import {
  __name
} from "./chunk-J2S4EL5Y.js";

// packages/core/src/core/tool-call-preparation.ts
init_esbuild_shims();
var preparationsByResponse = /* @__PURE__ */ new WeakMap();
function setToolCallPreparations(response, preparations) {
  preparationsByResponse.set(response, preparations);
}
__name(setToolCallPreparations, "setToolCallPreparations");
function getToolCallPreparations(response) {
  return preparationsByResponse.get(response) ?? [];
}
__name(getToolCallPreparations, "getToolCallPreparations");

// packages/core/src/core/invalid-stream-error.ts
init_esbuild_shims();
var InvalidStreamError = class extends Error {
  static {
    __name(this, "InvalidStreamError");
  }
  type;
  constructor(message, type) {
    super(message);
    this.name = "InvalidStreamError";
    this.type = type;
  }
};

export {
  setToolCallPreparations,
  getToolCallPreparations,
  InvalidStreamError
};
/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */
/**
 * @license
 * Copyright 2025 Qwen
 * SPDX-License-Identifier: Apache-2.0
 */

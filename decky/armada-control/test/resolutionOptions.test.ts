import assert from "node:assert/strict";
import test from "node:test";

import { resolutionOptions } from "../src/lib/resolutionOptions.ts";

test("Joyeuse gets 20:9, 16:9, and 4:3 game resolution options", () => {
  assert.deepEqual(
    resolutionOptions("xiaomi-joyeuse").map((option) => option.data),
    [
      "Default", "Native", "2400x1080", "1600x720", "1200x540", "800x360",
      "1920x1080", "1280x720", "960x540", "640x360",
      "1440x1080", "960x720", "720x540", "480x360",
    ],
  );
});

test("other devices keep the standard resolution options", () => {
  assert.deepEqual(
    resolutionOptions("ayn-odin-2").map((option) => option.data),
    ["Default", "Native", "1280x720", "960x540"],
  );
});

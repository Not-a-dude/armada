import type { DropdownChoice } from "../types";

const baseOptions: DropdownChoice[] = [
  { data: "Default", label: "Default" },
  { data: "Native", label: "Native" },
];

const standardOptions: DropdownChoice[] = [
  ...baseOptions,
  { data: "1280x720", label: "1280x720 (16:9)" },
  { data: "960x540", label: "960x540 (16:9)" },
];

const joyeuseOptions: DropdownChoice[] = [
  ...baseOptions,
  { data: "2400x1080", label: "2400x1080 (20:9, 1080p)" },
  { data: "1600x720", label: "1600x720 (20:9, 720p)" },
  { data: "1200x540", label: "1200x540 (20:9, 540p)" },
  { data: "800x360", label: "800x360 (20:9, 360p)" },
  { data: "1920x1080", label: "1920x1080 (16:9, 1080p)" },
  { data: "1280x720", label: "1280x720 (16:9, 720p)" },
  { data: "960x540", label: "960x540 (16:9, 540p)" },
  { data: "640x360", label: "640x360 (16:9, 360p)" },
  { data: "1440x1080", label: "1440x1080 (4:3, 1080p)" },
  { data: "960x720", label: "960x720 (4:3, 720p)" },
  { data: "720x540", label: "720x540 (4:3, 540p)" },
  { data: "480x360", label: "480x360 (4:3, 360p)" },
];

export function resolutionOptions(deviceId: string): DropdownChoice[] {
  return deviceId === "xiaomi-joyeuse"
    ? joyeuseOptions
    : standardOptions;
}

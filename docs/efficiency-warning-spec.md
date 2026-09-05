# Efficiency warning

## Goal

Gently point out when the laptop is using a clearly wasteful configuration on
battery while the current workload is light, and offer one straightforward way
to correct it.

The motivating case is browsing or watching video with Performance mode,
dGPU-direct graphics, 240 Hz, and aggressive fan settings enabled while the
battery is low.

## Experience

After the qualifying state has lasted five minutes:

- Add a small amber indicator to the existing bar icon. Do not flash, animate,
  or show a desktop notification.
- Show a compact banner on the Main tab, below the temperature tiles and above
  the profile/fan controls.
- Use calm copy such as: **High-power settings during light use.**
- Give the banner one primary action: **Switch to Efficiency**.

The banner should look native to the existing Omarchy panel: the same spacing,
corners, typography, and muted semantic colours as the rest of the plugin. It
must not be a modal and must not take over the panel.

The indicator and banner disappear automatically when the laptop is plugged
in, meaningful work resumes, the battery is no longer low, or the expensive
settings are no longer active. There is no escalating notification or repeated
prompt.

## Trigger

Show the warning only when all three groups below are true.

### On battery and low

- The laptop is discharging.
- Battery is at or below 30%.

### Sustained light workload

For five minutes, use a rolling average of passive readings:

- CPU utilization below 20%.
- dGPU utilization below 15% when available.
- dGPU power below 15 W when available.

Unavailable sensors must not make a high-power configuration look busy. CPU
utilization should come from `/proc/stat`; GPU readings should keep using the
existing passive sysfs approach and must never poll `nvidia-smi`.

Short activity spikes should not restart the timer. Clear the light-workload
state promptly when utilization remains above a threshold for 30 seconds.

### Monitoring cost and self-interference

Do not add a daemon, a second polling timer, or a process scan. Extend the
existing sensor command with one read of the aggregate CPU counters in
`/proc/stat`. Calculate CPU utilization from the delta between consecutive
samples in QML. GPU, battery, and fan data continue to come from the same
existing sysfs pass.

When the panel is closed, reuse its existing 20-second sensor interval. The
two-second interval while the panel is open may update the UI, but warning
eligibility must be accumulated by elapsed wall time rather than by counting
samples. Opening the panel therefore cannot make the five-minute warning arrive
faster.

The probe's own CPU time is naturally included in the following `/proc/stat`
delta. This biases the detector toward considering the machine busier and
suppressing the warning, rather than falsely declaring the machine idle. Do not
subtract or special-case the plugin's own work.

Before merge, compare the feature disabled and enabled with the panel closed
for at least ten minutes on an otherwise idle machine. The feature must:

- Create no additional periodic process beyond the existing sensor command.
- Add no new wake-up cadence beyond the existing 20-second interval.
- Keep incremental `omarchy-shell` CPU below 0.1% of one core on average.
- Add less than 2 ms to the sensor command's mean wall time and no more than
  5 ms to its 95th percentile compared with the feature-disabled baseline.
- Leave the dGPU runtime-suspended when it was already suspended.

### Clearly expensive configuration

Treat the configuration as expensive when dGPU-direct mode is active together
with any one of the following:

- Performance power profile.
- Built-in display refresh above 60 Hz.
- An enabled custom fan curve for the active profile.

Also treat Performance + refresh above 60 Hz + an enabled custom fan curve as
expensive when the machine is not in dGPU-direct mode. A high refresh rate by
itself must never trigger the warning.

Use current hardware state for the warning. A GPU-mode change that is merely
queued for the next boot should be explained in the banner, not treated as if
it has already happened.

## Switch to Efficiency

The button applies the following best-effort preset:

1. Set the power profile to Quiet.
2. Set the built-in display to 60 Hz, preserving the existing hyprmoncfg save
   behavior when a monitor profile is managed.
3. Request Integrated-only GPU mode (`gpu_mux_mode=1`, `dgpu_disable=1`).
4. Use the existing Quiet fan configuration. Do not erase or rewrite the
   user's saved custom fan curves.

Apply changes sequentially and report partial failure in the banner. Never
reboot or shut down automatically. When the GPU change is queued, replace the
warning copy with a calm completion state such as: **Efficiency applied.
Integrated graphics will take effect after restart.**

The action must retain the existing safety checks around GPU users, unknown
process state, current versus queued firmware values, and replacement of a
previously queued GPU change.

## Settings

Add one plugin setting, enabled by default:

- **Suggest Efficiency on low battery**

Keep the initial thresholds fixed rather than exposing expert tuning controls.
They can be adjusted later from real usage feedback.

## Acceptance criteria

- The warning does not appear while charging or above 30% battery.
- The warning does not appear for 240 Hz alone.
- The warning appears after five minutes for the motivating case.
- Sustained meaningful CPU or GPU work suppresses or clears it.
- No warning path wakes a runtime-suspended dGPU.
- The banner is placed between sensors and controls on the Main tab.
- The action reaches Quiet + 60 Hz immediately when supported and queues
  Integrated-only mode without rebooting.
- Unsupported or failed actions are described without preventing the remaining
  safe actions.
- Existing GPU confirmation and queued-state behavior remains intact.
- Model and panel tests cover trigger timing, unavailable sensors, queued GPU
  state, partial action failure, and banner visibility.

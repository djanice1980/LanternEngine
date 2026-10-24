using System.Globalization;
using System.Text.RegularExpressions;

namespace BloodborneLauncher.Core
{
    /// <summary>
    /// Lossless Scaling's frame generation through the lsfg-vk Vulkan layer (lsfg-vk.dev), Linux
    /// only: the Engine page's "Frame generation: lsfg-vk" switch (LSFGVK_MULTIPLIER). The layer
    /// is configured by profiles in its conf.toml, chosen by the process they are active in or by
    /// LSFGVK_PROFILE: the launcher keeps one profile of its own for bb-probe with the chosen
    /// multiplier (the player's other profiles and [global], with the DLL's path, stay as they
    /// are) and names it in LSFGVK_PROFILE. The game is capped at the screen's refresh rate over
    /// the multiplier, on the delta-time (uncapped) patch so its speed does not depend on the cap, and
    /// the engine's own frame generation is left off for the run (two generators would stack).
    /// </summary>
    public static class LsfgVk
    {
        public const string ProfileName = "Paleblood Engine";
        public const string Process = "bb-probe";

        public static string ConfigPath =>
            Environment.GetEnvironmentVariable("LSFGVK_CONFIG") is { Length: > 0 } path
                ? path
                : Path.Combine(Environment.GetEnvironmentVariable("XDG_CONFIG_HOME") is { Length: > 0 } xdg
                      ? xdg
                      : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config"),
                  "lsfg-vk", "conf.toml");

        /// <summary>Applies the switch to the game's environment: the profile written, selected, and
        /// the frame limit set. Returns what was done, for the launcher's log.</summary>
        public static string Apply(IDictionary<string, string> env, int multiplier, int refreshHz)
        {
            var limit = Math.Max(30, Math.Max(refreshHz, 60) / Math.Max(multiplier, 2));
            env["BB_FPS"] = "uncap";
            env["BB_FPS_LIMIT"] = limit.ToString(CultureInfo.InvariantCulture);
            env["BB_VBLANK_HZ"] = "0";
            // The engine's own frame generation (FSR 3.1 or DLSS, frame_gen in lantern.ini) stays off
            // for this run: two generators would double the doubled frames.
            env["BB_FRAME_GEN"] = "off";
            env["LSFGVK_PROFILE"] = ProfileName;
            string written;
            try
            {
                written = WriteProfile(ConfigPath, multiplier) ? $"profile \"{ProfileName}\" written to {ConfigPath}" : $"profile \"{ProfileName}\" in {ConfigPath}";
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException)
            {
                written = $"profile not written ({e.Message}); the layer's own rules apply";
            }
            return $"lsfg-vk {multiplier}x: {written}; the game capped at {limit} FPS, the engine's own frame generation off";
        }

        /// <summary>The launcher's [[profile]] block.</summary>
        public static string Profile(int multiplier) =>
            "[[profile]]\n" +
            $"name = \"{ProfileName}\"\n" +
            $"active_in = [\"{Process}\"]\n" +
            $"multiplier = {multiplier.ToString(CultureInfo.InvariantCulture)}\n" +
            "flow_scale = 1.0\n" +
            "performance_mode = false\n" +
            "pacing = \"vsync\"\n" +
            "override_present_mode = true\n";

        /// <summary>Puts the launcher's profile into the layer's config file: replaced where it is,
        /// appended where it is not, the file made (version 2) where there is none. Returns whether
        /// the file changed.</summary>
        public static bool WriteProfile(string path, int multiplier)
        {
            var text = File.Exists(path) ? File.ReadAllText(path).Replace("\r\n", "\n") : "";
            var updated = Merge(text, Profile(multiplier));
            if (updated == text) return false;
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, updated);
            return true;
        }

        /// <summary>The config text with the launcher's profile in place of its earlier one (the
        /// [[profile]] block whose name is ProfileName), else added at the end.</summary>
        public static string Merge(string text, string profile)
        {
            if (text.Trim().Length == 0) return "version = 2\n\n" + profile;
            var blocks = Regex.Split(text, @"(?m)^(?=\[\[profile\]\]\s*$)");
            var mine = Regex.Replace(profile, @"\s+$", "") + "\n";
            var found = false;
            for (var i = 0; i < blocks.Length; i++)
            {
                if (!blocks[i].StartsWith("[[profile]]", StringComparison.Ordinal) ||
                    !Regex.IsMatch(blocks[i], $@"(?m)^\s*name\s*=\s*""{Regex.Escape(ProfileName)}""\s*$"))
                    continue;
                // Keep what follows the block in it (a later [global] or a comment belongs to the file).
                var trailing = Regex.Match(blocks[i], @"(?m)^\[global\][\s\S]*$").Value;
                blocks[i] = mine + (trailing.Length > 0 ? "\n" + trailing : "");
                found = true;
                break;
            }
            var merged = string.Concat(blocks);
            if (found) return merged;
            if (!merged.EndsWith("\n", StringComparison.Ordinal)) merged += "\n";
            return merged + "\n" + mine;
        }
    }
}

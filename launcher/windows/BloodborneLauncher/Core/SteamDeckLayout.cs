using System.Text.RegularExpressions;

namespace BloodborneLauncher.Core
{
    /// <summary>
    /// The controller layout a Steam Deck gives the shortcut in Game Mode. A non-Steam shortcut starts
    /// on Steam's keyboard-and-mouse layout: the left stick types W/A/S/D (the hunter moves as with a
    /// d-pad), the right stick moves the mouse, and the game never sees a gamepad. The layout a
    /// shortcut uses with the Deck's own controller is listed in
    /// steamapps/common/Steam Controller Configs/[account]/config/configset_controller_neptune.vdf,
    /// keyed by the shortcut's name in lower case, read when Steam starts (and kept in Steam Cloud).
    /// "Add to Steam" puts the Gamepad template there for Bloodborne when the file has no entry for it
    /// yet; a layout the player chose stays as it is.
    /// </summary>
    public static class SteamDeckLayout
    {
        /// <summary>Steam's "Gamepad" template for the Deck: every control as on an Xbox controller.</summary>
        public const string Template = "controller_neptune_gamepad_joystick.vdf";
        public const string FileName = "configset_controller_neptune.vdf";

        public static string PathFor(string steam, string account) =>
            Path.Combine(steam, "steamapps", "common", "Steam Controller Configs", account, "config", FileName);

        /// <summary>The file's text with the shortcut's entry added, or null when it already has one
        /// (or the text is not a config set that can take one).</summary>
        public static string? Merge(string text, string appName)
        {
            var key = appName.ToLowerInvariant();
            if (Regex.IsMatch(text, "\"" + Regex.Escape(key) + "\"\\s*\\{", RegexOptions.IgnoreCase)) return null;
            var entry = $"\t\"{key}\"\n\t{{\n\t\t\"template\"\t\t\"{Template}\"\n\t}}\n";
            if (string.IsNullOrWhiteSpace(text)) return "\"controller_config\"\n{\n" + entry + "}\n";
            var close = text.LastIndexOf('}');
            if (close < 0 || !text.Contains("\"controller_config\"", StringComparison.OrdinalIgnoreCase)) return null;
            return text[..close] + entry + text[close..];
        }

        /// <summary>Writes the entry for the account; what was done, for the log.</summary>
        public static string Apply(string steam, string account, string appName)
        {
            var path = PathFor(steam, account);
            var text = File.Exists(path) ? File.ReadAllText(path) : "";
            var merged = Merge(text, appName);
            if (merged is null)
                return text.Length == 0 ? $"Steam Deck layout: {path} left alone" : $"Steam Deck layout: {appName} already has one in {path}";
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            if (File.Exists(path)) File.Copy(path, path + ".bak", overwrite: true);
            File.WriteAllText(path, merged);
            return $"Steam Deck layout: Gamepad template for {appName} in {path}";
        }
    }
}

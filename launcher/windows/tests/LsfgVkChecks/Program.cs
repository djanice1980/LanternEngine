// Checks for Core/LsfgVk.cs: the launcher's profile in lsfg-vk's conf.toml and the game's cap.
//   dotnet run --project launcher/windows/tests/LsfgVkChecks
using BloodborneLauncher.Core;

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

// No file yet: a version 2 file with the profile alone.
var fresh = LsfgVk.Merge("", LsfgVk.Profile(2));
Require(fresh.StartsWith("version = 2\n\n[[profile]]\n", StringComparison.Ordinal), "A new file starts with its version");
Require(fresh.Contains("active_in = [\"bb-probe\"]\n") && fresh.Contains("multiplier = 2\n"), "The profile names bb-probe and the multiplier");

// A player's file: [global] and their own profiles stay, ours is added at the end.
const string theirs = "version = 2\n\n[global]\ndll = \"/home/p/Lossless Scaling/lsfg-vk.dll\"\nallow_fp16 = true\n\n[[profile]]\nname = \"mpv\"\nactive_in = [\"mpv\"]\nmultiplier = 3\n";
var added = LsfgVk.Merge(theirs, LsfgVk.Profile(2));
Require(added.StartsWith(theirs, StringComparison.Ordinal), "The player's file is kept as it is");
Require(added.EndsWith("override_present_mode = true\n", StringComparison.Ordinal) && added.Contains("name = \"Paleblood Engine\""), "Ours is appended");

// Ours already there, in the middle: replaced in place, the rest untouched.
var middle = theirs.Replace("[[profile]]\nname = \"mpv\"", LsfgVk.Profile(2) + "\n[[profile]]\nname = \"mpv\"");
var replaced = LsfgVk.Merge(middle, LsfgVk.Profile(4));
Require(replaced.Contains("multiplier = 4\n") && !replaced.Contains("multiplier = 2\n"), "The multiplier changed");
Require(replaced.Contains("[[profile]]\nname = \"mpv\"\nactive_in = [\"mpv\"]\nmultiplier = 3\n"), "The player's profile is untouched");
Require(replaced.Split("Paleblood Engine").Length == 2, "Ours appears once");
Require(LsfgVk.Merge(replaced, LsfgVk.Profile(4)) == replaced, "Merging the same profile again changes nothing");

// A [global] written after our profile belongs to the file, not to our block.
var globalAfter = "version = 2\n\n" + LsfgVk.Profile(2) + "\n[global]\nallow_fp16 = false\n";
var kept = LsfgVk.Merge(globalAfter, LsfgVk.Profile(3));
Require(kept.Contains("[global]\nallow_fp16 = false\n") && kept.Contains("multiplier = 3\n"), "[global] after our block survives");

// The environment: the delta-time patch, the cap at refresh over multiplier, the profile selected.
var env = new Dictionary<string, string> { ["BB_FPS"] = "120", ["BB_FPS_LIMIT"] = "120", ["BB_VBLANK_HZ"] = "0" };
var dir = Path.Combine(Path.GetTempPath(), "lsfg-vk-checks-" + Guid.NewGuid().ToString("N"));
Environment.SetEnvironmentVariable("LSFGVK_CONFIG", Path.Combine(dir, "conf.toml"));
try
{
    var note = LsfgVk.Apply(env, 2, 120);
    Require(env["BB_FPS"] == "uncap" && env["BB_FPS_LIMIT"] == "60" && env["LSFGVK_PROFILE"] == "Paleblood Engine", "2x at 120 Hz caps at 60 on the uncapped patch: " + note);
    Require(File.Exists(Path.Combine(dir, "conf.toml")) && note.Contains("written"), "The file is made where there is none: " + note);
    Require(LsfgVk.Apply(env, 3, 144).Contains("capped at 48") && env["BB_FPS_LIMIT"] == "48", "3x at 144 Hz caps at 48");
    Require(LsfgVk.Apply(env, 4, 60).Contains("capped at 30"), "The cap never goes below 30");
}
finally
{
    Environment.SetEnvironmentVariable("LSFGVK_CONFIG", null);
    try { Directory.Delete(dir, recursive: true); } catch { }
}
Console.WriteLine("LsfgVk checks passed");

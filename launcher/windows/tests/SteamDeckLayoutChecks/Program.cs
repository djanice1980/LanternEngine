// Checks for Core/SteamDeckLayout.cs: the shortcut's Gamepad layout in Steam's Deck config set.
//   dotnet run --project launcher/windows/tests/SteamDeckLayoutChecks -f net9.0
using BloodborneLauncher.Core;

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

const string Entry = "\t\"bloodborne\"\n\t{\n\t\t\"template\"\t\t\"controller_neptune_gamepad_joystick.vdf\"\n\t}\n";

// No file yet: a config set with the entry alone.
var fresh = SteamDeckLayout.Merge("", "Bloodborne");
Require(fresh == "\"controller_config\"\n{\n" + Entry + "}\n", "A new file holds the entry alone: " + fresh);

// A player's file (EmuDeck's entries, a Steam game's): theirs stay, ours goes before the closing brace.
const string theirs = "\"controller_config\"\n{\n\t\"1091500\"\n\t{\n\t\t\"template\"\t\t\"controller_neptune_gamepad_fps.vdf\"\n\t}\n\t\"mario kart 8\"\n\t{\n\t\t\"template\"\t\t\"emudeck_controller_neptune.vdf\"\n\t}\n}\n";
var added = SteamDeckLayout.Merge(theirs, "Bloodborne");
Require(added == theirs[..theirs.LastIndexOf('}')] + Entry + "}\n", "Ours is added before the closing brace: " + added);
Require(added!.Contains("\"mario kart 8\""), "The player's entries stay");

// Already there (the player's own choice, any template): nothing changes.
Require(SteamDeckLayout.Merge(added, "Bloodborne") is null, "An entry is not doubled");
var chosen = theirs.Replace("\"mario kart 8\"", "\"Bloodborne\"").Replace("emudeck_controller_neptune.vdf", "controller_neptune_wasd.vdf");
Require(SteamDeckLayout.Merge(chosen, "Bloodborne") is null, "The player's own choice stays, whatever its case");

// Not a config set: left alone.
Require(SteamDeckLayout.Merge("\"something_else\"\n{\n}\n", "Bloodborne") is null, "Another file is left alone");

// The file: made where there is none, kept with a backup where there is one.
var dir = Path.Combine(Path.GetTempPath(), "deck-layout-checks-" + Guid.NewGuid().ToString("N"));
try
{
    var note = SteamDeckLayout.Apply(dir, "7012510", "Bloodborne");
    var path = SteamDeckLayout.PathFor(dir, "7012510");
    Require(File.Exists(path) && File.ReadAllText(path) == fresh && note.Contains("Gamepad template"), "The file is made: " + note);
    Require(SteamDeckLayout.Apply(dir, "7012510", "Bloodborne").Contains("already"), "A second run changes nothing");
    File.WriteAllText(path, theirs);
    SteamDeckLayout.Apply(dir, "7012510", "Bloodborne");
    Require(File.ReadAllText(path) == added && File.ReadAllText(path + ".bak") == theirs, "The player's file gets the entry and a backup");
}
finally
{
    try { Directory.Delete(dir, recursive: true); } catch { }
}
Console.WriteLine("SteamDeckLayout checks passed");

# Ashen Divine

*Only embers remember the gods.*

A first-person soulslike prototype made in Godot 4. Fight your way through a
torch-lit dungeon with a rapier and a flintlock pistol, find what's hidden
behind the walls, and face the Reaper at its end.

## Download

| Platform | Download |
| --- | --- |
| Windows | [AshenDivine-windows.zip](https://github.com/Jesajeba/ashen-divine/releases/latest/download/AshenDivine-windows.zip) |
| macOS (Intel and Apple Silicon) | [AshenDivine-macos.zip](https://github.com/Jesajeba/ashen-divine/releases/latest/download/AshenDivine-macos.zip) |

All versions are on the [Releases page](https://github.com/Jesajeba/ashen-divine/releases).

**Windows:** unzip and run `AshenDivine.exe`. If Windows says it protected your
PC, click **More info → Run anyway** (the game isn't code-signed).

**macOS:** unzip, then right-click the app and choose **Open**, then **Open**
again (the app isn't signed by Apple). If macOS says the app is damaged, run
this once in Terminal and try again:

```
xattr -dr com.apple.quarantine "/path/to/Ashen Divine.app"
```

## Controls

| Action | Input |
| --- | --- |
| Move / look | WASD / mouse |
| Attack (3-hit combo) | Left click |
| Heavy thrust | Hold left click, release to lunge |
| Fire pistol | Right click |
| Dodge | Shift |
| Jump | Space |
| Drink flask | F |
| Pause | Esc |

## Tips

- Every enemy telegraphs its attacks: watch the stance, and the glint on the
  weapon just before it swings.
- Shoot an enemy as its blow is launched to **parry** it. It staggers, and
  every hit while it reels does triple damage.
- The pistol costs health. Win it back by landing melee hits soon after.
- Not every wall is what it seems.

## Building from source

Open the project in Godot 4.7.2. Pushing a version tag (for example `v0.2.0`)
builds Windows and macOS versions on GitHub Actions and publishes them as a
release.

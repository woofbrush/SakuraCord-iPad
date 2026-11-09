<div align="center">
  <img src="Brand/Banners/SakuraCord-README-Header.svg" width="1200" alt="SakuraCord">

  <p>A fast, native Discord client shaped around SwiftUI, macOS, and the way desktop chat should feel.</p>

  <p>
    <a href="https://github.com/SakuraCordApp/SakuraCord/releases/latest"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/release/SakuraCordApp/SakuraCord.svg?label=Release&amp;mode=dark&amp;size=sm"><img alt="Latest release" src="https://shieldcn.dev/github/release/SakuraCordApp/SakuraCord.svg?label=Release&amp;mode=light&amp;size=sm"></picture></a>
    <a href="https://discord.gg/hWNwFXkUTP"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/discord/online-members/hWNwFXkUTP.svg?variant=branded&amp;mode=dark&amp;size=sm"><img alt="Discord online members" src="https://shieldcn.dev/discord/online-members/hWNwFXkUTP.svg?variant=branded&amp;mode=light&amp;size=sm"></picture></a>
    <a href="https://roadmap.sakuracord.app"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Roadmap-D9578B.svg?logo=ri%3AFaMap&amp;logoColor=white&amp;mode=dark&amp;size=sm"><img alt="Roadmap" src="https://shieldcn.dev/badge/Roadmap-D9578B.svg?logo=ri%3AFaMap&amp;logoColor=white&amp;mode=light&amp;size=sm"></picture></a>
  </p>

  <p>
    <a href="https://github.com/SakuraCordApp/SakuraCord/actions/workflows/ci.yml"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/ci/SakuraCordApp/SakuraCord.svg?workflow=ci.yml&amp;branch=main&amp;label=Build&amp;variant=secondary&amp;mode=dark&amp;size=xs"><img alt="Build status" src="https://shieldcn.dev/github/ci/SakuraCordApp/SakuraCord.svg?workflow=ci.yml&amp;branch=main&amp;label=Build&amp;variant=secondary&amp;mode=light&amp;size=xs"></picture></a>
    <a href="#build-from-source"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/macOS-27-18181B.svg?logo=apple&amp;mode=dark&amp;size=xs"><img alt="Requires iPadOS 27" src="https://shieldcn.dev/badge/macOS-27-18181B.svg?logo=apple&amp;mode=light&amp;size=xs"></picture></a>
    <a href="https://www.swift.org"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Swift-6.4-F05138.svg?logo=swift&amp;mode=dark&amp;size=xs"><img alt="Built with Swift 6.4" src="https://shieldcn.dev/badge/Swift-6.4-F05138.svg?logo=swift&amp;mode=light&amp;size=xs"></picture></a>
  </p>

  <p>
    <a href="https://github.com/woofbrush/SakuraCord-iPad/releases/">Download .ipa</a>
    ·
    <a href="#build-from-source">Build from source</a>
    ·
    <a href="docs/README.md">Documentation</a>
  </p>
</div>

> [!IMPORTANT]
> This is a port of SakuraCord to iPadOS only, mobile experience might not feel as good, made to be experienced by a mouse and keyboard.
>
> Build it with `iPad/build.sh` ([instructions](docs/DEVELOPMENT.md#ipados-app)). The rest of this page describes [upstream SakuraCord](https://github.com/SakuraCordApp/SakuraCord) for macOS.

> [!WARNING]
> This is my first ever iOS/iPadOS related project, I don't even own a mac therefore I had to build/compile this with xtool, support would be appreciated.
---

## A Discord client that belongs on iPadOS

SakuraCord preserves the visual language and familiar rhythm of Discord, then
reimagines the experience through Liquid Glass and native macOS design instead
of wrapping the web app in an Electron runtime.

The result keeps Discord's familiarity while looking and behaving like a native
Mac app.

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🌸 Native by design</h3>
      SwiftUI surfaces, real iPadOS windows, menus, shortcuts, settings, and
      Liquid Glass presentation.
    </td>
    <td width="50%" valign="top">
      <h3>⚡ Responsive conversations</h3>
      Native timeline rendering, bounded media work, and shared caches keep
      conversations responsive.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🎙️ Voice and video</h3>
      Native device controls, guild voice, direct-message calls, Opus audio,
      H.264 video, voice-server migration, and DAVE support.
    </td>
    <td width="50%" valign="top">
      <h3>✨ Rich Discord content</h3>
      Embeds, Components V2, modals, stickers, GIFs, uploads, custom emoji,
      slash commands, and media previews where Discord capability gates allow.
    </td>
  </tr>
</table>

## Download

Download the [latest SakuraCord .ipa](https://github.com/woofbrush/SakuraCord-iPad/releases/)
for iPadOS 27 or newer, open it, and move SakuraCord into Applications.

SakuraCord is an independent project and is not affiliated with Discord.
Discord does not provide a supported third-party platform for normal-account
clients, so compatibility can change as Discord evolves.

## Build from source

SakuraCord for iPadOS builds with [xtool](https://github.com/xtool-org/xtool) on
macOS, Linux or Windows through WSL, so a Mac isn't required. You need xtool, its
Darwin SDK with the iOS 27 SDK, Python 3 and Git. On Linux and WSL you also need
Swift 6.4 on your `PATH`.

```sh
git clone https://github.com/woofbrush/SakuraCord-iPad.git
cd SakuraCord-iPad
xtool setup
iPad/build.sh
```

`xtool setup` installs the Darwin SDK and only needs to run once. `iPad/build.sh`
makes a release build and writes it to `iPad/xtool/SakuraCordPad.ipa`. On Linux or
WSL, if the first build can't find the OpenSSL headers, run `iPad/build.sh` again:
it links them once the dependencies have downloaded.

The app requires iPadOS 27. Install the IPA with a sideloading tool such as
[Impactor](https://github.com/claration/impactor), and keep its app extension,
which screen sharing needs. See the
[development guide](docs/DEVELOPMENT.md#ipados-app) for how the port is put together.

## Contributing and support

Start with the [contributing guide](CONTRIBUTING.md) for setup, change guidelines,
verification, and pull requests. The [documentation task index](docs/README.md)
points to the owner and detailed guidance for each area.

For a bug report, include reproduction steps, expected and actual behaviour, and
the app version/release track. The [support recipe](docs/DEVELOPMENT.md#report-a-problem)
explains how to collect a support summary and sanitized diagnostics. Use the
[issue tracker](https://github.com/SakuraCordApp/SakuraCord/issues) or the
[Discord community](https://discord.gg/hWNwFXkUTP).

## Repository guide

| Path | Purpose |
| --- | --- |
| `App/` | Native macOS application and plugin-host targets |
| `iPad/` | iPadOS build of the app, compiled with xtool ([build](docs/DEVELOPMENT.md#ipados-app)) |
| `Packages/` | Models, Discord protocol, persistence, message rendering, media, and plugin contracts |
| `Brand/` | Logos, banners, and brand metadata |
| `Config/` | Application entitlements |
| `docs/` | Canonical architecture, protocol, testing, development, and release guides |
| `script/` | Build, test, quality, packaging, and release entry points |

SwiftPM manifests are the build source of truth;
`SakuraCord.xcworkspace` is a convenience entry point. Start with the
[documentation index](docs/README.md), then use the
[architecture guide](docs/ARCHITECTURE.md) or
[protocol baseline](docs/PROTOCOL_BASELINE.md) for deeper work.

## Sponsors

Thank you to the sponsors supporting SakuraCord's development.

<p align="center">
  <a href="https://github.com/charlie-hotel">
    <img src="Brand/Sponsors/charlie-hotel.svg" width="80" height="80" alt="charlie-hotel's avatar"><br>
    <strong>charlie-hotel</strong>
  </a>
</p>

## Follow along

<table>
  <tr>
    <td align="center" width="33%">
      <h3>Discord</h3>
      Talk with the community, share feedback, and follow day-to-day project
      conversation.<br><br>
      <a href="https://discord.gg/hWNwFXkUTP"><strong>Join the server →</strong></a>
    </td>
    <td align="center" width="33%">
      <h3>Roadmap</h3>
      Browse planned work, active development, completed features, and community
      requests.<br><br>
      <a href="https://roadmap.sakuracord.app"><strong>Explore the roadmap →</strong></a>
    </td>
    <td align="center" width="33%">
      <h3>Releases</h3>
      Read release notes and download the newest packaged build for macOS.<br><br>
      <a href="https://github.com/SakuraCordApp/SakuraCord/releases/latest"><strong>Get the latest build →</strong></a>
    </td>
  </tr>
</table>

<div align="center">
  <sub>Made for macOS with Swift, SwiftUI, and a little sakura pink.</sub>
</div>

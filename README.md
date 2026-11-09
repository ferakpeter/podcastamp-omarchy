# podcastamp for Omarchy

What [podcastamp](https://github.com/ferakpeter/podcastamp) plays, in the Omarchy
bar: play or pause, skip to the next topic, seek, quote the moment, and the
full player one click away.

## Install podcastamp first

The plugin reads `podcastamp now --follow --json`, so it needs the
`podcastamp` command on your PATH:

```sh
omarchy pkg aur add podcastamp-bin
```

Then add the plugin from the Omarchy plugin marketplace, or let podcastamp
install the copy built into it, which always matches its version:

```sh
podcastamp omarchy install
```

`podcastamp omarchy install` copies the plugin into
`~/.config/omarchy/plugins/io.github.ferakp.podcastamp/` and writes the
absolute path of the `podcastamp` executable into `Command.js`, so the plugin
runs that exact binary. It also leaves a marker file there, so
`podcastamp omarchy uninstall` only removes a copy podcastamp wrote and never
a checkout made by `omarchy plugin add`.

## Usage

- **Click**: play or pause; when nothing plays, open the player.
- **Middle click**: skip to the next topic.
- **Wheel**: seek.
- **Right click**: open the popout, with the controls and quoting the moment.
- **Escape**: close the popout.

## Configure

Settings are in the widget's settings in Omarchy:

- **Show when nothing plays**: keep the widget in the bar while idle; a
  click opens the player.
- **Longest episode title**: how many characters of the title the bar shows.

Move the widget to another part of the bar:

```sh
omarchy bar move io.github.ferakp.podcastamp --section center
```

## Remove

```sh
omarchy plugin remove io.github.ferakp.podcastamp
```

or, if podcastamp installed it:

```sh
podcastamp omarchy uninstall
```

## Security

Omarchy plugins run unsandboxed in the shell process with your user
permissions. This one starts the `podcastamp` command (a long-running
`now --follow --json` follower, plus short `podcastamp ctl` commands for the
actions above) and nothing else. It makes no network requests of its own and asks for
no extra privileges. The only external dependency is the `podcastamp`
executable.

## License

MIT, see [LICENSE](LICENSE).

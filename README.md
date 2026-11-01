# podcastamp for Omarchy

What [podcastamp](https://github.com/ferakp/podcastamp) plays, in the Omarchy
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

## Settings

- **Show when nothing plays**: keep the widget in the bar while idle; a
  click opens the player.
- **Longest episode title**: how many characters of the title the bar shows.

## License

MIT, see [LICENSE](LICENSE).

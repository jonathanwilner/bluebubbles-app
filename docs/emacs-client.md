# BlueBubbles Emacs Client Package

The `tools/emacs/bluebubbles.el` module provides an Emacs front-end for the BlueBubbles server API.  It is packaged as a standard Emacs library so that it can be installed with `use-package`, byte-compiled, and submitted to ELPA.

## Installation

Add the repository directory to your `load-path` and declare the package with `use-package`:

```elisp
(use-package bluebubbles
  :load-path "/path/to/bluebubbles-app/tools/emacs"
  :commands (bluebubbles-login
             bluebubbles-dispatch
             bluebubbles-send-text
             bluebubbles-send-attachment
             bluebubbles-notifications-mode)
  :init
  ;; Defaults match the hosted demo instance; customise as needed.
  (setq bluebubbles-base-url "https://imessage.thewilners.com"
        bluebubbles-guid "Platypus94022$")
  :config
  ;; Enable background message polling.
  (bluebubbles-notifications-mode 1))
```

When packaging for ELPA, include the `tools/emacs` directory so that `bluebubbles.el`, its autoload cookies, and the tests are available.  The library only depends on Emacs 27.1 or newer.

## Interactive Commands

The package exposes several interactive entry points, each tagged with autoload cookies so they can be lazy-loaded:

- `bluebubbles-login` – Performs an authentication handshake and caches server metadata.
- `bluebubbles-dispatch` – Presents a completing-read interface for every documented REST and socket action.
- `bluebubbles-send-text` / `bluebubbles-send-attachment` – Send chat messages or file attachments.
- `bluebubbles-list-chats` / `bluebubbles-open-chat` – Inspect chat metadata and message history.
- `bluebubbles-notifications-mode` – Global minor mode that enables or disables the polling-based notification loop.

All commands honour the default credentials for the hosted server so manual authentication is only required when the server rejects the configured GUID.

## Testing and Build Automation

The Emacs client ships with an automated ERT suite that covers the request builder, multipart encoding, and attachment helpers.  Run the tests from the repository root with:

```sh
make -C tools/emacs test
```

To produce byte-compiled artefacts ready for ELPA distribution:

```sh
make -C tools/emacs byte-compile
```

`make clean` removes generated `.elc` files from the package and its test suite.

## Development Tips

- All networked commands funnel through `bluebubbles--call`, which appends the server GUID automatically and logs unexpected responses to the buffer named by `bluebubbles-log-buffer`.
- Attachment uploads use a handwritten multipart encoder so that binary payloads can be sent without additional dependencies.
- Tests avoid network access by stubbing low-level functions (`bluebubbles--call`, `bluebubbles--read-file-bytes`), making them safe to run in continuous integration.

Refer to `docs/server_api.md` for the full catalogue of REST and Socket.IO actions that `bluebubbles-dispatch` can trigger.

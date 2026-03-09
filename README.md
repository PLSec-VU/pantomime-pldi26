# Meta-Artifact for the paper *Pantomime: Constructive Leakage Proofs via Simulation*

This repository contains a Nix derivation for building the artifact (a Docker
image) for the paper. See [artifact/](artifact/) for the actual benchmarking
infrastructure, including dependencies, if you want to run it outside docker.

## (Re-)creating the Docker image

### Requirements
- The [Nix](https://nixos.org/) package manager.

### Initial setup

You must initialize and update the submodules:

```
git submodule init
git submodule update
```

### Building the Docker image

Run

```
$ nix-build docker.nix -o pantomime.tar.gz
```

> Note: If you have Nix sandboxing enabled (via `nix.settings.sandbox = true` in
> a NixOS configuration or `sandbox = true` in `nix.conf`), you will need to
> pass `--option sandbox false` and run the command as a Nix trusted user as
> Stack needs internet access during the build.

This produces a file called `pantomime.tar.gz` (a symlink to the actual image, which
is in the Nix store).

See [artifact/README.md](artifact/README.md) for further instructions.

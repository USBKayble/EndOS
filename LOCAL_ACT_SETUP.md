# Running GitHub Actions Locally with act

This guide covers how to run and debug the `build_iso.yml` workflow locally using [act](https://github.com/nektos/act).

## Installation

```bash
# Install act (v0.2.40)
curl -sL "https://github.com/nektos/act/releases/download/v0.2.40/act_Linux_x86_64.tar.gz" -o /tmp/act.tar.gz
mkdir -p ~/.local/bin
tar xzf /tmp/act.tar.gz -C ~/.local/bin
chmod +x ~/.local/bin/act
export PATH="$HOME/.local/bin:$PATH"

# Verify
act --version
```

## Docker Setup

The `build_iso.yml` workflow uses the `archlinux:latest` container. Pull it first:

```bash
docker pull archlinux:latest
```

## Running the Workflow

### Option 1: Workflow Dispatch (Recommended for testing)

This simulates a manual workflow run:

```bash
act workflow_dispatch -W
```

### Option 2: Push Event

```bash
act push -W
```

### Option 3: Specific Job

Run only the `build` job:

```bash
act workflow_dispatch -j build
```

## Debugging Tips

### 1. Dry Run

Preview what would run without executing:

```bash
act workflow_dispatch -W --dryrun
```

### 2. Verbose Output

```bash
act workflow_dispatch -W --verbose
```

### 3. Interactive Shell

Drop into a shell when a job fails:

```bash
act workflow_dispatch -W --interactive
```

### 4. View Logs

The workflow outputs to `build.log`. During act runs, check:

```bash
tail -f build.log
```

### 5. Pass Environment Variables

Create a `.env` file:

```bash
echo "MY_VAR=value" > .env
```

Or pass directly:

```bash
act workflow_dispatch -W -e my-env.env
```

## Configuration File

A `.actrc` file is provided in the project root:

```
-P ubuntu-latest=archlinux:latest
--pull=false
--verbose
```

## Common Issues

### Issue: Container lacks internet

The workflow needs internet to download packages. Ensure Docker has network access:

```bash
docker run --rm archlinux:latest ping -c 3 google.com
```

### Issue: Out of disk space

The build requires ~20GB. Clean up Docker:

```bash
docker system prune -a
```

### Issue: Permission denied

The build.sh requires root. act runs containers as root by default, so this should work.

### Issue: Missing /dev/fuse

ISO building may need FUSE. Not available in unprivileged containers by default.

## Workflow Structure

The `build_iso.yml` has two jobs:

1. **check-updates** - Checks if dots-hyprland has new commits, uses cache
2. **build** - Actually builds the ISO (requires check-updates to pass)

For local testing, you may want to bypass the check-updates:

```bash
# Run build directly (bypassing the conditional)
act workflow_dispatch -j build --force
```

## Notes

- **Build Time**: ~30-60 minutes even locally
- **Container Resources**: Allocate 4+ CPU cores, 8+ GB RAM
- **Output**: ISO will be in `out/` directory

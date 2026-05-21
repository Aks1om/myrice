# Backup & rollback

How the myrice setup stays recoverable. Two independent safety nets:

1. **Fallback kernel** (`linux-lts`) with its own systemd-boot entry — recovers
   from a broken main-kernel update.
2. **Timeshift rsync snapshots** with an automatic pre-pacman snapshot —
   recovers from a broken package, broken initramfs, broken config in `/etc`,
   or anything else short of disk corruption.

Both are set up by `install.sh` (`lts-kernel` and `backup` stages).

---

## Snapshot strategy

### Automatic

| When | How | Tag | Slot retention |
|------|-----|-----|----------------|
| Before every `pacman` transaction | `/etc/pacman.d/hooks/50-timeshift.hook` | `D` | 5 daily slots |
| Daily cron | `timeshift` cron job (installed by the timeshift package) | `D` | shares the 5 daily slots |
| Weekly / monthly cron | same cron | `W` / `M` | 3 weekly, 2 monthly |

You don't have to do anything for these — they keep a rolling history of the
last 5 days plus 3 weekly + 2 monthly points-in-time.

### Manual — "known-good"

After you've verified the system works (post-major-change, post-rice-tweak,
post-driver-replacement), pin that state with a monthly-tagged snapshot:

```bash
sudo timeshift --create --comments "known-good 2026-05-21 after wifi+system-tune" --tags M
```

Monthly-tagged snapshots survive much longer than daily ones. Reach for this
**right after** you've verified everything works end-to-end (reboot, Wi-Fi
connects, panels open, etc.). Treat it like a `git tag`: small ceremony, big
relief later.

Rule of thumb for *when*:

- After a big migration (kernel swap, driver replacement, bar migration).
- Before you head to bed / leave for the day — closes the loop on whatever
  you changed today.
- Before risky surgery (replacing a service manager, swapping bootloader,
  etc.) — pair it with `--comments "before X"`.

### List & inspect

```bash
sudo timeshift --list
```

Each snapshot has a numeric index, timestamp, tag, and the comment you gave
it. The currently-restoreable set is what's there.

---

## Rollback

There are two failure modes.

### A) System still boots, something broke after an update

This is the common case (Quickshell stopped rendering, an `/etc` file got
overwritten, a package broke):

```bash
sudo timeshift --list                   # find the snapshot you want
sudo timeshift --restore                # interactive picker
# OR target a specific one:
sudo timeshift --restore --snapshot '2026-05-21_22-22-43'
```

Timeshift restores files in-place using rsync. Your `/home` is **not**
touched — only system files. Reboot when prompted.

### B) Main kernel won't boot at all

Powers on, you get to the systemd-boot menu but the default entry fails or
hangs. Steps:

1. At the systemd-boot menu (held automatically for 5 seconds — see
   `/boot/loader/loader.conf`), pick **Arch Linux (linux-lts, fallback)**.
2. You'll boot into the same root filesystem on the LTS kernel. Everything
   you have still works — same configs, same DKMS modules (rebuilt for LTS
   too), same users.
3. From there, follow case (A): `sudo timeshift --restore`.
4. Reboot and verify the main kernel boots clean.

If even the LTS kernel doesn't boot — you're past what this setup
protects. Boot from an Arch ISO, `chroot` in, restore from a snapshot
manually with `rsync -aHAX` from `/run/timeshift/<id>/backup/timeshift/snapshots/<ts>/localhost/` to `/`.

---

## What's *not* snapshotted

Timeshift here is configured to skip:

- `/home/*` — your work, configs, code, downloads. **Not protected by this
  mechanism.** Use a separate user-data backup (borg / restic / a sync
  service / whatever) for `/home`.
- `/root` — same reason.

Rationale: snapshotting `/home` on every pacman transaction would balloon
disk usage and lengthen each snapshot to minutes. System rollback should be
fast and disposable; user-data backup is a separate concern.

---

## Disk budget

Each rsync snapshot reuses unchanged inodes via hardlinks. Typical Arch +
Hyprland system snapshot:

- First snapshot: ~5 GB.
- Subsequent: ~50-300 MB per snapshot (deltas only).
- 5 daily + 3 weekly + 2 monthly ≈ 7-12 GB total ceiling.

Check actual usage:

```bash
sudo du -sh /run/timeshift/*/backup/timeshift/snapshots/
sudo timeshift --list
```

---

## Pruning manually

```bash
sudo timeshift --list                                # find the index
sudo timeshift --delete --snapshot '2026-05-21_22-22-43'
sudo timeshift --delete-all                          # nuclear: every snapshot gone
```

The pacman hook will create a fresh one on the next `pacman -Syu` anyway,
so `--delete-all` after a misconfigured run is fine.

---

## Sanity-check the safety net (quarterly)

Once every couple of months, *verify* the rollback actually works:

1. `sudo timeshift --list` — should show 5+ snapshots, including at least
   one tagged `M`.
2. `ls /boot/loader/entries/arch-linux-lts.conf` — should exist.
3. Reboot, hold the systemd-boot menu, pick the LTS entry — should boot all
   the way to your Hyprland session. (Then reboot back to main.)
4. Optionally: do a non-destructive `--restore` dry-run by snapshotting
   first, restoring a single non-critical file, and confirming the file
   came back.

A backup you've never tested is a backup you don't have.

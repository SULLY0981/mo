"""Builds store/trailer.mp4 and fresh store/screenshots/*.png on Windows, macOS or Linux.

Needs Godot 4.3 and ffmpeg on PATH (or set GODOT=/path/to/godot).  Run from the repo root:
    python tools/store/make_trailer.py
Clips are recorded with Godot's Movie Maker (the bot plays with god mode on), title cards are
rendered by the game itself (--cards) so they use the game's fonts.
"""
import os, subprocess, shutil, tempfile, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "godot")
TMP = pathlib.Path(tempfile.gettempdir()) / "lantern_trailer"
FPS = 30
# name, start second, Keeper, frames, extra args, screenshot second (relative to clip start)
CLIPS = [
    ("c1", 25, "keeper", 150, [], 3.5),
    ("c2", 120, "ember", 150, ["--coop"], 3.0),
    ("c3", 184, "warden", 180, [], 3.0),
    ("c4", 372, "reaper", 150, [], 3.0),
    ("c5", 548, "seer", 180, [], 4.0),
    ("c6", 615, "alchemist", 150, [], 2.5),
    ("c7", 728, "saint", 210, ["--coop"], 4.5),
]
ORDER = ["t0", "c1", "c2", "c3", "t1", "c4", "c5", "c6", "t2", "c7", "t9"]
CARD_SECONDS = {"t0": 3.5, "t1": 2.5, "t2": 2.5, "t9": 5.0}


def run(cmd, **kw):
    print(" ".join(str(c) for c in cmd))
    subprocess.run(cmd, check=True, **kw)


def main():
    if TMP.exists():
        shutil.rmtree(TMP)
    TMP.mkdir(parents=True)
    shots = ROOT / "store" / "screenshots"
    shots.mkdir(parents=True, exist_ok=True)
    # Title cards
    run([GODOT, "--path", ROOT, "--windowed", "--resolution", "1920x1080", "--", f"--cards={TMP}"])
    for name, secs in CARD_SECONDS.items():
        run(["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-i", TMP / f"{name}.png", "-t", str(secs),
             "-vf", f"scale=1920:1080,fade=in:0:12,fade=out:st={secs - 0.5}:d=0.5", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS), TMP / f"{name}.mp4"])
    # Gameplay clips + one screenshot from each
    for i, (name, start, char, frames, extra, shot_at) in enumerate(CLIPS):
        avi = TMP / f"{name}.avi"
        with open(TMP / f"{name}.log", "w") as log:
            subprocess.run([GODOT, "--path", ROOT, "--windowed", "--resolution", "1920x1080", "--write-movie", avi,
                            "--fixed-fps", str(FPS), "--quit-after", str(frames), "--", f"--trailer={start}", f"--char={char}", *extra],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        secs = frames / FPS
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", avi, "-an", "-vf", f"fade=in:0:8,fade=out:st={secs - 0.3}:d=0.3",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS), TMP / f"{name}.mp4"])
        run(["ffmpeg", "-y", "-loglevel", "error", "-ss", str(shot_at), "-i", avi, "-frames:v", "1", shots / f"{i + 1:02d}_{name}.png"])
        avi.unlink()
    (TMP / "list.txt").write_text("".join(f"file '{n}.mp4'\n" for n in ORDER))
    video = TMP / "video.mp4"
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", TMP / "list.txt", "-c", "copy", video])
    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video]).decode())
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", video, "-stream_loop", "-1", "-i", ROOT / "assets" / "audio" / "music_boss.ogg",
         "-t", str(dur), "-af", f"afade=in:0:d=1.5,afade=out:st={dur - 2.5}:d=2.5", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
         "-shortest", ROOT / "store" / "trailer.mp4"])
    print("trailer:", ROOT / "store" / "trailer.mp4", f"{dur:.1f}s")


if __name__ == "__main__":
    main()

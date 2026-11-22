# Your own immich-optimizer image

A template for building a custom image of [immich-optimizer](https://github.com/miguelangel-nubla/immich-optimizer): the official image plus whatever you add. Use it when you need something the official image does not have:

- a driver for your graphics card
- another tool, or another version of one

**If you only want your own tasks, you do not need this.** Mount a folder with your `tasks.yaml` over `/etc/immich-optimizer/config` in the official image, as its [tasks documentation](https://github.com/miguelangel-nubla/immich-optimizer/blob/main/docs/tasks.md) describes. That also covers AMD and NVIDIA cards, whose encoders and driver the official image already has: see [Graphics cards](#graphics-cards) for the task and the compose lines.

You edit two files. GitHub builds the image and publishes it to your own repository; nothing has to be installed on your computer.

## Start

1. Press **Use this template** → **Create a new repository** at the top of this page. (A fork works too; see [Forks](#forks).)
2. In your new repository, open the **Actions** tab. The first build starts by itself and takes a few minutes.
3. Your image is at `ghcr.io/<your-user>/<your-repository>:latest`. Use it in your compose file in place of the official one:

   ```yaml
   services:
     immich-optimizer:
       image: ghcr.io/<your-user>/<your-repository>:latest
   ```

GitHub publishes every new image as private, also from a public repository: a package takes over the repository's access rights, not its visibility. Either make it public (your profile → **Packages** → the package → **Package settings** → **Change visibility**), or log in on your server with `docker login ghcr.io`.

## Change it

| File | What it is |
|---|---|
| [`Dockerfile`](Dockerfile) | what is in the image. Every optional part is commented out and explained there. |
| [`config/tasks.yaml`](config/tasks.yaml) | the tasks your image starts with, so that what you add to the image is used without further setup. It is the official lossless profile, with examples commented out. A folder mounted over `/etc/immich-optimizer/config` still replaces it. |
| `profiles/` (you create it) | your own [profiles](https://github.com/miguelangel-nubla/immich-optimizer/blob/main/docs/library.md#profiles) for library mode, one folder each with a `tasks.yaml`: for the photos you tag `immich-optimizer/convert/<profile>`. Switch on the `profiles/` line in the `Dockerfile`. |

To switch a part on, remove the leading `# ` from its lines and commit. You can do that in the browser: open the file on GitHub, press the pencil, edit, **Commit changes**. Every commit to `main` builds and publishes a new image.

A build that fails publishes nothing: your last working image stays. The log on the **Actions** tab says what went wrong. Before publishing, the build checks that the optimizer starts with your tasks file, which catches most typing mistakes. It does not convert anything, so whether a task does what you want, you see with a real file.

How tasks work is described in the [tasks documentation](https://github.com/miguelangel-nubla/immich-optimizer/blob/main/docs/tasks.md).

## When it is built

- on every commit to `main`
- once a week, so your image picks up updates of the official image
- when you press **Run workflow** on the Actions tab

Each build is published as `:latest` and as `:<commit>`. To go back to an earlier image, use its commit tag.

By default the image is built on the newest official release. To stay on one version, or to use the development branch, change `BASE_IMAGE` at the top of the `Dockerfile`.

## Graphics cards

The official image already has `ffmpeg` with the encoders for NVIDIA and for VAAPI (AMD and Intel), and the open-source VAAPI driver for AMD. Intel needs a driver added in the `Dockerfile`. Beyond that, what is missing is on your side: the container has to be given the card, and a task has to use it.

The examples in `config/tasks.yaml` were written from the documentation of the encoders. **They have not been run on real graphics cards**: check the result of the first conversions.

### Graphics card or CPU

**For the optimizer, the CPU is usually the better choice.** The optimizer is there to save space, and its conversions run in the background, where nobody waits for them. What counts is the size of the result, not how fast it is made.

| | Graphics card (`videos-nvenc-hevc`, `videos-vaapi-hevc`) | CPU (`videos-x265`, `videos-svtav1`) |
|---|---|---|
| Speed | many times faster | slow, AV1 most of all |
| Load on the server | little: the CPU stays free | high while a video is converted |
| Size at the same quality | larger | smaller |
| Settings to tune | few | many |
| Setup | the card in compose, a driver for Intel | none: works in the official image |

- **A larger result often saves nothing.** A result that is not smaller than the original is thrown away and the original is kept. Video from recent phones is already compressed well, so a graphics card's output is more often too large to be used.
- **Use a graphics card** when you convert a lot of video, your CPU cannot keep up, and you accept saving less space for it.
- **To keep the CPU from taking over the server**, limit how many conversions run at once with `IO_TASKS_CONCURRENCY`, or give the container a CPU limit (`cpus:` in compose).

### AMD and Intel (VAAPI)

Give the container the render device, and the group that may use it:

```yaml
services:
  immich-optimizer:
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - "993"        # the "render" group of YOUR server: getent group render | cut -d: -f3
```

- Switch on `videos-vaapi-hevc` in `config/tasks.yaml`.
- AMD needs nothing else.
- Intel graphics of the 5th generation (Broadwell) and newer need the driver block in the `Dockerfile`. It builds for `linux/amd64` only, so remove `linux/arm64` from `PLATFORMS` in [`.github/workflows/build.yml`](.github/workflows/build.yml). Older Intel graphics need the `i965-va-driver` package instead, as described there.
- To see what the card offers: `docker exec <container> vainfo`.
- If the device is not `/dev/dri/renderD128` on your server (`ls /dev/dri`), change it in the task.

### NVIDIA

Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the server, then:

```yaml
services:
  immich-optimizer:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu, video]
```

- Switch on `videos-nvenc-hevc` in `config/tasks.yaml`.
- Nothing has to be added to the `Dockerfile`: the driver comes from the server.

### When the card is not there

A task that cannot reach its card fails, and the next task for that file type takes over. With the tasks file as it comes, that is "store the video as it is". So a missing device costs you the saving, not the upload.

## The temp folder

While a file is converted, up to three copies of it are in the container's `/tmp`. With video that is a lot. By default `/tmp` is on the disk Docker itself uses; to put it elsewhere, mount a folder:

```yaml
services:
  immich-optimizer:
    volumes:
      - /mnt/fast-disk/optimizer-tmp:/tmp
```

A memory-backed `tmpfs` is faster, but several people ran out of memory with it on a first backup full of videos.

## What went wrong for others

Collected from the custom images people built before this template:

- **Changing the base image.** Images moved to Alpine lost HEIC decoding until more packages were added, and images on Debian "sid" broke when two build steps picked up different library versions. This template keeps the official image as its base for that reason.
- **Graphics card images are for `linux/amd64`.** Drop `linux/arm64` from `PLATFORMS` when a block you switch on says so.
- **Tools compiled for one processor** (`-march=...`) crashed on another.
- **HandBrake with NVIDIA or Quick Sync** needs a HandBrake built for it, which Debian's is not. The examples here use `ffmpeg`, whose Debian build has the NVIDIA and VAAPI encoders.

## Forks

A fork of this repository works the same way, with two differences GitHub makes for forks:

- Actions are off until you press **I understand my workflows, go ahead and enable them** on the Actions tab.
- The weekly build does not run in a fork until you have enabled the workflow, and GitHub switches it off again after 60 days without a commit.

To take over later changes of this template, use **Sync fork**. A repository made with **Use this template** has no such button: copy what you want by hand.

## What this is not

It does not build the optimizer itself: the program comes from the official image. To change the program, see the [main repository](https://github.com/miguelangel-nubla/immich-optimizer/blob/main/docs/development.md).

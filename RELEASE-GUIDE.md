# Publish DiskMetrics so people can download it

## Current state

Source has been uploaded to https://github.com/Charan606/disk-metrics . The latest local correction normalizes the project layout and name. The assistant has not committed or pushed corrections. You and your teammate own review and publication; a downloadable app release is still needed.

## 1. Update the existing public repository

Your repository is https://github.com/Charan606/disk-metrics . Keep its existing Git history. The reviewed upload put sources inside TCL/ while the root Makefile expected them at the root. The corrected TCL Challenge source archive has Package.swift, Makefile, Sources, Tests, scripts and documentation together at its root. Include the hidden .github and .gitignore files.

For an existing clone, apply the supplied Disk-Metrics-fix.patch after checking it with git apply --check. Review changes in GitHub Desktop, test on the Mac, and commit and push yourselves. Do not replace the clone's .git folder. The assistant has not committed or pushed these corrections.

## 2. Make real contributions under both accounts

Each person should configure their own Git name and an email associated with their GitHub account (a GitHub-provided no-reply email works). GitHub Desktop exposes this in its Git settings. Do not share account passwords or use someone else's identity.

One person can commit the implementation they reviewed and tested. The other can make a genuine change—such as correcting the setup instructions after testing from a clean clone, adding a useful test, or improving the interface—and commit it using their own identity. Invite the teammate as a collaborator, or use a fork and pull request. Merge real contributions into the default branch. Contributor displays may take time to update; they are not created just by adding a name to the README. Preserve separate real commits if you want each authorship to be visible; do not fabricate contribution history.

## 3. Build the downloadable app on the Mac

In the source folder, run:

```sh
make test
make package
```

Find `dist/DiskMetrics-macOS.zip` in Finder. This is the **app download**. It contains the compiled DiskMetrics.app. The `TCL Challenge.zip` supplied during development contains source code instead; it is not the end-user app download.

If building while running a copy from `dist`, quit that copy first. The normal `make update` workflow installs a separate copy under your personal Applications folder.

## 4. Create a GitHub Release

On the repository page, open **Releases**, choose **Draft a new release**, create a version tag such as `v0.1.0`, and give it a clear title such as `DiskMetrics 0.1 — HackWesTex preview`. Copy the release description from RELEASE-NOTES.md and adjust tested details. Attach `dist/DiskMetrics-macOS.zip` in the release's asset area. Publish the release only after verifying the asset.

GitHub documents attaching compiled programs to releases here: https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

Now share your repository's Releases page. A separate website or App Store listing is not required for a public download.

## 5. What users do

Users download **DiskMetrics-macOS.zip** from the release, extract it, move **DiskMetrics.app** into Applications, and open it. They click its menu-bar icon and **Open dashboard**. They do not run `make` or install Swift to use the binary.

The current release is an Apple Silicon build when built on your Apple Silicon Mac. It targets macOS 13+; verify on the macOS versions you intend to claim. Do not claim Intel support for an arm64-only archive.

Detailed drive-health metrics optionally require smartmontools. Basic monitoring works without that separate executable, with unavailable detail fields honestly labeled.

## 6. Apple signing limitation

Our packaging currently uses **ad-hoc signing**, which is useful for local builds but is not Developer ID signing/notarization. On another Mac, Gatekeeper may block normal opening. Do not advertise a warning-free installation yet.

For people who trust the release, Apple documents the explicit Privacy & Security approval path: https://support.apple.com/en-gb/102445 . Do not tell users to disable Gatekeeper or remove security controls globally.

For a polished public distribution, use an Apple Developer ID Application certificate, hardened runtime and notarization, then staple the ticket and repackage the final app. This needs your team's developer identity and credentials on the Mac; they must not be sent in chat or stored in the repository. Apple's process is here: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution . The current Makefile does not perform this process.

Test the downloaded asset on another Mac, including opening it, menu-bar access, report export and notifications. A successful build alone does not prove successful distribution.

## 7. Future updates

For your team: keep one cloned source folder. After teammates push changes, `make sync` pulls and installs the new build. It stops instead of discarding conflicting local edits. `make update` rebuilds from local changes without pulling.

For ordinary downloaders: publish a new release and have them replace the app with that version. There is no automatic internet updater in this project yet. Saved alerts are kept separately from the app bundle.

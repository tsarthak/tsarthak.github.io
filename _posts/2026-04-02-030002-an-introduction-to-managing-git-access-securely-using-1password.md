---
title: "An introduction to managing git access securely using 1Password"
date: 2026-04-02 03:02:00 -0400
categories: [Developer Tools]
tags: [git, ssh, 1password, security, github]
toc: true
---

Most developers have SSH keys sitting as plain files in `~/.ssh/`. If you've ever run `ssh-keygen` and hit enter through the prompts without a passphrase, you have unencrypted private keys on disk. Anyone (or any process) with read access to your home directory can silently copy them.

[1Password for SSH & Git](https://developer.1password.com/docs/ssh/) solves this by making 1Password the single source of truth for your SSH keys. Private keys never touch the filesystem — they stay encrypted inside 1Password, and authentication happens through a built-in SSH agent that prompts for biometric confirmation (Touch ID, Windows Hello) before signing anything.

This post walks through the initial setup. A follow-up post covers [managing multiple Git accounts](/posts/managing-multiple-git-accounts-securely-using-1password/) on the same machine.

## What you get

- **Key generation and storage** — create Ed25519 or RSA keys directly in 1Password. No more `ssh-keygen`.
- **SSH agent** — 1Password runs a background agent that provides keys to SSH clients on demand, with explicit authorization per-application.
- **Public key autofill** — the browser extension can fill your public key on GitHub, GitLab, Bitbucket, and other platforms.
- **Git commit signing** — sign commits with SSH keys (Git 2.34+), verified on GitHub/GitLab without needing GPG.
- **Biometric auth** — every key usage is gated behind Touch ID, Windows Hello, or your account password.

## Prerequisites

- A [1Password account](https://1password.com/pricing/password-manager)
- The 1Password desktop app ([Mac](https://1password.com/downloads/mac) / [Windows](https://1password.com/downloads/windows) / [Linux](https://1password.com/downloads/linux))
- The [1Password browser extension](https://1password.com/downloads/browser-extension) (optional, for public key autofill)
- Git 2.34+ (for commit signing)

## Step 1: Generate an SSH key in 1Password

1. Open 1Password and navigate to your **Personal** (or **Private** / **Employee**) vault
2. Select **New Item** → **SSH Key**
3. Select **Add Private Key** → **Generate New Key**
4. Choose **Ed25519** (recommended — faster and more secure than RSA)
5. Give it a descriptive name (e.g., "GitHub - personal") and **Save**

1Password generates the private key, public key, and fingerprint as a single item.

> **Already have keys?** You can import existing keys from `~/.ssh/` — select **Import a Key File** instead of generating. If the key has a passphrase, you'll enter it once during import. After that, 1Password manages encryption.
{: .prompt-tip }

### Supported key types

| Type        | Bits               | Notes                                                        |
| ----------- | ------------------ | ------------------------------------------------------------ |
| **Ed25519** | 256                | Recommended. Fast, secure, compact. Default in 1Password.    |
| **RSA**     | 2048 / 3072 / 4096 | Wider compatibility with older servers. Slower than Ed25519. |

DSA and ECDSA keys are **not supported**.

## Step 2: Upload your public key to GitHub (or other platform)

You need to register your public key with the Git platform so it can verify your identity.

### With the browser extension (easiest)

1. Go to [GitHub SSH key settings](https://github.com/settings/ssh/new)
2. Click the **Key** field — 1Password will offer your SSH keys
3. Select the key you just created — it auto-fills the title and public key
4. Click **Add SSH Key**

### Without the browser extension

1. Open the SSH key item in 1Password
2. Copy the public key from the item
3. Paste it into the GitHub settings page

> This also works for [GitLab](https://gitlab.com/-/user_settings/ssh_keys), [Bitbucket](https://bitbucket.org/account/settings/ssh-keys/), [Azure DevOps](https://dev.azure.com), and [many other platforms](https://developer.1password.com/docs/ssh/public-key-autofill/).
{: .prompt-info }

## Step 3: Enable the 1Password SSH agent

The agent runs in the background and handles SSH authentication without exposing private keys.

### macOS

1. Open 1Password → **Settings** (⌘,) → **Developer**
2. Click **Set Up SSH Agent**
3. Optionally enable **Display key names when authorizing connections**

To keep the agent running even when the app is closed:

- **Settings** → **General** → enable **Keep 1Password in the menu bar** and **Start at login**

### Windows

1. Open 1Password → **Settings** → **Developer**
2. Enable **Use the SSH agent**

The Windows agent uses the named pipe `\\.\pipe\openssh-ssh-agent` — no `SSH_AUTH_SOCK` configuration needed.

### Linux

1. Open 1Password → **Settings** → **Developer**
2. Enable **Use the SSH agent**

## Step 4: Configure your SSH client

After enabling the agent, your SSH client needs to know where to find it. There are two ways — an environment variable or an SSH config entry. **The environment variable is the recommended approach** because it works globally and keeps `~/.ssh/config` free for per-host overrides (which you'll want if you later manage [multiple Git identities](/posts/managing-multiple-git-accounts-securely-using-1password/)).

### macOS

#### Option A: Environment variable (recommended)

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```shell
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

> **Tip:** You can create a symlink for a shorter path:
>
> ```shell
> mkdir -p ~/.1password && ln -s ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
> ```
>
> Then use `export SSH_AUTH_SOCK=~/.1password/agent.sock` instead.
{: .prompt-tip }

#### Option B: SSH config

Add to `~/.ssh/config`:

```config
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

> If you plan to set up multiple Git identities later, prefer Option A. The multi-account setup uses per-host blocks in `~/.ssh/config`, and having a `Host *` with `IdentityAgent` there can create a conflict.
{: .prompt-info }

### Windows

No configuration needed — 1Password automatically registers as the SSH agent via the standard Windows named pipe.

### Linux

#### Option A: Environment variable (recommended)

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```shell
export SSH_AUTH_SOCK=~/.1password/agent.sock
```

#### Option B: SSH config

Add to `~/.ssh/config`:

```config
Host *
  IdentityAgent ~/.1password/agent.sock
```

## Step 5: Verify the setup

Check that the agent is serving your keys:

```shell
ssh-add -l
```

Expected output:

```pub
256 SHA256:xxxx... GitHub - personal (ED25519)
```

If you see `Error connecting to agent: No such file or directory`, the socket path is wrong. If you see `The agent has no identities`, the SSH agent isn't enabled in 1Password settings.

Test the connection:

```shell
ssh -T git@github.com
```

1Password will prompt for biometric auth (Touch ID / Windows Hello), then you should see:

```shell
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

## Step 6: Set up Git commit signing (optional but recommended)

Git 2.34+ supports signing commits with SSH keys — no GPG required.

### Automatic setup (easiest)

1. Open the SSH key item in 1Password
2. Select **⋯** → **Configure Commit Signing**
3. Click **Edit Automatically**

This adds the following to your `~/.gitconfig`:

```ini
[gpg]
  format = ssh

[user]
  signingkey = ssh-ed25519 AAAA... # your public key

[commit]
  gpgsign = true

[gpg "ssh"]
  program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
```

### Register your signing key on GitHub

1. Go to [GitHub SSH key settings](https://github.com/settings/ssh/new)
2. Set **Key type** to **Signing Key**
3. Fill in your public key (use the browser extension or copy/paste)

After this, your commits will show the **Verified** badge on GitHub.

## The six-key limit

OpenSSH servers default to allowing only 6 authentication attempts per connection (`MaxAuthTries`). If you have more than 6 keys in 1Password, SSH may fail with `Too many authentication failures` before trying the right key.

**Fix:** Specify which key to use per host in `~/.ssh/config`:

```config
Host github.com
  IdentityFile ~/.ssh/github-personal.pub
  IdentitiesOnly yes
```

The `IdentityFile` points to a **public key file** on disk (download it from 1Password). The private key stays in 1Password — SSH just uses the public key to know which identity to offer.

## What's next

Once you have the basics working, check out [managing multiple Git accounts](/posts/managing-multiple-git-accounts-securely-using-1password/) to set up per-account SSH keys for personal and work GitHub accounts on the same machine.

## References

- [1Password SSH & Git — Overview](https://developer.1password.com/docs/ssh/)
- [Get started with 1Password SSH](https://developer.1password.com/docs/ssh/get-started)
- [Manage SSH keys in 1Password](https://developer.1password.com/docs/ssh/manage-keys)
- [Autofill public keys](https://developer.1password.com/docs/ssh/public-key-autofill)
- [Git commit signing with SSH](https://developer.1password.com/docs/ssh/git-commit-signing)
- [1Password SSH Agent](https://developer.1password.com/docs/ssh/agent/)
- [Advanced SSH agent use cases](https://developer.1password.com/docs/ssh/agent/advanced)
- [SSH agent configuration file](https://developer.1password.com/docs/ssh/agent/config/)
- [SSH client compatibility](https://developer.1password.com/docs/ssh/agent/compatibility/)
- [1Password SSH agent security model](https://developer.1password.com/docs/ssh/agent/security/)
- [GitHub — About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)

---
title: "Managing multiple git accounts securely using 1Password"
date: 2026-04-02 04:00:00 -0400
categories: [Developer Tools]
tags: [git, ssh, 1password, github, productivity]
toc: true
---

If you work with multiple GitHub accounts  -  say, a personal account and a work account  -  on the same machine, you've probably run into the problem where `git` always authenticates as the same identity. This post covers how to set up per-account SSH keys managed by 1Password, so each Git remote authenticates with the right identity automatically.

> This post assumes you already have 1Password's SSH agent set up. If not, start with the [introduction to managing Git access securely using 1Password](/posts/an-introduction-to-managing-git-access-securely-using-1password/) first.
{: .prompt-info }

## How it works

GitHub uses SSH public key authentication to identify users. Every SSH connection to `github.com` uses the same `git` user, but GitHub differentiates accounts by which SSH key is presented. The trick is:

1. Store a separate SSH key in 1Password for each GitHub account
2. Create an SSH host alias in `~/.ssh/config` for each identity, pointing to the right public key
3. Tell SSH to use 1Password's agent (which holds the private keys) instead of the system default agent
4. Clone and interact with repos using the alias instead of `github.com`

The public key in `~/.ssh/` tells SSH _which identity to offer_. The private key never leaves 1Password - the 1Password SSH agent signs the challenge on its behalf.

## Prerequisites

- [1Password](https://1password.com/) with the desktop app installed
- SSH keys already created and stored in 1Password for each GitHub account
- Each public key added to the respective GitHub account under **Settings -> SSH and GPG keys**

## Step 1: Download public keys from 1Password

For each GitHub account:

1. Open 1Password and find the SSH Key item
2. Click the **down arrow** next to the public key field -> **Download**
3. Save the file to `~/.ssh/`, using a descriptive name

```shell
~/.ssh/personal.pub
~/.ssh/work.pub
```

The private key stays in 1Password - you only need the `.pub` file on disk.

## Step 2: Configure SSH host aliases

Edit `~/.ssh/config` (create it if it doesn't exist) and add a `Host` block for each identity:

```config
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/personal.pub
  IdentitiesOnly yes

Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/work.pub
  IdentitiesOnly yes
```

- **`Host`** - the alias you'll use in Git URLs (can be anything)
- **`HostName`** - the actual host to connect to (`github.com` for both)
- **`User git`** - always `git` for GitHub, regardless of your GitHub username
- **`IdentityFile`** - path to the downloaded `.pub` file
- **`IdentitiesOnly yes`** - prevents SSH from trying other keys in the agent

## Step 3: Point `SSH_AUTH_SOCK` to 1Password's agent

By default, macOS uses its own SSH agent. You need to override this to use 1Password's agent, which is the one that actually holds your private keys.

Find your 1Password agent socket:

```shell
find ~/Library/Group\ Containers -name "agent.sock"
```

You should see something like:

```shell
/Users/you/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

Add this to your `~/.zshrc` (or `~/.bashrc`):

```shell
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

Then reload your shell:

```shell
source ~/.zshrc
```

> **Common pitfall:** The folder prefix is `2BUA8C4S2C` - double-check it carefully. A typo here will silently point to a non-existent socket and you will get `Error connecting to agent: No such file or directory`.

## Step 4: Enable the SSH agent in 1Password

In the 1Password desktop app navigate to **Settings -> Developer** and toggle on **Enable the SSH agent**.

Without this, the socket exists but 1Password will not respond to SSH authentication requests.

## Step 5: Verify everything is wired up

```shell
ssh-add -l
```

You should see all your 1Password SSH keys listed:

```shell
256 SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx GitHub - personal (ED25519)
256 SHA256:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy GitHub - work (ED25519)
```

If you see `Error connecting to agent: No such file or directory`, the `SSH_AUTH_SOCK` path is wrong. If you see `The agent has no identities`, the 1Password SSH agent isn't enabled.

Test each alias:

```shell
ssh -T git@github-personal
# Hi personal-username! You've successfully authenticated...

ssh -T git@github-work
# Hi work-username! You've successfully authenticated...
```

## Step 6: Clone using the host alias

Instead of `git@github.com:username/repo.git`, use your alias:

```shell
# Personal account
git clone git@github-personal:personal-username/repo.git

# Work account
git clone git@github-work:work-org/repo.git
```

The SSH host alias is a drop-in replacement for `github.com` in any Git URL.

## Updating existing repositories

For repos you already have cloned, update the remote URL:

```shell
git remote set-url origin git@github-work:work-org/existing-repo.git
```

Verify it:

```shell
git remote -v
```

## Setting per-repo Git identity

SSH handles authentication, but commit authorship is separate. Set the right name and email per repo so commits are attributed correctly:

```shell
# Inside a work repo
git config user.name "Your Name"
git config user.email "you@work.com"
```

Or set a global default and override per repo as needed:

```shell
# Global default (personal)
git config --global user.name "Your Name"
git config --global user.email "you@personal.com"

# Override in a specific repo
cd ~/work/some-repo
git config user.name "Your Name"
git config user.email "you@work.com"
```

## Summary

| Step                          | What it does                             |
| ----------------------------- | ---------------------------------------- |
| Download `.pub` files         | Tells SSH which key to offer per alias   |
| `~/.ssh/config` host aliases  | Maps an alias to a real host + key       |
| `SSH_AUTH_SOCK` override      | Routes authentication through 1Password  |
| Enable SSH agent in 1Password | Allows 1Password to sign SSH challenges  |
| Use alias in Git URLs         | Ensures the right key is used per remote |

The private keys never touch the filesystem - 1Password holds them and prompts for biometric or passphrase confirmation when needed. Clean, secure, and once set up, completely transparent.

## Debugging

If things aren't working, these are the most common issues:

**`SSH_AUTH_SOCK` not set correctly:**

```shell
echo $SSH_AUTH_SOCK
# Should point to 1Password's agent socket
```

**Verbose SSH output** — use `-v` to see which keys are being offered:

```shell
ssh -vT git@github-personal
```

Look for lines like `Offering public key` to confirm the right key is being tried.

**Agent not responding:**

```shell
ssh-add -l
# Should list your 1Password SSH keys
```

If you see `Error connecting to agent`, check the socket path. If you see `The agent has no identities`, enable the SSH agent in 1Password → Settings → Developer.

**`Too many authentication failures`** — you have more than 6 keys in 1Password. Make sure `IdentitiesOnly yes` is set in each `Host` block to prevent SSH from trying all keys.

Set `SSH_AUTH_SOCK` and use verbose mode together to diagnose step-by-step:

```shell
SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ssh -vT git@github-personal
```

## References

- [1Password SSH & Git — Overview](https://developer.1password.com/docs/ssh/)
- [1Password SSH Agent — Advanced use cases](https://developer.1password.com/docs/ssh/agent/advanced) — the primary source for multi-identity setup
- [SSH agent configuration file](https://developer.1password.com/docs/ssh/agent/config/) — for controlling which vaults/keys the agent offers
- [SSH client compatibility](https://developer.1password.com/docs/ssh/agent/compatibility/)
- [Git commit signing with SSH](https://developer.1password.com/docs/ssh/git-commit-signing) — sign commits per-identity
- [1Password SSH agent security model](https://developer.1password.com/docs/ssh/agent/security/)
- [Introduction to managing Git access with 1Password](/posts/an-introduction-to-managing-git-access-securely-using-1password/) — prerequisite setup guide

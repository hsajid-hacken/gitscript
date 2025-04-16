# 🔍 Git Fork Diff Analyzer (Cross-Repo)

A bash script to analyze and compare a forked or manually copied Git repository with its official source. Ideal for auditors and developers who want to:

- Detect the fork point (common ancestor commit)
- Compare changes between custom and original codebases
- Measure divergence and customizations
- Handle manual copies with no Git history

---

## ✨ Features

- ✅ Detects shared Git history (fork point)
- 🧱 Handles manual copies without common commits
- 📊 Summarizes file-level diffs (insertions/deletions)
- 📝 Exports a clean audit report (`diff_summary_*.txt`)
- 🧹 Cleans up temporary checkouts

---
## 🚀 User Manual Google drive link

https://docs.google.com/document/d/19EFoPPGdo9VfNJkv_hk9xIrXX651Zi1tQstoIfekNx4/edit?tab=t.0

## 🚀 Getting Started

### Requirements

- Bash shell (Unix/macOS/Linux)
- Git installed (`git --version`)
- Repos cloned locally
- SSH access (if using private repos)

### Make the script executable

```bash
chmod +x git-diff.sh


---
marp: true
theme: vibe
paginate: true
title: Show your Claude Certifications
---

<!-- _paginate: false -->

# Show your Claude Certifications 🎓

Earned **Claude 101** or **Claude Code 101**?
Add them to your builder profile — they light up as **amber badges** on your card at **vibecode.tours**.

> Optional. Only add a cert you actually earned — each badge links to your public Skilljar verification.

---

## How to add (English)

1. Open your builder file: `src/content/builders/<your-github>.md`
2. Add a **`certs:`** block in the frontmatter — keys **indented under `certs:`**, not at the top level.

```yaml
certs:
  claude_101: https://verify.skilljar.com/c/XXXXXXXX
  claude_code_101: https://verify.skilljar.com/c/YYYYYYYY
```

3. Commit, push to your fork, open a Pull Request.

**We recommend the full verify URL** (badge links to your proof). The bare Skilljar code also works.

---

## How to add (မြန်မာ)

1. သင့် builder file ဖွင့်ပါ: `src/content/builders/<သင့်-github>.md`
2. Frontmatter ထဲမှာ **`certs:`** block ထည့်ပါ — key တွေ **`certs:` အောက်မှာ indent** ထားရမယ်၊ top level မှာ မထားရ။

```yaml
certs:
  claude_101: https://verify.skilljar.com/c/XXXXXXXX
  claude_code_101: https://verify.skilljar.com/c/YYYYYYYY
```

3. Commit လုပ်ပြီး fork ကို push၊ Pull Request ဖွင့်ပါ။

**verify URL အပြည့် သုံးဖို့ အကြံပြုတယ်**။ bare code လည်း ရတယ်။

---

## What it looks like

![w:380](assets/claude_certs_git.png) ![w:340](assets/claude_certs_web.png)

**Left:** the `certs:` block in your profile `.md`.
**Right:** your card on vibecode.tours — earned = amber, next 2 = grey targets. 🌟

---

## ⚠️ Common mistake

Putting `claude_101:` at the **top level** instead of under `certs:`.
It silently won't show.

✅ Always **nest under `certs:`**. The CI check now warns you if you slip.

**Known ids:** `claude_101` · `claude_code_101` · `mcp_intro` · `agent_skills_intro` · `subagents_intro` · `claude_code_in_action` · `building_claude_api`

Stuck? Ask in **#setup-help**.

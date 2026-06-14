# Cohort Announcements — Chapter 0 & 1

Copy-paste blocks (English + မြန်မာ) for the #announcements channel. Posted via
`/announce` (Discord + Telegram) or the webhook. Guide: https://github.com/vibe-code-tours/vibecode-setup

---

## Chapter 0 — Setup

**English**

🎓 **Chapter 0 — Setup**
1. Install tools (one command):
   `curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/student-setup.sh | bash`
2. Log in to GitHub: `gh auth login`
3. Run the self-check & make your badge: `bash doctor.sh`
4. Drop the PNG (from `~/.vibecode/doctor/`) in #ch-0-intro
5. A mentor reacts 👏 → you earn 🌱 ch-0-done → #ch-1 unlocks

📖 Guide: https://github.com/vibe-code-tours/vibecode-setup · Stuck? #setup-help

**မြန်မာ**

🎓 **Chapter 0 — Setup (ပြင်ဆင်ခြင်း)**
1. Tools install (command တစ်ကြောင်းတည်း):
   `curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/student-setup.sh | bash`
2. GitHub ဝင်ပါ: `gh auth login`
3. Self-check လုပ်ပြီး badge ထုတ်ပါ: `bash doctor.sh`
4. PNG (`~/.vibecode/doctor/` ထဲက) ကို #ch-0-intro မှာ တင်ပါ
5. Mentor က 👏 ပေးရင် → 🌱 ch-0-done ရပြီး → #ch-1 ပွင့်မယ်

📖 လမ်းညွှန်: https://github.com/vibe-code-tours/vibecode-setup · ပြဿနာတက်ရင် #setup-help

---

## Chapter 1 — First Commit

**English**

🔧 **Chapter 1 — First Commit**
Do these on GitHub first:
• Profile repo `github.com/<you>/<you>` (with a README)
• A Pull Request to `vibe-code-tours/vibe-code-tours.github.io`

Then:
1. `bash doctor.sh ch-1` → posts a public gist when all checks pass
2. In Discord: paste the gist link in #ch-1 (or `/submit`)
3. Mentor reacts 👏 → you earn 🔧 ch-1-done

⚠️ Your gh token needs the `gist` scope (browser login includes it).
📖 Guide: https://github.com/vibe-code-tours/vibecode-setup · Stuck? #ch-1

**မြန်မာ**

🔧 **Chapter 1 — First Commit (ပထမဆုံး commit)**
GitHub မှာ အရင်လုပ်ထားရမယ်:
• Profile repo `github.com/<သင့်နာမည်>/<သင့်နာမည်>` (README ပါရမယ်)
• `vibe-code-tours/vibe-code-tours.github.io` ကို Pull Request တစ်ခု

ပြီးရင်:
1. `bash doctor.sh ch-1` → check အကုန်အောင်ရင် gist (public) တင်ပေးမယ်
2. Discord #ch-1 မှာ gist link ကို paste လုပ်ပါ (သို့) `/submit`
3. Mentor က 👏 ပေးရင် → 🔧 ch-1-done ရမယ်

⚠️ gh token မှာ `gist` scope လိုတယ် (browser login လုပ်ရင် ပါပြီးသား)။
📖 လမ်းညွှန်: https://github.com/vibe-code-tours/vibecode-setup · ပြဿနာတက်ရင် #ch-1

---

## Claude Certifications — show your badges

**English**

🎓 **Earned Claude 101 or Claude Code 101?** Put them on your builder card.

Add a `certs:` block to your profile (`src/content/builders/<you>.md`):
```yaml
certs:
  claude_101: https://verify.skilljar.com/c/XXXXXXXX
  claude_code_101: https://verify.skilljar.com/c/YYYYYYYY
```
We recommend the full verify URL (optional). Earned = amber badge, linked to
your proof. ⚠️ Keys go **under** `certs:` — top level won't show.

📖 Full guide (with pictures): https://github.com/vibe-code-tours/vibecode-setup/blob/main/CERTS.md · Stuck? #setup-help

**မြန်မာ**

🎓 **Claude 101 / Claude Code 101 ပြီးပြီလား?** သင့် builder card မှာ ပြပါ။

Profile (`src/content/builders/<you>.md`) မှာ `certs:` block ထည့်ပါ:
```yaml
certs:
  claude_101: https://verify.skilljar.com/c/XXXXXXXX
  claude_code_101: https://verify.skilljar.com/c/YYYYYYYY
```
verify URL အပြည့် သုံးဖို့ အကြံပြုတယ် (optional)။ ရထားရင် amber badge ဖြစ်ပြီး proof
ကို link ဖြစ်မယ်။ ⚠️ key တွေက `certs:` **အောက်မှာ** ထားရမယ် — top level မှာ မပေါ်ဘူး။

📖 လမ်းညွှန် အပြည့် (ပုံနဲ့): https://github.com/vibe-code-tours/vibecode-setup/blob/main/CERTS.md · ပြဿနာတက်ရင် #setup-help

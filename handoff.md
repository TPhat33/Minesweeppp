# Handoff — Minesweeppp

เอกสารส่งต่องานสำหรับ agent ที่รับช่วงทำงานต่อในเครื่อง local
เขียนขึ้น ณ 2026-09-27 หลังจบรอบ Feature A + B ของ `docs/OCTALYSIS_PLAN.md`
บวกกับ hotfix หนึ่งจุดที่ผู้ใช้แจ้งเพิ่มระหว่างทาง

อ่านคู่กับ:
- `docs/DESIGN.md` — ทำไมเกมถึงออกแบบมาแบบนี้ (กติกา, ค่าคงที่, เหตุผลของแต่ละค่า)
- `docs/OCTALYSIS_PLAN.md` — แผนฟีเจอร์ทั้งหมด, สิ่งที่ทำไปแล้ว (§3), สิ่งที่ยังไม่ทำ (§4),
  และ**สิ่งที่ตั้งใจไม่ทำ** (§5) — อย่าเสนอของในหมวดนั้นซ้ำโดยไม่อ่านเหตุผลก่อน

---

## 1. สถานะ repo ตอนนี้

| อะไร | ค่า |
| --- | --- |
| Repo | `TPhat33/minesweeppp` (GitHub) |
| Branch สำหรับพัฒนาต่อ | `main` — ใช้ branch นี้ตลอดตั้งแต่ 2026-09-27 เป็นต้นไป (เดิมใช้ `claude/minesweeper-flutter-flame-ne3n6l` แต่เลิกใช้แล้ว) |
| `claude/minesweeper-flutter-flame-ne3n6l` | branch เก่าที่เคยเป็น default/dev branch — ยังอยู่บน GitHub เป็นประวัติ ไม่ต้องใช้งานต่อ อย่า push เข้า branch นี้อีก |
| Default branch บน GitHub | **ต้องเปลี่ยนเป็น `main` ด้วยมือ** — GitHub MCP tools ที่มีในเซสชันนี้ไม่มีตัวไหนแก้ repo setting นี้ได้ (ไม่มี "update repository" / admin API) เจ้าของ repo ต้องเข้า Settings → Branches → Default branch → เปลี่ยนเป็น `main` เอง ที่ https://github.com/TPhat33/Minesweeppp/settings/branches |
| Commit ล่าสุด | `3078a3b` — "docs: add handoff notes for the local agent picking up this work" (`main` และ `claude/minesweeper-flutter-flame-ne3n6l` ชี้ commit เดียวกันตอนนี้) |
| Deploy จริง | https://tphat33.github.io/Minesweeppp/ ผ่าน GitHub Actions (`.github/workflows/deploy-web.yml`) |
| **Deploy trigger** | แก้แล้วให้ยิงตอน push เข้า **`main`** (`on.push.branches: [main]`) — เดิมยิงจาก `claude/minesweeper-flutter-flame-ne3n6l` เท่านั้น เปลี่ยนพร้อมกับการย้ายมาใช้ `main` เป็นหลัก ถ้า push เข้า branch เก่าต่อไปจะไม่ deploy อะไรเลย |
| Test suite | 154 tests, `flutter test` ผ่านหมด, `flutter analyze` สะอาด (เช็กล่าสุดวันนี้) |
| Flutter version (pin ใน CI) | `3.47.5` stable (`subosito/flutter-action@v2`) |

Working tree สะอาด ไม่มี uncommitted changes ณ ตอนเขียนเอกสารนี้

---

## 2. งานที่ทำเสร็จแล้วในรอบนี้

### Feature A — Salvage Chain (commit `3429c61`)
ลูกโซ่การเก็บกู้: ชุดที่เก็บกู้ติดกันโดยขนาดไม่ลดลงจะต่อลูกโซ่ ยิ่งยาวยิ่งได้โบนัสต่อลูกมากขึ้น
รายละเอียดกติกา/ค่าคงที่/ไฟล์ที่แก้ทั้งหมด อยู่ที่ `docs/OCTALYSIS_PLAN.md` §3.1
เทสต์ครอบคลุมทั้ง `chainBonus()`, `chainAtRisk`, การ round-trip ผ่าน `toJson`/`fromJson`,
และการปฏิเสธเซฟเก่าที่ `rulesVersion: 1` (bump เป็น 2 แล้วเพราะกติกาคะแนนเปลี่ยน)

### Feature B — Board Log & Rival Score (commit `49bea99`)
จำผลงานแยกรายกระดาน (คีย์ = รหัสด่าน) ปักหมุดได้ ใส่คะแนนคู่แข่งได้ พร้อมหน้า Records/Boards
ไฟล์ใหม่หลัก: `lib/core/models/board_record.dart`, ส่วนต่อขยายใน `player_store.dart`,
`hud_bar.dart`, `result_sheet.dart`, `home_screen.dart`, `stats_screen.dart`
รายละเอียดเต็มอยู่ที่ `docs/OCTALYSIS_PLAN.md` §3.2

### Hotfix — Tap-to-start cover (commit `d330c9f`, ไม่ได้อยู่ในแผน Octalysis)
ผู้ใช้แจ้งว่ากดปุ่ม Start Run แล้วเจอกระดานที่เปิดไปแล้วบางส่วนพร้อมคะแนนทันที
(พฤติกรรมเดิมนี้ถูกต้องตามที่ตั้งใจไว้ — ดู `docs/DESIGN.md` บรรทัด 102 — ช่องเปิดแรกถูกกันไม่ให้มีระเบิด
ใน 3×3 รอบตัวเสมอ จึงเปิดเป็นพื้นที่กว้าง ไม่ใช่บั๊ก) แต่ผู้ใช้ขอเปลี่ยนดีไซน์ให้ผู้เล่นเริ่มเองจาก 0 จริง ๆ

วิธีแก้: เพิ่ม `GameScreen.showStartCover` (bool) + widget `_StartCover` ที่บังเต็มจอ
จนกว่าผู้เล่นจะแตะเอง และ `GameSession.hold()`/`release()` ที่กันไม่ให้นาฬิกาเดินระหว่างนั้น
ตั้งใจทำเป็น presentation-layer ล้วน ๆ ไม่แตะ `MinesweeperEngine` เลยเพื่อไม่เสี่ยงกับ
คำสัญญา "ไม่ต้องเดา" — ดูโค้ดที่ `lib/ui/screens/game_screen.dart` และ `lib/game/game_session.dart`

---

## 3. ⚠️ เรื่องค้างที่ยังไม่ยืนยันว่าจบ — สำคัญที่สุด

หลัง deploy hotfix ข้างบนสำเร็จ (GitHub Actions run `35443938533` = success) ผู้ใช้ทดสอบบน
iPhone จริงแล้ว**ยังเจอพฤติกรรมเดิม** (กระดานเปิดมาเลย ไม่มีหน้า "TAP TO START")

**สมมติฐานหลักที่ยังไม่ถูกยืนยัน**: `main.dart.js` และไฟล์ build อื่น ๆ ของ Flutter web
**ไม่มี content hash ต่อ build** (ชื่อไฟล์เดิมทุกครั้งที่ deploy) ทำให้ Safari บน iOS
มีโอกาสสูงที่จะ cache bundle เก่าค้างไว้ข้ามการ deploy — ได้ให้ผู้ใช้ลองสองวิธีแล้ว
(เปิด Private Tab ทดสอบ, ลบ Website Data ของ `tphat33.github.io`) แต่ **ยังไม่ได้รับการยืนยันผลกลับ**
ว่าทำแล้วหายหรือไม่

**สิ่งที่ agent ที่รับช่วงต่อควรทำ**:
1. ถ้าผู้ใช้ยืนยันว่าเป็นแค่ cache (ลอง Private Tab แล้วเจอ cover ถูกต้อง) — เรื่องนี้ปิดได้เลย
   ไม่ต้องแก้โค้ดอะไรเพิ่ม
2. ถ้ายังไม่หายแม้ลบ cache แล้วจริง ๆ — นั่นคือบั๊กจริงที่ verification ในเครื่อง (local rebuild
   + Playwright) ไม่จับได้ ต้องขุดลึกกว่านั้น (เช่น diff ระหว่าง build output ที่ deploy จริงกับที่ build local,
   หรือพฤติกรรม iOS Safari WebView ที่ต่างจาก headless Chromium)
3. **แนวทางป้องกันปัญหานี้ซ้ำในอนาคตที่ยังไม่ได้ทำ**: พิจารณาเพิ่ม cache-busting ให้ `deploy-web.yml`
   เช่น ตั้ง `Cache-Control` header ผ่าน GitHub Pages (มีข้อจำกัดว่ากำหนดเองไม่ได้ตรง ๆ)
   หรือให้ Flutter build ด้วย `--pwa-strategy=none` แล้ว fetch ใหม่ทุกครั้งแทน service worker เดิม
   ยังไม่ได้ตัดสินใจว่าจะทำแนวไหน — เป็นเรื่องที่คุยกับผู้ใช้ก่อนได้ถ้าจะเสนอ

---

## 4. งานถัดไปตามแผน (`docs/OCTALYSIS_PLAN.md` §4)

เรียงลำดับความสำคัญตามที่เอกสารแผนกำหนดไว้ (มีเหตุผลว่าทำไมต้องเรียงแบบนี้ อยู่ในเอกสารนั้น):

1. **E — Classic Par Line** (#6 Scarcity) — แถบเทียบเวลากับ `parSeconds` ในโหมด Classic
   **ต้องทำหลังคะแนนจาก Feature A นิ่งแล้ว** เพราะ A ทำให้สมดุลคะแนนขยับอยู่แล้ว
   และควรวัด `parSeconds` ทั้งห้าค่าจาก `RunStats.bestTimeSeconds` ที่สะสมจริงก่อนตั้งเส้น
2. **D — Field Report** (#1 Epic Meaning, #7 Unpredictability) — โชว์ว่าตัวแก้ต้องใช้การไล่
   ความเป็นไปได้หรือกฎนับตรง ๆ กว่าจะแก้กระดานนี้ได้ งานเดินสายข้อมูลที่มีอยู่แล้วเกือบล้วน ๆ
   (`SolveReport`, `GeneratedBoard.attempts/elapsed`) เสี่ยงต่ำ
3. **C — Seeded Contracts** (#7, #2) — "สัญญา" ต่อกระดานที่สุ่มจาก seed เอง
   ต้องทำหลัง A เพราะสัญญาที่น่าสนใจครึ่งหนึ่งอ้างอิงลูกโซ่ ไฟล์ใหม่ `lib/core/engine/contract.dart`
   ใช้ `DeterministicRandom` เท่านั้น ห้าม `dart:math`
4. **Salvage Ranks** (#2 Accomplishment) — บันไดยศจาก `RunStats.minesSalvaged`
   อยู่ท้ายสุดเพราะทั่วไปที่สุด ไม่ได้ใช้กลไกเก็บกู้เป็นชุดโดยเฉพาะ

**อย่าเสนอซ้ำ** สิ่งที่อยู่ใน §5 ของแผน (โหมดเนื้อเรื่องเต็ม, leaderboard มีเซิร์ฟเวอร์,
daily challenge, streak ข้ามรัน, รางวัลสุ่มที่ไม่ผูก seed, การแตะ `BoardGenerator`/`LogicSolver`
เพื่อความน่าเล่น) — มีเหตุผลเขียนไว้แล้วว่าทำไมถึงไม่ทำ

---

## 5. ข้อจำกัดที่ทุกงานถัดไปต้องเคารพ (ย่อจาก OCTALYSIS_PLAN.md)

| ข้อจำกัด | เหตุผล |
| --- | --- |
| `lib/core/engine/` ห้าม import Flutter หรือ Flame | ต้องเทสต์ตรรกะได้โดยไม่ต้องมี widget |
| ไม่มี backend ไม่มีบัญชีผู้ใช้ | ทุกอย่างอยู่บน `shared_preferences` ผ่าน `PlayerStore` |
| ความสุ่มทุกชนิดต้องผูกกับ seed ผ่าน `DeterministicRandom` | ไม่งั้นรหัสด่านเทียบคะแนนกันไม่ได้ (ห้าม `dart:math` ในโค้ดที่กระทบผลลัพธ์ของเกม) |
| ห้ามทำลายคำสัญญา "ไม่ต้องเดา" | อะไรที่แตะ `BoardGenerator`/`LogicSolver` ต้องมีเหตุผลหนักมาก และต้องมีเทสต์ยืนยัน |
| กติกาคะแนนเปลี่ยน → ต้อง bump `GameRules.rulesVersion` | ของเดิมมี `LevelCode.isCurrentRules` และ `fromJson` คืน `null` จัดการ backward-compat ให้อัตโนมัติอยู่แล้ว ไม่ต้องเขียน migration เอง |
| สถานะใหม่ต้องมี `toJson`/`fromJson` ที่อ่านค่าที่หายไปด้วย `?? ค่าเริ่มต้น` | ตามแบบ `GameSettings`/`RunStats`/`BoardRecord` เดิมทั้งหมด |

---

## 6. Dev loop ที่ใช้งานได้จริงในรอบนี้

**รันเทสต์** (จากรากโปรเจกต์):
```
flutter test                 # 154 tests
flutter analyze              # ต้องสะอาด ไม่มี warning
```

**Widget test gotcha ที่เจอมาแล้วสองรอบ** — ถ้า `find.text()` หาไม่เจอทั้งที่ข้อมูลมีจริง
(ยืนยันด้วย print debug แล้ว) ให้เช็กก่อนว่า `tester.view.physicalSize` สูงพอหรือยัง
`ListView` ธรรมดา (ไม่ใช่ `.builder`) จะ mount แค่ widget ในช่วง viewport + cache extent เท่านั้น
วิธีแก้มาตรฐานในโปรเจกต์นี้: ตั้ง `Size(440, 2400)` ก่อน pump (ดูตัวอย่างใน `home_screen_test.dart`,
`result_sheet_test.dart`, `stats_screen_test.dart`)

**`GameScreen`/`GameSession` test อีกจุด**: ห้ามใช้ `pumpAndSettle()` เพราะ Flame game loop
ไม่มีวันหยุดนิ่ง (สั่ง frame ใหม่ทุกครั้ง) ให้ใช้ pump แบบวนจำกัดจำนวนครั้งแทน (ดู `settleFrames()`
ใน `home_screen_test.dart` / `game_screen_test.dart`)

**Board generation ผ่าน `compute()`** สร้าง isolate จริงบน VM เทสต์ต้องมี
`await tester.runAsync(() => Future.delayed(...))` คั่นก่อนถึงจะรอผลลัพธ์จริงได้
(ดู `waitForRealAsyncWork()` ใน `home_screen_test.dart`)

**ดูเว็บจริงในเครื่องแบบไม่มีมือถือ** (ใช้ตอนตรวจ hotfix นี้):
```
flutter build web --release --no-web-resources-cdn
http-server build/web -p 8080 --silent &
# แล้วขับด้วย Playwright ผ่าน Node ESM script (createRequire import CommonJS playwright)
# Chromium อยู่ที่ /opt/pw-browsers/chromium-1194/chrome-linux/chrome ในสภาพแวดล้อมนี้
```
ข้อควรระวัง: `http-server` อ่านไฟล์จากดิสก์ใหม่ทุก request ไม่มี cache ในตัวมันเอง —
ถ้าผลลัพธ์ยังเก่าอยู่ ให้เช็ก process เก่าที่อาจยังรันค้างอยู่คนละพอร์ต ไม่ใช่ตัว server เอง
ส่วน canvaskit-rendered Flutter web ใช้ DOM locator อย่าง `page.getByText()` ไม่ได้เลย
(ทุกอย่างวาดลง `<canvas>` เดียว) ต้องคลิกด้วยพิกัดจากภาพหน้าจอแทน

---

## 7. ถ้าจะ push งานใหม่

Push เข้า `main` เท่านั้น — เป็น branch เดียวที่ใช้พัฒนาต่อและเป็น branch เดียวที่ทำให้เว็บ
https://tphat33.github.io/Minesweeppp/ อัปเดตอัตโนมัติ (ดูข้อ 1) อย่า push เข้า
`claude/minesweeper-flutter-flame-ne3n6l` อีก — branch นั้นถูกปลดจากหน้าที่ deploy แล้ว
และงานใหม่ที่ push เข้าไปจะไม่ปรากฏบนเว็บจนกว่าจะ merge เข้า `main` เอง

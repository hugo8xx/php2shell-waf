# Cloudflare WAF custom rules

| Rule | Plan ขั้นต่ำ |
|---|---|
| multipart ไปยัง path ที่ไม่ใช่ upload | Free |
| multipart ไม่มี Content-Length / chunked | Free |
| Content-Type multipart ที่ไม่ใช่รูปแบบมาตรฐาน เช่น `multipart/form-data,boundary=x` | Free |
| `PHP_SESSION_UPLOAD_PROGRESS` ใน query / cookie | Free |
| body ≥ 10 MB (ใช้ `matches` regex) | Business |
| ชื่อ field upload progress / nesting ใน body (`http.request.body.raw`) | Enterprise |

Free plan มี custom rule ได้ 5 ข้อ — ชุดนี้ใช้ 4 ข้อ

rule Content-Type แบบเข้มอนุญาตเฉพาะ `multipart/form-data;...boundary=...` (ไม่มีช่องว่างก่อน `;`) เพราะ Free plan ใช้ regex ไม่ได้

## ติดตั้ง

**แบบ dashboard:** Security → WAF → Custom rules → Create rule → Edit expression → copy `expression` จาก [`rules.json`](rules.json) → Action: Block

**แบบ API** (ไม่ลบ rule เดิม, ข้าม rule ที่มีชื่อซ้ำ):

```bash
CF_API_TOKEN=xxx CF_ZONE_ID=xxx CF_PLAN=free ./deploy.sh
```

Token ต้องมีสิทธิ์ `Zone → Zone WAF → Edit` และต้องมี `jq`

## ก่อน deploy

- แก้ path ใน rule แรก (`/upload`, `/wp-admin/...`) ให้ตรงกับ endpoint upload จริงของแอป
- ถ้ามี Enterprise ให้ตั้ง action เป็น `log` ก่อนเพื่อดู false positive

## ข้อจำกัด

- Custom rules **ตรวจ response ไม่ได้** → ไม่มี rule ตรวจ `PHPSESSID` ขาออก
- ต่ำกว่า Enterprise ตรวจ body ไม่ได้ → ต้องตั้ง `session.upload_progress.enabled=0` ที่ origin เสมอ (ดู [`../local-vps/php`](../local-vps/php))
- อย่าลืมปิดการเข้าถึง origin ตรง ๆ (ให้รับเฉพาะ IP ของ Cloudflare) ไม่งั้น attacker ข้าม WAF ได้

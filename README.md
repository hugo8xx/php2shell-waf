# php2shell-waf

Virtual patch / WAF rules สำหรับช่องโหว่ **PHP2Shell**

| CVE | ชื่อ | CVSS 4.0 | Advisory |
|---|---|---|---|
| CVE-2026-109618 | RCE via OOM corruption | 9.2 Critical | [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) |
| CVE-2026-109619 | RCE via stale global state | 9.2 Critical | [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) |

**Affected:** PHP < 8.2.35 / 8.3.36 / 8.4.27 / 8.5.12. RCE แบบไม่ต้อง login และไม่ต้องมีโค้ดแอปที่มีช่องโหว่ (แม้แต่ "Hello World" ก็โดน)

> ⚠️ **WAF ไม่ใช่ทางแก้ที่สมบูรณ์** — ทาง PHP ระบุว่า **อัปเกรด PHP** เป็นทางแก้เดียวที่ครบ
> repo นี้มีไว้ลดความเสี่ยงระหว่างรออัปเกรดเท่านั้น

## ช่องโหว่ทำงานยังไง (สรุป)

- **109618:** ทำให้ PHP หน่วยความจำหมด (OOM) ระหว่างแยก multipart request ตอน request startup → `longjmp()` ทิ้งหน่วยความจำที่ยังไม่ initialize → ใช้ตอน cleanup → RCE
- **109619:** fatal error / OOM ทิ้ง global state ชี้ไปหน่วยความจำที่ free แล้ว → request ถัดไปบน worker เดิมอ่านค่าค้าง (เช่นผ่าน session upload progress) → use-after-free → RCE / memory leak ออกทาง cookie `PHPSESSID`
- **mod_php** = มีการยืนยันแล้วว่าโจมตีได้จริง, **PHP-FPM** = เสี่ยงน้อยกว่าแต่ยังโดนได้

## โครงสร้าง

| โฟลเดอร์ | ใช้กับ | ตรวจ body ได้ |
|---|---|---|
| [`local-vps/`](local-vps/) | VPS ที่ setup เอง: nginx, ModSecurity, php.ini, PHP-FPM, fail2ban | ✅ (ModSecurity) / ❌ (nginx เปล่า) |
| [`cloudflare/`](cloudflare/) | Cloudflare WAF custom rules | Enterprise เท่านั้น |
| [`aws-waf/`](aws-waf/) | AWS WAFv2 (ALB, API Gateway, CloudFront) | ✅ (8–64 KB แรก) |
| [`gcp-cloud-armor/`](gcp-cloud-armor/) | Google Cloud Armor | ❌ |
| [`tests/`](tests/) | สคริปต์ curl ทดสอบทุก platform | — |

## Rule ที่มีในทุก platform

1. block `multipart/form-data` ที่ไม่ได้ส่งไป path สำหรับ upload — **ต้องแก้ allowlist ให้ตรงกับแอปคุณ**
2. block multipart ที่ไม่มี `Content-Length` หรือเป็น `Transfer-Encoding: chunked`
3. block ชื่อ `PHP_SESSION_UPLOAD_PROGRESS` ใน query / cookie (และ body ถ้า platform รองรับ)
4. จำกัดขนาด body (ค่า default 10 MB)
5. (ถ้า platform รองรับ) จำกัดความลึก `a[b][c]...`, จำนวน part/ไฟล์/ตัวแปร, ตรวจ `PHPSESSID` ขาออกที่ยาวผิดปกติ

## ขั้นตอนแนะนำ

1. **อัปเกรด PHP** ถ้าทำได้ — จบ
2. ถ้ายังไม่ได้: ใส่ [`local-vps/php/99-php2shell.ini`](local-vps/php/99-php2shell.ini) (ทำได้ทุก platform ที่คุมเซิร์ฟเวอร์ได้) + restart worker ทุกตัว
3. deploy WAF rule ของ platform คุณใน **โหมด log/count/preview ก่อน** แล้วดูว่าไม่มี false positive
4. รัน `tests/curl-tests.sh` แล้วเปิด block จริง

```bash
./tests/curl-tests.sh https://your-site.example /upload/test.php
```

## Sources

- [CVE-2026-109618](https://www.cve.org/CVERecord?id=CVE-2026-109618) · [CVE-2026-109619](https://www.cve.org/CVERecord?id=CVE-2026-109619)
- [Wiz: PHP2Shell](https://www.wiz.io/blog/php2shell-php-rce)

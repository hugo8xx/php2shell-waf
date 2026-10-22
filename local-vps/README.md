# Local VPS (setup เอง)

สำหรับเครื่องที่คุณคุมเองทั้งหมด — nginx + PHP-FPM (Ubuntu/Debian)

| ไฟล์ | ทำอะไร |
|---|---|
| `php/99-php2shell.ini` | **สำคัญที่สุด** — ปิด `session.upload_progress`, จำกัด input, ปิด `fatal_error_backtraces` (8.5) |
| `php/php2shell-pool.conf` | FPM pool: recycle worker (`pm.max_requests`) + บังคับค่า ini ด้วย `php_admin_value` |
| `nginx/conf.d/php2shell-maps.conf` | `map` ทั้งหมด (ใส่ใน `http{}`) |
| `nginx/snippets/php2shell-server.conf` | `include` ใน `server{}` ที่ส่งไป PHP |
| `modsecurity/php2shell.conf` | ถ้ามี ModSecurity (v2.9.6+ / v3.0.8+) — ตรวจ body ได้ละเอียดกว่า nginx เปล่า |
| `fail2ban/` | แบน IP ที่ทำให้ PHP OOM / timeout ซ้ำ ๆ (อ่านจาก nginx error log) |

## ติดตั้ง

```bash
# 1) PHP — แก้ 8.X เป็นเวอร์ชันของคุณ; PHP 8.2–8.4 ให้ลบบรรทัด fatal_error_backtraces
sudo cp php/99-php2shell.ini /etc/php/8.X/fpm/conf.d/
sudo systemctl restart php8.X-fpm
```

```bash
# 2) nginx — แก้ upload path ใน php2shell-maps.conf ก่อน
sudo cp nginx/conf.d/php2shell-maps.conf /etc/nginx/conf.d/
sudo mkdir -p /etc/nginx/snippets && sudo cp nginx/snippets/php2shell-server.conf /etc/nginx/snippets/
# เพิ่ม `include snippets/php2shell-server.conf;` ใน server{} ของเว็บ
sudo nginx -t && sudo systemctl reload nginx
```

```bash
# 3) fail2ban
sudo cp fail2ban/filter.d/php2shell.conf /etc/fail2ban/filter.d/
sudo cp fail2ban/jail.d/php2shell.local /etc/fail2ban/jail.d/
sudo systemctl reload fail2ban
```

```bash
# ตรวจว่าค่า ini ใช้จริง (ต้องดูจาก FPM ไม่ใช่ CLI)
sudo php-fpm8.X -i | grep -E 'upload_progress.enabled|max_input_nesting|post_max_size'
```

## ข้อจำกัด

- **nginx เปล่าอ่านชื่อ field ใน body ไม่ได้** → ต้องพึ่ง `session.upload_progress.enabled=0` ใน php.ini หรือใช้ ModSecurity
- nginx **block response ไม่ได้** → การตรวจ `PHPSESSID` ยาวผิดปกติเป็นแค่ log ที่ `/var/log/nginx/php2shell.log`
- **Apache mod_php** คือเป้าที่ยืนยันแล้วว่าโจมตีได้ → ถ้าใช้อยู่ แนะนำย้ายไป PHP-FPM (`mod_proxy_fcgi`) และใช้ ModSecurity rule
- ตรวจว่าไม่มี `fastcgi_param PHP_VALUE` / `PHP_ADMIN_VALUE` ที่รับค่าจาก request: `grep -rn 'PHP_VALUE\|PHP_ADMIN_VALUE' /etc/nginx`

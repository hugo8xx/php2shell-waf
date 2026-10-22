# AWS WAFv2

Rule group 6 ข้อ ([`rules.json`](rules.json)): multipart นอก upload path, multipart ไม่มี length / chunked, upload progress (body + query + cookie), body ≥ 10 MB, nesting ลึก, Content-Type multipart ที่ไม่ใช่รูปแบบมาตรฐาน (เช่น `multipart/form-data,boundary=x` ที่ PHP ยังมองเป็น multipart)

## ติดตั้ง

```bash
# ALB / API Gateway — ลองโหมด Count ก่อน
SCOPE=REGIONAL AWS_REGION=ap-southeast-1 MODE=count ./deploy.sh
```

```bash
# CloudFront
SCOPE=CLOUDFRONT MODE=count ./deploy.sh
```

script จะรัน `check-capacity` เพื่อคำนวณ WCU แล้วสร้าง rule group พร้อมพื้นที่เผื่อ 50 WCU จากนั้นนำ ARN ไปผูกกับ Web ACL โดยวาง **ก่อน** AWS managed rule groups

ดูผลใน CloudWatch metrics `php2shell-*` / sampled requests แล้วค่อยรันใหม่ด้วย `MODE=block` (หรือเปลี่ยน override ใน Web ACL)

## ก่อน deploy

- แก้ regex upload path ใน rule `php2shell-multipart-non-upload-path`

## ข้อจำกัด

- WAF ตรวจ body ได้แค่ส่วนแรก (ALB/API GW 8 KB, CloudFront 16 KB ปรับได้ถึง 64 KB) — field `PHP_SESSION_UPLOAD_PROGRESS` ต้องมาก่อน part ที่เป็นไฟล์ แต่จะวางหลัง field ธรรมดาจำนวนมากก็ได้ ซึ่ง PoC สาธารณะทำแบบนั้น (field อยู่หลังข้อมูลราว 3 MB) **rule ตรวจ body จึงจับ PoC บน path upload ไม่ได้** — ต้องตั้ง `session.upload_progress.enabled=0` ที่ origin
- นับจำนวน part / header ต่อ part ไม่ได้ และตรวจ response ไม่ได้
- ยังควรตั้ง `session.upload_progress.enabled=0` ที่ origin

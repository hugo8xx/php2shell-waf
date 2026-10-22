# GCP Cloud Armor

เพิ่ม 5 rule เข้า security policy ที่มีอยู่ (priority 1000–1004) — รวม rule Content-Type แบบเข้มที่กัน `multipart/form-data,boundary=x`

## ติดตั้ง

```bash
# preview mode ก่อน (log อย่างเดียว ไม่ block)
POLICY=my-policy PREVIEW=1 ./deploy.sh
```

ดูผลใน Cloud Logging (`jsonPayload.previewSecurityPolicy`) ถ้าไม่มี false positive ให้ปิด preview:

```bash
for p in 1000 1001 1002 1003 1004; do gcloud compute security-policies rules update $p --security-policy=my-policy --no-preview; done
```

## ก่อน deploy

- แก้ `UPLOAD_PATHS` ใน `deploy.sh` ให้ตรง endpoint จริง
- ถ้า priority 1000–1004 ถูกใช้แล้ว ตั้ง `PRIORITY_BASE=...`
- Cloud Armor จำกัด 5 sub-expression ต่อ rule — rule 1000/1001 ใช้ครบ 5 แล้ว ถ้าจะเพิ่ม upload path ต้องรวมเป็น regex เดียว เช่น `request.path.matches('^/(upload|api/files)')`

## ข้อจำกัด

- Custom rule **ตรวจ body ไม่ได้** และตรวจ response ไม่ได้ → ต้องตั้ง `session.upload_progress.enabled=0` ที่ origin (ดู [`../local-vps/php`](../local-vps/php))

<?php
// Simulates the memory-disclosure symptom: an oversized PHPSESSID
// Set-Cookie. Used to check nginx's php2shell.log flags it.
setcookie('PHPSESSID', str_repeat('A', 200));
echo "ok\n";

<?php
// Harmless stand-in for the exploit's producer step: a fatal OOM.
// Only used to check that the error reaches nginx's log with the
// client IP and that the fail2ban filter matches it.
$a = [];
while (true) {
    $a[] = str_repeat('x', 1 << 20);
}

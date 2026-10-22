<?php
// Legit upload endpoint: echoes what PHP actually received.
header('Content-Type: application/json');
echo json_encode([
    'post'  => $_POST,
    'files' => array_map(fn($f) => ['name' => $f['name'], 'size' => $f['size'], 'error' => $f['error']], $_FILES),
]), "\n";

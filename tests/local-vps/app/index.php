<?php
// Reports the effective (FPM, not CLI) values of the hardening settings.
header('Content-Type: application/json');
echo json_encode([
    'php'                             => PHP_VERSION,
    'session.upload_progress.enabled' => ini_get('session.upload_progress.enabled'),
    'post_max_size'                   => ini_get('post_max_size'),
    'max_input_vars'                  => ini_get('max_input_vars'),
    'max_input_nesting_level'         => ini_get('max_input_nesting_level'),
    'max_file_uploads'                => ini_get('max_file_uploads'),
    'display_errors'                  => ini_get('display_errors'),
    'fatal_error_backtraces'          => ini_get('fatal_error_backtraces'),
]), "\n";

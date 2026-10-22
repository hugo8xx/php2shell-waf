# Vulnerable PHP on purpose (8.3.35 < 8.3.36) behind Apache mod_php,
# with ModSecurity v2 from Debian (no CRS — our rules must stand alone).
FROM php:8.3.35-apache

RUN apt-get update \
 && apt-get install -y --no-install-recommends libapache2-mod-security2 \
 && rm -rf /var/lib/apt/lists/* \
 && a2enmod rewrite security2 \
 # Debian's security2.conf loads /etc/modsecurity/*.conf; start empty so
 # each test container mounts exactly the config it needs.
 && rm -f /etc/modsecurity/*.conf \
 && mkdir -p /var/log/apache2

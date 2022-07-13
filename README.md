<p align="center">
<img src="https://github.com/crowdsecurity/cs-nginx-bouncer/raw/main/docs/assets/crowdsec_nginx.svg" alt="CrowdSec" title="CrowdSec" width="280" height="300" />
</p>
<p align="center">
<img src="https://img.shields.io/badge/build-pass-green">
<img src="https://img.shields.io/badge/tests-pass-green">
</p>
<p align="center">
&#x1F4DA; <a href="#installation/">Documentation</a>
&#x1F4A0; <a href="https://hub.crowdsec.net">Hub</a>
&#128172; <a href="https://discourse.crowdsec.net">Discourse </a>
</p>



# CrowdSec HAProxy Bouncer

A lua bouncer for haproxy.

## How does it work ?

This bouncer leverages haproxy lua's API.

New/unknown IP are checked against crowdsec API, and if request should be blocked, a **403** is returned to the user, and put in cache.

# Installation

Please follow the [official documentation](https://doc.crowdsec.net/docs/bouncers/haproxy).
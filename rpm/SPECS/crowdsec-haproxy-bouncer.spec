Name:           crowdsec-haproxy-bouncer
Version:        %(echo $VERSION)
Release:        %(echo $PACKAGE_NUMBER)%{?dist}
Summary:      Haproxy bouncer for Crowdsec 

License:        MIT
URL:            https://crowdsec.net
Source0:        https://github.com/crowdsecurity/%{name}/archive/v%(echo $VERSION).tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:  git
BuildRequires:  make
Requires: haproxy
%{?fc33:BuildRequires: systemd-rpm-macros}

%define debug_package %{nil}

%description

%define version_number  %(echo $VERSION)
%define releasever  %(echo $RELEASEVER)
%global local_version v%{version_number}-%{releasever}-rpm
%global name crowdsec-haproxy-bouncer
%global __mangle_shebangs_exclude_from /usr/bin/env

%prep
%setup -n crowdsec-haproxy-bouncer-%{version}

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_sysconfdir}/crowdsec/bouncers
mkdir -p %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/
mkdir -p %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec

install -m 600 -D %{name}.conf %{buildroot}%{_sysconfdir}/crowdsec/bouncers/%{name}.conf

install -m 644 lib/crowdsec.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy
install -m 644 lib/json.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy
install -m 644 lib/plugins/crowdsec/recaptcha.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/template.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/config.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/ban.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/utils.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec

install -m 644 templates/captcha.html %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/
install -m 644 templates/ban.html %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/
install -m 644 community_blocklist.map %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy
%clean
rm -rf %{buildroot}

%files
%{_libdir}/crowdsec/lua/haproxy/crowdsec.lua
%{_libdir}/crowdsec/lua/haproxy/json.lua
%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/recaptcha.lua
%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/template.lua
%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/config.lua
%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/ban.lua
%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/utils.lua
%{_sharedstatedir}/crowdsec/lua/haproxy/templates/captcha.html
%{_sharedstatedir}/crowdsec/lua/haproxy/templates/ban.html
%{_sharedstatedir}/crowdsec/lua/haproxy/community_blocklist.map

%config(noreplace) %{_sysconfdir}/crowdsec/bouncers/%{name}.conf


%post -p /bin/bash
systemctl daemon-reload


START=0

systemctl is-active --quiet crowdsec

if [ "$?" -eq "0" ] ; then
    START=1
    echo "cscli/crowdsec is present, generating API key"
    unique=`date +%s`
    API_KEY=`sudo cscli -oraw bouncers add HaproxyBouncer-${unique}`
    if [ $? -eq 1 ] ; then
        echo "failed to create API token, service won't be started."
        START=0
        API_KEY="<API_KEY>"
    else
        echo "API Key : ${API_KEY}"
    fi
fi

TMP=$(mktemp -p /tmp)
cp /etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.conf ${TMP}
API_KEY=${API_KEY} envsubst < ${TMP} > /etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.conf
rm ${TMP}

if [ ${START} -eq 0 ] ; then
    echo "no api key was generated, won't start service"
fi

echo "Please configure '/etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.conf' as you see fit"


 
%changelog
* Wed Sep 29 2022 Manuel Sabban <manuel@crowdsec.net>
- First initial packaging


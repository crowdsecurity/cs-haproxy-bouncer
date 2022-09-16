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

install -m 600 -D %{name}.yaml %{_sysconfdir}/crowdsec/bouncers/%{name}.conf

install -m 644 lib/crowdsec.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy
install -m 644 lib/json.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy
install -m 644 lib/plugins/crowdsec/recaptcha.luaw %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/template.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/config.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/ban.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec
install -m 644 lib/plugins/crowdsec/utils.lua %{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec

install -m 644 templates/captcha.html %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/
install -m 644 templates/ban.html %{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/
install -m 644 community_blocklist.map %{buildroot}%{_libdir}/crowdsec/lua/haproxy
%clean
rm -rf %{buildroot}

%files
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/crowdsec.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/json.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/recaptcha.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/template.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/config.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/ban.lua
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/plugins/crowdsec/utils.lua
%{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/captcha.html
%{buildroot}%{_sharedstatedir}/crowdsec/lua/haproxy/templates/ban.html
%{buildroot}%{_libdir}/crowdsec/lua/haproxy/community_blocklist.map

%config(noreplace) /etc/crowdsec/bouncers/%{name}.conf


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

TMP=`mktemp -p /tmp/`
cp /etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.yaml ${TMP}
API_KEY=${API_KEY} envsubst < ${TMP} > /etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.yaml
rm ${TMP}

if [ ${START} -eq 0 ] ; then
    echo "no api key was generated, won't start service"
fi

echo "please enter the binary path in '/etc/crowdsec/bouncers/crowdsec-haproxy-bouncer.yaml' and start the bouncer via 'sudo systemctl start crowdsec-haproxy-bouncer' "


 
%changelog
* Wed Jun 30 2021 Shivam Sandbhor <shivam@crowdsec.net>
- First initial packaging

%preun -p /bin/bash

if [ "$1" == "0" ] ; then
    systemctl stop crowdsec-haproxy-bouncer || echo "cannot stop service"
    systemctl disable crowdsec-haproxy-bouncer || echo "cannot disable service"
fi



%postun -p /bin/bash

if [ "$1" == "1" ] ; then
    systemctl restart  crowdsec-haproxy-bouncer || echo "cannot restart service"
elif [ "$1" == "0" ] ; then
    systemctl stop crowdsec-haproxy-bouncer
    systemctl disable crowdsec-custom-bouncer
fi
